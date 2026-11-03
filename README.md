<div align="center">
  <img src="icon_1024.png" width="100" height="100" alt="KeyInjector App Icon" />
  <h1>KeyInjector</h1>
  <p><b>Native macOS Keystroke & Code Injector</b></p>

  [![Release](https://img.shields.io/github/v/release/chrollovale/KeyInjector?style=flat-square&color=38bdf8)](https://github.com/chrollovale/KeyInjector/releases/latest)
  [![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/chrollovale/KeyInjector)
  [![Swift](https://img.shields.io/badge/Swift-6.0-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](./LICENSE)

  <br />
  <a href="https://github.com/chrollovale/KeyInjector/releases/latest"><b>📥 Download KeyInjector for macOS (.zip)</b></a>
</div>

---

**KeyInjector** is a native macOS application designed to inject text, code snippets, or commands character-by-character into any window (terminals, virtual machines like Parallels Desktop, remote consoles, or restricted web editors) without using the target system's clipboard.

---

## Features

- **Countdown-Based Injection:** Click "Inject", and you get a customizable countdown (1–10 seconds) with audio beeps to switch focus to your target window before typing starts.
- **Three Injection Modes:**
  1. **Base64 One-Liner (Recommended for Terminals):** Encodes your code into `echo <base64> | base64 -d > <filepath>` so it types a single line without any auto-indentation or auto-closing bracket interference.
  2. **Terminal Heredoc:** Wraps your code in a `cat << 'EOF' > <filepath>` block for clean multi-line writes.
  3. **Direct Typing:** Types the exact text character-by-character into any text field or editor.
- **Keystroke Delay Control:** Adjust typing speed between 2ms and 40ms per character to prevent input buffer overruns.
- **Live Payload Preview:** See the exact string that will be typed before starting.
- **Always-on-Top Toggle:** Keep KeyInjector floating over your active windows.
- **Emergency Cancel:** Click Cancel anytime or hit Stop to abort typing immediately.

---

## Quick Install

1. Download **[KeyInjector-v1.0.0-macos.zip](https://github.com/chrollovale/KeyInjector/releases/latest)**.
2. Unzip and drag `KeyInjector.app` into `/Applications`.
3. Launch `KeyInjector` and grant Accessibility permissions when prompted.

---

## Build from Source

```bash
git clone https://github.com/chrollovale/KeyInjector.git
cd KeyInjector
./bundle.sh
```

The compiled application bundle will be created at `./KeyInjector.app`.

---

## macOS Accessibility Permissions

Simulating hardware keystrokes on macOS requires Accessibility permissions:
1. Go to **System Settings → Privacy & Security → Accessibility**.
2. Ensure **KeyInjector** is enabled in the list.
3. The app includes an active status indicator in the top right to verify permissions automatically.

---

### ⭐ Support the Project
If KeyInjector saved you time or made working with virtual machines/terminals easier, please consider giving it a **Star**!
