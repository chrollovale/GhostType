import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var targetFilePath: String = "src/SQLiteJDBCExample.java"
    @Published var selectedMode: InjectionMode = .base64
    @Published var countdownSeconds: Double = 4.0
    @Published var keyIntervalMs: Double = 15.0
    @Published var remoteCompatibleInput = false
    @Published var playBeeps: Bool = true
    @Published var isAlwaysOnTop: Bool = true

    let engine = KeystrokeEngine()

    var generatedPayload: String {
        InjectionPayloadBuilder.build(
            input: inputText,
            mode: selectedMode,
            targetPath: targetFilePath
        )
    }

    var payloadValidationError: String? {
        InjectionPayloadBuilder.validationError(
            for: inputText,
            mode: selectedMode,
            targetPath: targetFilePath
        )
    }

    func triggerInjection() {
        let payload = generatedPayload
        guard !payload.isEmpty else { return }

        KeyboardPanelController.shared.hide()
        engine.startInjection(
            text: payload,
            mode: selectedMode,
            countdownSeconds: Int(countdownSeconds),
            minimumKeyIntervalMs: keyIntervalMs,
            remoteCompatible: remoteCompatibleInput,
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
        if let window = NSApplication.shared.windows.first(where: { !($0 is NonActivatingPanel) }) {
            window.level = isTop ? .floating : .normal
        }
    }
}
