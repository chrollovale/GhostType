import Foundation

enum InjectionMode: String, CaseIterable, Identifiable {
    case raw = "Direct Typing"
    case base64 = "Base64 One-Liner"
    case heredoc = "Terminal Heredoc"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .raw:
            return "Types the exact text character-by-character into whatever is focused."
        case .base64:
            return "Encodes code into a single-line base64 pipe. Best for terminals to bypass auto-indent and auto-bracket brackets."
        case .heredoc:
            return "Wraps your code in a cat << 'EOF' > filepath block for terminal insertion."
        }
    }
}
