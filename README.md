<div align="center">
  <img src="icon_1024.png" width="100" height="100" alt="GhostType App Icon" />
  <h1>GhostType</h1>
  <p><b>Native macOS Text Injection</b></p>

  [![Release](https://img.shields.io/github/v/release/chrollovale/GhostType?style=flat-square&color=38bdf8)](https://github.com/chrollovale/GhostType/releases/latest)
  [![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/chrollovale/GhostType)
  [![Swift](https://img.shields.io/badge/Swift-6.0-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](./LICENSE)

  <br />
  <a href="https://github.com/chrollovale/GhostType/releases/latest"><b>📥 Download GhostType for macOS (.zip)</b></a>
</div>

---

**GhostType** is a native macOS application for sending text and commands to other apps. Hardware key injection works without the clipboard; Exact Paste and Smart Editor modes support code editors that transform keystrokes. The GitHub repository was renamed from **KeyInjector** to **GhostType**; its earlier releases remain available.

---

## Features

- **Countdown-Based Injection:** Click "Inject", then use the countdown to switch focus to your target window.
- **Five Injection Modes:**
  1. **Base64 One-Liner:** Encodes source as UTF-8 and writes it with `printf` and Base64 decoding. The destination path is shell-quoted.
  2. **Terminal Heredoc:** Writes through a quoted here-document with a delimiter selected to avoid collisions with source lines.
  3. **Direct Typing:** Sends clipboard-free keyboard events. Hardware key mapping assumes a US ANSI layout. Code editors may transform Enter, Tab, or punctuation through their editor behaviors.
  4. **Smart Editor (Anti-Bracket):** For an empty Monaco or VS Code editor with auto-pairing enabled, types the source character-by-character, waits for and deletes generated closers after `{`, `(`, `[`, `"`, and `'`, then clears editor-generated indentation before reproducing the source line's own indentation.
  5. **Exact Paste:** Places the text on the macOS clipboard briefly, pastes it once, and restores the previous clipboard if it hasn't changed.
- **Key Interval Control:** Set the minimum time between key starts from 8ms to 100ms. Event hold time is included; a VM / remote option uses longer holds.
- **Live Payload Preview:** See the payload before starting.
- **Emergency Cancel:** Stop typing from the app at any time.

Terminal modes type commands into the focused terminal. Review the target path and payload preview before starting. The generated command treats source text as data; paths containing line breaks or control characters are rejected. Exact Paste temporarily uses the system clipboard; it avoids per-character editor behavior but relies on the target editor accepting paste.

---

## Quick Install

1. Download **[GhostType-v1.3.0-macos-arm64.zip](https://github.com/chrollovale/GhostType/releases/latest)**.
2. Unzip and drag `GhostType.app` into `/Applications`.
3. Launch `GhostType` and grant Accessibility permissions when prompted.

Previous [GhostType v1.2.0](https://github.com/chrollovale/GhostType/releases/tag/v1.2.0), [GhostType v1.1.1](https://github.com/chrollovale/GhostType/releases/tag/v1.1.1), [GhostType v1.1.0](https://github.com/chrollovale/GhostType/releases/tag/v1.1.0), and original [KeyInjector v1.0.0](https://github.com/chrollovale/GhostType/releases/tag/v1.0.0) releases remain available.

---

## Build from Source

```bash
git clone https://github.com/chrollovale/GhostType.git
cd GhostType
swift build
swift run GhostType
./bundle.sh
```

The compiled application bundle will be created at `./GhostType.app`. Pass an output directory to `bundle.sh` to place it elsewhere.

---

## macOS Accessibility Permissions

Simulating hardware keystrokes on macOS requires Accessibility permissions:
1. Go to **System Settings → Privacy & Security → Accessibility**.
2. Ensure **GhostType** is enabled in the list.
3. The app includes an active status indicator in the top right to verify permissions automatically.

---

### ⭐ Support the Project
If GhostType saved you time, please consider giving the project a **Star**!
