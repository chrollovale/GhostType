import Foundation

enum InjectionMode: String, CaseIterable, Identifiable {
    case raw = "Direct Typing"
    case smartEditor = "Smart Editor (Anti-Bracket)"
    case exactPaste = "Exact Paste"
    case base64 = "Base64 One-Liner"
    case heredoc = "Terminal Heredoc"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .raw:
            return "Sends clipboard-free key events using a US ANSI layout. CodeChef's editor may transform Enter, Tab, or punctuation while typing."
        case .smartEditor:
            return "For an empty editor with auto-pairing enabled: after (), [], or {} is inserted automatically, GhostType moves past the editor's closer instead of typing it again. Auto-indentation is still editor-controlled."
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
        case .smartEditor: return "Smart Editor"
        case .exactPaste: return "Exact Paste"
        case .base64: return "Base64"
        case .heredoc: return "Heredoc"
        }
    }

    var usesTargetPath: Bool {
        self == .base64 || self == .heredoc
    }
}

enum SmartEditorAction: Equatable {
    case type(Character)
    case stepOverPair(Character)
}

enum SmartEditorPlanner {
    private enum ScanState {
        case code
        case lineComment
        case blockComment
        case string(Character)
    }

    private static let bracketPairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}"
    ]

    static func actions(for text: String) -> [SmartEditorAction] {
        let characters = Array(text)
        var actions: [SmartEditorAction] = []
        actions.reserveCapacity(characters.count)
        var state = ScanState.code
        var escaped = false
        var expectedClosers: [Character] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            switch state {
            case .lineComment:
                actions.append(.type(character))
                if character == "\n" { state = .code }

            case .blockComment:
                actions.append(.type(character))
                if character == "*", next == "/" {
                    actions.append(.type("/"))
                    state = .code
                    index += 1
                }

            case let .string(delimiter):
                actions.append(.type(character))
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == delimiter {
                    state = .code
                }

            case .code:
                if character == "/", next == "/" {
                    actions.append(.type(character))
                    actions.append(.type("/"))
                    state = .lineComment
                    index += 1
                } else if character == "/", next == "*" {
                    actions.append(.type(character))
                    actions.append(.type("*"))
                    state = .blockComment
                    index += 1
                } else if character == "\"" || character == "'" || character == "`" {
                    actions.append(.type(character))
                    state = .string(character)
                    escaped = false
                } else if let closer = bracketPairs[character] {
                    actions.append(.type(character))
                    expectedClosers.append(closer)
                } else if let expected = expectedClosers.last, character == expected {
                    actions.append(.stepOverPair(character))
                    expectedClosers.removeLast()
                } else {
                    actions.append(.type(character))
                }
            }

            index += 1
        }

        return actions
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
        case .raw, .smartEditor, .exactPaste:
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
