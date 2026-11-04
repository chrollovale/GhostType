import Foundation

enum InjectionMode: String, CaseIterable, Identifiable {
    case raw = "Direct Typing"
    case exactPaste = "Exact Paste"
    case base64 = "Base64 One-Liner"
    case heredoc = "Terminal Heredoc"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .raw:
            return "Sends clipboard-free key events using a US ANSI layout. CodeChef's editor may transform Enter, Tab, or punctuation while typing."
        case .exactPaste:
            return "Temporarily places the source on the clipboard, pastes it once, then restores the previous clipboard if unchanged. Use this when editor key handling changes spacing."
        case .base64:
            return "Writes the exact UTF-8 text through a quoted Base64 command. Best for terminals and remote desktops."
        case .heredoc:
            return "Writes text through a quoted heredoc in a terminal. A final newline is added when the input has none."
        }
    }

    var pickerTitle: String {
        switch self {
        case .raw: return "Direct"
        case .exactPaste: return "Exact Paste"
        case .base64: return "Base64"
        case .heredoc: return "Heredoc"
        }
    }

    var usesTargetPath: Bool {
        self == .base64 || self == .heredoc
    }
}

enum InjectionPayloadBuilder {
    static func validationError(for input: String, mode: InjectionMode, targetPath: String) -> String? {
        guard !input.isEmpty, mode.usesTargetPath else { return nil }

        let path = resolvedPath(targetPath)
        if path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return "The target path can't contain line breaks or control characters."
        }
        return nil
    }

    static func build(input: String, mode: InjectionMode, targetPath: String) -> String {
        guard !input.isEmpty,
              validationError(for: input, mode: mode, targetPath: targetPath) == nil else {
            return ""
        }

        switch mode {
        case .raw, .exactPaste:
            return input
        case .base64:
            let encoded = Data(input.utf8).base64EncodedString()
            let path = shellQuoted(resolvedPath(targetPath))
            return "printf '%s' '\(encoded)' | base64 -d > \(path)\n"
        case .heredoc:
            let normalizedInput = normalizeLineEndings(input)
            let delimiter = uniqueDelimiter(for: normalizedInput)
            let trailingNewline = normalizedInput.hasSuffix("\n") ? "" : "\n"
            let path = shellQuoted(resolvedPath(targetPath))
            return "cat << '\(delimiter)' > \(path)\n\(normalizedInput)\(trailingNewline)\(delimiter)\n"
        }
    }

    private static func resolvedPath(_ targetPath: String) -> String {
        let trimmed = targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "output.txt" : trimmed
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func normalizeLineEndings(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func uniqueDelimiter(for input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        var delimiter = "GHOSTTYPE_EOF"
        var suffix = 1
        while lines.contains(delimiter) {
            delimiter = "GHOSTTYPE_EOF_\(suffix)"
            suffix += 1
        }
        return delimiter
    }
}
