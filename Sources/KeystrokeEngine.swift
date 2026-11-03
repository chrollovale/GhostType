import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

@MainActor
final class KeystrokeEngine: ObservableObject {
    @Published var isInjecting: Bool = false
    @Published var isCountingDown: Bool = false
    @Published var countdownRemaining: Int = 0
    @Published var progress: Double = 0.0
    @Published var progressText: String = ""
    @Published var isAccessibilityTrusted: Bool = true

    private var injectionTask: Task<Void, Never>?

    init() {
        checkAccessibility()
    }

    func checkAccessibility() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Directly open macOS System Settings -> Privacy & Security -> Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        checkAccessibility()
    }

    func startInjection(
        text: String,
        countdownSeconds: Int,
        charDelayMs: Double,
        playBeeps: Bool = true
    ) {
        guard !text.isEmpty else { return }
        checkAccessibility()
        guard isAccessibilityTrusted else {
            promptAccessibility()
            return
        }

        cancelInjection()

        isCountingDown = true
        isInjecting = false
        countdownRemaining = countdownSeconds
        progress = 0.0
        progressText = "Preparing to inject..."

        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")

        injectionTask = Task { [weak self] in
            guard let self = self else { return }

            // 1. Countdown phase
            for sec in (1...countdownSeconds).reversed() {
                if Task.isCancelled { break }
                self.countdownRemaining = sec
                self.progressText = "Switch focus to target window! Starting in \(sec)s..."
                if playBeeps {
                    NSSound.beep()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard !Task.isCancelled else {
                self.resetState(message: "Injection cancelled.")
                return
            }

            // 2. Typing phase
            self.isCountingDown = false
            self.isInjecting = true
            self.progressText = "Injecting keystrokes..."

            let characters = Array(normalized)
            let total = characters.count
            // Delay between keystrokes in nanoseconds
            let interKeyDelayNanos = UInt64(max(5.0, charDelayMs) * 1_000_000.0)

            let source = CGEventSource(stateID: .hidSystemState)

            for (index, char) in characters.enumerated() {
                if Task.isCancelled { break }

                Self.simulateHardwareCharacter(char, source: source)

                try? await Task.sleep(nanoseconds: interKeyDelayNanos)

                if index % 5 == 0 || index == total - 1 {
                    let curProg = Double(index + 1) / Double(total)
                    self.progress = curProg
                    self.progressText = "Typing: \(index + 1) / \(total) characters (\(Int(curProg * 100))%)"
                }
            }

            if Task.isCancelled {
                self.resetState(message: "Injection cancelled.")
            } else {
                self.progress = 1.0
                self.resetState(message: "Injection complete!")
            }
        }
    }

    func cancelInjection() {
        injectionTask?.cancel()
        injectionTask = nil
        resetState(message: "Stopped.")
    }

    private func resetState(message: String) {
        isCountingDown = false
        isInjecting = false
        progressText = message
    }

    // MARK: - Hardware Scan Code Synthesis for VMs & Remote Desktops
    private static func simulateHardwareCharacter(_ char: Character, source: CGEventSource?) {
        let (keyCode, needsShift) = getHardwareKeyCode(for: char)

        if let keyCode = keyCode {
            // macOS Virtual KeyCode mapped accurately
            let kVK_Shift: CGKeyCode = 0x38 // Left Shift

            if needsShift {
                let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: true)
                shiftDown?.flags = .maskShift
                shiftDown?.post(tap: .cghidEventTap)
                usleep(8000) // 8ms shift registration
            }

            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            if needsShift {
                down?.flags = .maskShift
            }
            down?.post(tap: .cghidEventTap)

            // Hold key down for 16ms so VM input thread samples it reliably
            usleep(16000)

            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            if needsShift {
                up?.flags = .maskShift
            }
            up?.post(tap: .cghidEventTap)

            if needsShift {
                usleep(8000)
                let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: false)
                shiftUp?.flags = []
                shiftUp?.post(tap: .cghidEventTap)
            }

            usleep(8000) // Inter-key cooldown
        } else {
            // Fallback for non-ASCII Unicode characters
            var utf16Chars = Array(String(char).utf16)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &utf16Chars)
            down?.post(tap: .cghidEventTap)

            usleep(16000)

            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &utf16Chars)
            up?.post(tap: .cghidEventTap)

            usleep(8000)
        }
    }

    // MARK: - Single Key Sender (for Virtual Keyboard)
    static func sendSingleKey(
        keyCode: CGKeyCode,
        shift: Bool = false,
        control: Bool = false,
        option: Bool = false,
        command: Bool = false
    ) {
        let source = CGEventSource(stateID: .hidSystemState)
        let kVK_Shift: CGKeyCode = 0x38
        let kVK_Control: CGKeyCode = 0x3B
        let kVK_Option: CGKeyCode = 0x3A
        let kVK_Command: CGKeyCode = 0x37

        var flags: CGEventFlags = []

        // Press modifiers down
        if control {
            flags.insert(.maskControl)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: true)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if shift {
            flags.insert(.maskShift)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: true)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if option {
            flags.insert(.maskAlternate)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Option, keyDown: true)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if command {
            flags.insert(.maskCommand)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }

        // Press and release the main key
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        usleep(20000)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
        usleep(12000)

        // Release modifiers in reverse order
        if command {
            flags.remove(.maskCommand)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if option {
            flags.remove(.maskAlternate)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Option, keyDown: false)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if shift {
            flags.remove(.maskShift)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Shift, keyDown: false)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
        if control {
            flags.remove(.maskControl)
            let ev = CGEvent(keyboardEventSource: source, virtualKey: kVK_Control, keyDown: false)
            ev?.flags = flags
            ev?.post(tap: .cghidEventTap)
            usleep(12000)
        }
    }

    // Comprehensive macOS ANSI Virtual Keycode Map
    private static func getHardwareKeyCode(for char: Character) -> (CGKeyCode?, Bool) {
        switch char {
        case "a": return (0x00, false); case "A": return (0x00, true)
        case "b": return (0x0B, false); case "B": return (0x0B, true)
        case "c": return (0x08, false); case "C": return (0x08, true)
        case "d": return (0x02, false); case "D": return (0x02, true)
        case "e": return (0x0E, false); case "E": return (0x0E, true)
        case "f": return (0x03, false); case "F": return (0x03, true)
        case "g": return (0x05, false); case "G": return (0x05, true)
        case "h": return (0x04, false); case "H": return (0x04, true)
        case "i": return (0x22, false); case "I": return (0x22, true)
        case "j": return (0x26, false); case "J": return (0x26, true)
        case "k": return (0x28, false); case "K": return (0x28, true)
        case "l": return (0x25, false); case "L": return (0x25, true)
        case "m": return (0x2E, false); case "M": return (0x2E, true)
        case "n": return (0x2D, false); case "N": return (0x2D, true)
        case "o": return (0x1F, false); case "O": return (0x1F, true)
        case "p": return (0x23, false); case "P": return (0x23, true)
        case "q": return (0x0C, false); case "Q": return (0x0C, true)
        case "r": return (0x0F, false); case "R": return (0x0F, true)
        case "s": return (0x01, false); case "S": return (0x01, true)
        case "t": return (0x11, false); case "T": return (0x11, true)
        case "u": return (0x20, false); case "U": return (0x20, true)
        case "v": return (0x09, false); case "V": return (0x09, true)
        case "w": return (0x0D, false); case "W": return (0x0D, true)
        case "x": return (0x07, false); case "X": return (0x07, true)
        case "y": return (0x10, false); case "Y": return (0x10, true)
        case "z": return (0x06, false); case "Z": return (0x06, true)

        case "1": return (0x12, false); case "!": return (0x12, true)
        case "2": return (0x13, false); case "@": return (0x13, true)
        case "3": return (0x14, false); case "#": return (0x14, true)
        case "4": return (0x15, false); case "$": return (0x15, true)
        case "5": return (0x17, false); case "%": return (0x17, true)
        case "6": return (0x16, false); case "^": return (0x16, true)
        case "7": return (0x1A, false); case "&": return (0x1A, true)
        case "8": return (0x1C, false); case "*": return (0x1C, true)
        case "9": return (0x19, false); case "(": return (0x19, true)
        case "0": return (0x1D, false); case ")": return (0x1D, true)

        case "-": return (0x1B, false); case "_": return (0x1B, true)
        case "=": return (0x18, false); case "+": return (0x18, true)
        case "[": return (0x21, false); case "{": return (0x21, true)
        case "]": return (0x1E, false); case "}": return (0x1E, true)
        case ";": return (0x29, false); case ":": return (0x29, true)
        case "'": return (0x27, false); case "\"": return (0x27, true)
        case ",": return (0x2B, false); case "<": return (0x2B, true)
        case ".": return (0x2F, false); case ">": return (0x2F, true)
        case "/": return (0x2C, false); case "?": return (0x2C, true)
        case "\\": return (0x2A, false); case "|": return (0x2A, true)
        case "`": return (0x32, false); case "~": return (0x32, true)

        case " ": return (0x31, false)
        case "\n": return (0x24, false)
        case "\t": return (0x30, false)

        default:
            return (nil, false)
        }
    }
}
