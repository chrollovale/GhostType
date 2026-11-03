# KeyInjector (macOS SwiftUI Keystroke & Code Injector)

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

## How to Run

You can launch the compiled app immediately:

```bash
open /Users/aniketraj/.gemini/antigravity/scratch/KeyInjector/KeyInjector.app
```

Or from Terminal:
```bash
/Users/aniketraj/.gemini/antigravity/scratch/KeyInjector/KeyInjector.app/Contents/MacOS/KeyInjector
```

---

## How to Rebuild

To rebuild after making modifications:

```bash
cd /Users/aniketraj/.gemini/antigravity/scratch/KeyInjector
./bundle.sh
```

---

## macOS Accessibility Permissions

Simulating hardware keystrokes on macOS requires Accessibility permissions:
1. Go to **System Settings $\rightarrow$ Privacy & Security $\rightarrow$ Accessibility**.
2. Ensure **KeyInjector** (or your Terminal) is enabled.
3. The app includes an active status indicator in the top right to verify permissions automatically.
