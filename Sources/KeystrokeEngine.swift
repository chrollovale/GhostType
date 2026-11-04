import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

@MainActor
final class KeystrokeEngine: ObservableObject {
    @Published var isInjecting = false
    @Published var isCountingDown = false
    @Published var countdownRemaining = 0
    @Published var progress = 0.0
    @Published var progressText = ""
    @Published var isAccessibilityTrusted = false

    private var injectionTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init() {
        checkAccessibility()
    }

    func checkAccessibility() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        checkAccessibility()
    }

    func startInjection(
        text: String,
        mode: InjectionMode,
        countdownSeconds: Int,
        minimumKeyIntervalMs: Double,
        remoteCompatible: Bool = false,
        playBeeps: Bool = true
    ) {
        guard !text.isEmpty else { return }

        cancelInjection()
        checkAccessibility()
        guard isAccessibilityTrusted else {
            promptAccessibility()
            return
        }

        let runID = UUID()
        activeRunID = runID
        isCountingDown = true
        isInjecting = false
        countdownRemaining = min(max(countdownSeconds, 0), 60)
        progress = 0.0
        progressText = "Preparing to inject…"

        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let safeCountdown = countdownRemaining
        let safeIntervalMs = minimumKeyIntervalMs.isFinite
            ? min(max(minimumKeyIntervalMs, 0.0), 1_000.0)
            : 15.0
        let minimumKeyIntervalNanos = UInt64(safeIntervalMs * 1_000_000.0)

        injectionTask = Task { [weak self] in
            guard let self else { return }

            for second in stride(from: safeCountdown, through: 1, by: -1) {
                guard self.activeRunID == runID, !Task.isCancelled else { return }
                self.countdownRemaining = second
                self.progressText = "Switch focus to the target window. Starting in \(second)s…"
                if playBeeps {
                    NSSound.beep()
                }
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }

            guard self.activeRunID == runID, !Task.isCancelled else { return }
            self.isCountingDown = false
            self.isInjecting = true

            if mode == .exactPaste {
                self.progressText = "Pasting text…"
                let pasteResult = await Self.pasteText(text, remoteCompatible: remoteCompatible)
                guard self.activeRunID == runID, !Task.isCancelled else { return }
                self.progress = pasteResult.succeeded ? 1.0 : 0.0
                self.finish(runID: runID, message: pasteResult.message)
                return
            }

            guard let source = CGEventSource(stateID: .hidSystemState) else {
                self.finish(runID: runID, message: "Couldn't create a keyboard event source.")
                return
            }
            self.progressText = "Injecting keystrokes…"

            if mode == .smartEditor {
                let succeeded = await self.injectSmartEditor(
                    normalizedText,
                    source: source,
                    remoteCompatible: remoteCompatible,
                    minimumKeyIntervalNanos: minimumKeyIntervalNanos,
                    runID: runID
                )
                guard self.activeRunID == runID, !Task.isCancelled else { return }
                guard succeeded else {
                    self.finish(runID: runID, message: "Smart Editor couldn't create a keystroke. Check Accessibility access and that the target editor is ready.")
                    return
                }
                self.progress = 1.0
                self.finish(runID: runID, message: "Injection complete.")
                return
            }

            let characters = Array(normalizedText)
            let total = characters.count
            guard total > 0 else {
                self.finish(runID: runID, message: "Nothing to inject.")
                return
            }

            for (index, character) in characters.enumerated() {
                guard self.activeRunID == runID, !Task.isCancelled else { return }
                let keyStartedAt = ProcessInfo.processInfo.systemUptime
                let sent = await Self.simulateHardwareCharacter(
                    character,
                    source: source,
                    remoteCompatible: remoteCompatible
                )
                guard self.activeRunID == runID, !Task.isCancelled else { return }
                guard sent else {
                    self.finish(runID: runID, message: "Keystroke creation failed. Check Accessibility access and try again.")
                    return
                }

                let elapsedNanos = UInt64(max(0, (ProcessInfo.processInfo.systemUptime - keyStartedAt) * 1_000_000_000))
                if minimumKeyIntervalNanos > elapsedNanos {
                    do {
                        try await Task.sleep(nanoseconds: minimumKeyIntervalNanos - elapsedNanos)
                    } catch {
                        return
                    }
                }

                if index % 32 == 0 || index == total - 1 {
                    let currentProgress = Double(index + 1) / Double(total)
                    self.progress = currentProgress
                    self.progressText = "Typing: \(index + 1) / \(total) characters (\(Int(currentProgress * 100))%)"
                }
            }

            guard self.activeRunID == runID, !Task.isCancelled else { return }
            self.progress = 1.0
            self.finish(runID: runID, message: "Injection complete.")
        }
    }

    private func injectSmartEditor(
        _ text: String,
        source: CGEventSource,
        remoteCompatible: Bool,
        minimumKeyIntervalNanos: UInt64,
        runID: UUID
    ) async -> Bool {
        let lines = SmartEditorPlanner.lines(for: text)
        let totalLines = lines.count
        guard totalLines > 0 else { return false }

        for (lineIndex, line) in lines.enumerated() {
            guard activeRunID == runID, !Task.isCancelled else { return false }

            if lineIndex > 0 {
                guard await typeSmartEditorCharacter(
                    "\n",
                    source: source,
                    remoteCompatible: remoteCompatible,
                    minimumKeyIntervalNanos: max(minimumKeyIntervalNanos, 25_000_000),
                    runID: runID
                ) else { return false }

                if line.clearsAutoIndent {
                    guard activeRunID == runID, !Task.isCancelled else { return false }
                    guard await Self.sendSingleKey(keyCode: 0x33, command: true) else {
                        return false
                    }
                    guard await waitForSmartEditor(15_000_000, runID: runID) else {
                        return false
                    }
                }
            }

            for character in line.text {
                guard await typeSmartEditorCharacter(
                    character,
                    source: source,
                    remoteCompatible: remoteCompatible,
                    minimumKeyIntervalNanos: minimumKeyIntervalNanos,
                    runID: runID
                ) else { return false }
            }

            let currentProgress = Double(lineIndex + 1) / Double(totalLines)
            progress = currentProgress
            progressText = "Typing line \(lineIndex + 1) / \(totalLines) (\(Int(currentProgress * 100))%)"
        }

        return activeRunID == runID && !Task.isCancelled
    }

    private func typeSmartEditorCharacter(
        _ character: Character,
        source: CGEventSource,
        remoteCompatible: Bool,
        minimumKeyIntervalNanos: UInt64,
        runID: UUID
    ) async -> Bool {
        guard activeRunID == runID, !Task.isCancelled else { return false }
        let keyStartedAt = ProcessInfo.processInfo.systemUptime
        guard await Self.simulateHardwareCharacter(
            character,
            source: source,
            remoteCompatible: remoteCompatible
        ) else { return false }

        if SmartEditorPlanner.deletesAutoCloser(after: character) {
            guard await waitForSmartEditor(50_000_000, runID: runID) else { return false }
            guard activeRunID == runID, !Task.isCancelled else { return false }
            guard await Self.sendSingleKey(keyCode: 0x75) else { return false }
            guard await waitForSmartEditor(20_000_000, runID: runID) else { return false }
        }

        let elapsedNanos = UInt64(max(0, (ProcessInfo.processInfo.systemUptime - keyStartedAt) * 1_000_000_000))
        if minimumKeyIntervalNanos > elapsedNanos {
            guard await waitForSmartEditor(minimumKeyIntervalNanos - elapsedNanos, runID: runID) else {
                return false
            }
        }
        return activeRunID == runID && !Task.isCancelled
    }

    private func waitForSmartEditor(_ nanoseconds: UInt64, runID: UUID) async -> Bool {
        guard activeRunID == runID, !Task.isCancelled else { return false }
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return false
        }
        return activeRunID == runID && !Task.isCancelled
    }

    func cancelInjection() {
        injectionTask?.cancel()
        injectionTask = nil
        activeRunID = nil
        resetState(message: "Stopped.")
    }

    private func finish(runID: UUID, message: String) {
        guard activeRunID == runID else { return }
        injectionTask = nil
        activeRunID = nil
        resetState(message: message)
    }

    private func resetState(message: String) {
        isCountingDown = false
        isInjecting = false
        countdownRemaining = 0
        progressText = message
    }

    private struct PasteResult {
        let succeeded: Bool
        let message: String
    }

    private static func pasteText(_ text: String, remoteCompatible: Bool) async -> PasteResult {
        let pasteboard = NSPasteboard.general
        guard let snapshot = PasteboardSnapshot.capture(from: pasteboard) else {
            return PasteResult(succeeded: false, message: "The current clipboard can't be preserved safely. Clear or copy its contents, then retry.")
        }

        pasteboard.clearContents()
        let clearedChangeCount = pasteboard.changeCount
        guard pasteboard.setString(text, forType: .string) else {
            _ = snapshot.restore(to: pasteboard, onlyIfChangeCount: clearedChangeCount)
            return PasteResult(succeeded: false, message: "Couldn't place the source text on the clipboard.")
        }
        let injectedChangeCount = pasteboard.changeCount

        let sent = await sendSingleKey(
            keyCode: 0x09,
            control: remoteCompatible,
            command: !remoteCompatible
        )
        guard sent else {
            _ = snapshot.restore(to: pasteboard, onlyIfChangeCount: injectedChangeCount)
            return PasteResult(succeeded: false, message: "Couldn't send the paste shortcut. Check Accessibility access.")
        }

        do {
            try await Task.sleep(nanoseconds: 180_000_000)
        } catch {
            _ = snapshot.restore(to: pasteboard, onlyIfChangeCount: injectedChangeCount)
            return PasteResult(succeeded: false, message: "Paste cancelled.")
        }

        guard pasteboard.changeCount == injectedChangeCount else {
            return PasteResult(succeeded: true, message: "Text pasted. A clipboard change was left untouched.")
        }

        guard snapshot.restore(to: pasteboard, onlyIfChangeCount: injectedChangeCount) else {
            return PasteResult(succeeded: true, message: "Text pasted, but the previous clipboard couldn't be restored.")
        }
        return PasteResult(succeeded: true, message: "Text pasted; previous clipboard restored.")
    }

    private struct PasteboardSnapshot {
        private struct Entry {
            let type: NSPasteboard.PasteboardType
            let data: Data
        }

        private let items: [[Entry]]

        static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot? {
            if let sourceItems = pasteboard.pasteboardItems, !sourceItems.isEmpty {
                var copiedItems: [[Entry]] = []
                for sourceItem in sourceItems {
                    var entries: [Entry] = []
                    for type in sourceItem.types {
                        if let data = sourceItem.data(forType: type) {
                            entries.append(Entry(type: type, data: data))
                        } else if let string = sourceItem.string(forType: type) {
                            entries.append(Entry(type: type, data: Data(string.utf8)))
                        } else {
                            return nil
                        }
                    }
                    guard !entries.isEmpty else { return nil }
                    copiedItems.append(entries)
                }
                return PasteboardSnapshot(items: copiedItems)
            }

            if let string = pasteboard.string(forType: .string) {
                return PasteboardSnapshot(items: [[Entry(type: .string, data: Data(string.utf8))]])
            }
            return PasteboardSnapshot(items: [])
        }

        func restore(to pasteboard: NSPasteboard, onlyIfChangeCount expectedChangeCount: Int) -> Bool {
            guard pasteboard.changeCount == expectedChangeCount else { return false }
            pasteboard.clearContents()
            guard !items.isEmpty else { return true }

            let restoredItems = items.map { entries in
                let item = NSPasteboardItem()
                for entry in entries {
                    item.setData(entry.data, forType: entry.type)
                }
                return item
            }
            return pasteboard.writeObjects(restoredItems)
        }
    }

    // Hardware keycodes preserve the key-position behavior expected by VMs and remote desktops.
    private static func simulateHardwareCharacter(
        _ character: Character,
        source: CGEventSource,
        remoteCompatible: Bool
    ) async -> Bool {
        let (keyCode, needsShift) = getHardwareKeyCode(for: character)
        let keyHoldNanos: UInt64 = remoteCompatible ? 16_000_000 : 4_000_000
        let shiftLeadNanos: UInt64 = remoteCompatible ? 8_000_000 : 2_000_000
        let shiftReleaseNanos: UInt64 = remoteCompatible ? 8_000_000 : 0
        if let keyCode {
            let shiftKey: CGKeyCode = 0x38

            if needsShift {
                guard postKeyEvent(source: source, keyCode: shiftKey, isDown: true, flags: .maskShift) else {
                    return false
                }
                await pause(shiftLeadNanos)
            }

            guard !Task.isCancelled else {
                if needsShift { _ = postKeyEvent(source: source, keyCode: shiftKey, isDown: false, flags: []) }
                return false
            }

            guard postKeyEvent(source: source, keyCode: keyCode, isDown: true, flags: needsShift ? .maskShift : []) else {
                if needsShift { _ = postKeyEvent(source: source, keyCode: shiftKey, isDown: false, flags: []) }
                return false
            }

            await pause(keyHoldNanos)
            let keyReleased = postKeyEvent(source: source, keyCode: keyCode, isDown: false, flags: needsShift ? .maskShift : [])
            if needsShift {
                if shiftReleaseNanos > 0 { await pause(shiftReleaseNanos) }
                _ = postKeyEvent(source: source, keyCode: shiftKey, isDown: false, flags: [])
            }
            return keyReleased
        }

        var utf16Characters = Array(String(character).utf16)
        guard !utf16Characters.isEmpty,
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Characters.count, unicodeString: &utf16Characters)
        keyDown.post(tap: .cghidEventTap)
        await pause(keyHoldNanos)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Virtual Keyboard Key Sender
    static func sendSingleKey(
        keyCode: CGKeyCode,
        shift: Bool = false,
        control: Bool = false,
        option: Bool = false,
        command: Bool = false
    ) async -> Bool {
        guard AXIsProcessTrusted(), let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        let modifiers: [(keyCode: CGKeyCode, flag: CGEventFlags, enabled: Bool)] = [
            (0x3B, .maskControl, control),
            (0x38, .maskShift, shift),
            (0x3A, .maskAlternate, option),
            (0x37, .maskCommand, command)
        ]

        var activeFlags: CGEventFlags = []
        var pressedModifiers: [(keyCode: CGKeyCode, flag: CGEventFlags)] = []

        for modifier in modifiers where modifier.enabled {
            activeFlags.insert(modifier.flag)
            guard postKeyEvent(source: source, keyCode: modifier.keyCode, isDown: true, flags: activeFlags) else {
                await releaseModifiers(pressedModifiers, source: source, flags: &activeFlags)
                return false
            }
            pressedModifiers.append((modifier.keyCode, modifier.flag))
            await pause(12_000_000)
        }

        guard postKeyEvent(source: source, keyCode: keyCode, isDown: true, flags: activeFlags) else {
            await releaseModifiers(pressedModifiers, source: source, flags: &activeFlags)
            return false
        }
        await pause(20_000_000)
        let keyReleased = postKeyEvent(source: source, keyCode: keyCode, isDown: false, flags: activeFlags)
        await releaseModifiers(pressedModifiers, source: source, flags: &activeFlags)
        return keyReleased
    }

    private static func releaseModifiers(
        _ modifiers: [(keyCode: CGKeyCode, flag: CGEventFlags)],
        source: CGEventSource,
        flags: inout CGEventFlags
    ) async {
        for modifier in modifiers.reversed() {
            flags.remove(modifier.flag)
            _ = postKeyEvent(source: source, keyCode: modifier.keyCode, isDown: false, flags: flags)
            await pause(12_000_000)
        }
    }

    private static func postKeyEvent(
        source: CGEventSource,
        keyCode: CGKeyCode,
        isDown: Bool,
        flags: CGEventFlags
    ) -> Bool {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else {
            return false
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        return true
    }

    private static func pause(_ nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    // ANSI US virtual keycode map. Non-ASCII and unmapped characters use Unicode events.
    private static func getHardwareKeyCode(for character: Character) -> (CGKeyCode?, Bool) {
        switch character {
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
        default: return (nil, false)
        }
    }
}
