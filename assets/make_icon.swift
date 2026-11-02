import AppKit
// Generates the app icon: swift assets/make_icon.swift icon_1024.png, then build an
// .iconset with sips and convert it with `iconutil -c icns`.

let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(calibratedRed: 0.89, green: 0.52, blue: 0.40, alpha: 1),
           ending: NSColor(calibratedRed: 0.72, green: 0.33, blue: 0.24, alpha: 1))!
    .draw(in: path, angle: -90)
let cfg = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let bell = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let s = bell.size
    bell.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
