// ClaudeNotify — posts macOS notifications for Claude Code and, when a notification
// is clicked, jumps back to the terminal / editor window that triggered it.
//
// Usage:
//   ClaudeNotify post <title> <subtitle> <body> <targetFile>
//   (launched with no arguments by the system when a notification is clicked)
//
// Settings (UserDefaults, domain = this app's bundle identifier):
//   hotkeyKeyCode    Int     virtual key code of the iTerm2 hotkey (default 49 = Space)
//   hotkeyModifiers  String  "+"-separated modifiers: option, command, control, shift
//                            (default "option")
import Cocoa
import UserNotifications
import ApplicationServices

let home = FileManager.default.homeDirectoryForCurrentUser.path
let baseDir = home + "/.claude/notify"
let logPath = baseDir + "/debug.log"

func log(_ s: String) {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    let line = "\(f.string(from: Date())) \(s)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let h = FileHandle(forWritingAtPath: logPath) {
        h.seekToEndOfFile()
        h.write(data)
        h.closeFile()
    } else {
        FileManager.default.createFile(atPath: logPath, contents: data)
    }
}

func shell(_ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "shell error: \(error)" }
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

/// Number of on-screen, normal-layer iTerm2 windows. A visible hotkey window is counted
/// here, while iTerm2's AppleScript `windows` never includes it.
func itermOnScreenWindows() -> Int {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return 0 }
    return list.filter {
        ($0[kCGWindowOwnerName as String] as? String) == "iTerm2" && ($0[kCGWindowLayer as String] as? Int) == 0
    }.count
}

struct Hotkey {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let label: String

    static func load() -> Hotkey {
        let d = UserDefaults.standard
        let code = d.object(forKey: "hotkeyKeyCode") as? Int ?? 49
        let mods = d.string(forKey: "hotkeyModifiers") ?? "option"
        var flags: CGEventFlags = []
        for m in mods.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch m {
            case "option", "opt", "alt": flags.insert(.maskAlternate)
            case "command", "cmd": flags.insert(.maskCommand)
            case "control", "ctrl": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            default: log("  unknown modifier '\(m)' ignored")
            }
        }
        return Hotkey(keyCode: CGKeyCode(code), flags: flags, label: "\(mods)+\(code)")
    }

    func press() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

func focus(target: String) {
    let out = shell([baseDir + "/focus.sh", target]).trimmingCharacters(in: .whitespacesAndNewlines)
    log("click target=\((target as NSString).lastPathComponent)\n\(out)")
    guard out.contains("ACTION=hotkey") else { return }

    // focus.sh prints AS_N=<window count visible to AppleScript>
    var asN = 0
    if let r = out.range(of: "AS_N=") {
        asN = Int(out[r.upperBound...].prefix { $0.isNumber }) ?? 0
    }
    let cgN = itermOnScreenWindows()
    let hotkey = Hotkey.load()
    if cgN > asN {
        // The hotkey toggles, so pressing it now would hide the window again.
        log("  hotkey skipped, already visible cg=\(cgN) as=\(asN)")
    } else if !AXIsProcessTrusted() {
        log("  hotkey error: Accessibility permission not granted")
    } else {
        hotkey.press()
        log("  hotkey sent \(hotkey.label) cg=\(cgN) as=\(asN)")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        UNUserNotificationCenter.current().delegate = self
        let args = CommandLine.arguments
        if args.count >= 6 && args[1] == "post" {
            post(title: args[2], subtitle: args[3], body: args[4], target: args[5])
        } else {
            // Launched by a notification click: wait for the delegate callback, then quit.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { NSApp.terminate(nil) }
        }
    }

    func post(title: String, subtitle: String, body: String, target: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { ok, err in
            if !ok { log("post: notifications not authorized \(err?.localizedDescription ?? "")") }
            let c = UNMutableNotificationContent()
            c.title = title
            c.subtitle = subtitle
            c.body = body
            c.sound = .default
            c.userInfo = ["target": target]
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
            center.add(req) { e in
                if let e = e { log("post error: \(e.localizedDescription)") }
                // Stay alive briefly to handle an immediate click; later clicks relaunch the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        if let t = response.notification.request.content.userInfo["target"] as? String {
            focus(target: t)
        }
        done()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list, .sound])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
