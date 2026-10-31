# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-31

### Added
- Swift notifier app: each notification carries its own jump target, so multiple
  notifications jump back to their own origins.
- Jump support for iTerm2 (window/tab/pane), iTerm2 hotkey window, VS Code family
  (extension and integrated terminal), and Terminal.app.
- Configurable hotkey and notification language via `defaults`.
- `install.sh`, `uninstall.sh`, `build.sh`, and CI build check.
