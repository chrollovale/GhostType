import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var targetFilePath: String = "src/SQLiteJDBCExample.java"
    @Published var selectedMode: InjectionMode = .base64
    @Published var countdownSeconds: Double = 4.0
    @Published var charDelayMs: Double = 30.0  // Default to 30ms for VM & browser stability
    @Published var playBeeps: Bool = true
    @Published var isAlwaysOnTop: Bool = true

    let engine = KeystrokeEngine()

    var generatedPayload: String {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch selectedMode {
        case .raw:
            return inputText
        case .base64:
            let encoded = Data(inputText.utf8).base64EncodedString()
            let path = targetFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let safePath = path.isEmpty ? "output.txt" : path
            return "echo \(encoded) | base64 -d > \(safePath)\n"
        case .heredoc:
            let path = targetFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let safePath = path.isEmpty ? "output.txt" : path
            return "cat << 'EOF' > \(safePath)\n\(inputText)\nEOF\n"
        }
    }

    func triggerInjection() {
        let payload = generatedPayload
        guard !payload.isEmpty else { return }

        engine.startInjection(
            text: payload,
            countdownSeconds: Int(countdownSeconds),
            charDelayMs: charDelayMs,
            playBeeps: playBeeps
        )
    }

    func pasteFromClipboard() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            inputText = clip
        }
    }

    func clearInput() {
        inputText = ""
    }

    func updateWindowLevel(isTop: Bool) {
        if let window = NSApplication.shared.windows.first {
            window.level = isTop ? .floating : .normal
        }
    }
}
