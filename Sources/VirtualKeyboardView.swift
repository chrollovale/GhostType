import SwiftUI
import CoreGraphics

// MARK: - macOS Virtual Key Codes (ANSI)
// These map to Windows key codes when passed through Parallels Desktop.
enum VK {
    // Letters (A-Z)
    static let a: CGKeyCode = 0x00; static let s: CGKeyCode = 0x01
    static let d: CGKeyCode = 0x02; static let f: CGKeyCode = 0x03
    static let h: CGKeyCode = 0x04; static let g: CGKeyCode = 0x05
    static let z: CGKeyCode = 0x06; static let x: CGKeyCode = 0x07
    static let c: CGKeyCode = 0x08; static let v: CGKeyCode = 0x09
    static let b: CGKeyCode = 0x0B; static let q: CGKeyCode = 0x0C
    static let w: CGKeyCode = 0x0D; static let e: CGKeyCode = 0x0E
    static let r: CGKeyCode = 0x0F; static let y: CGKeyCode = 0x10
    static let t: CGKeyCode = 0x11; static let n1: CGKeyCode = 0x12
    static let n2: CGKeyCode = 0x13; static let n3: CGKeyCode = 0x14
    static let n4: CGKeyCode = 0x15; static let n6: CGKeyCode = 0x16
    static let n5: CGKeyCode = 0x17; static let equals: CGKeyCode = 0x18
    static let n9: CGKeyCode = 0x19; static let n7: CGKeyCode = 0x1A
    static let minus: CGKeyCode = 0x1B; static let n8: CGKeyCode = 0x1C
    static let n0: CGKeyCode = 0x1D; static let rightBracket: CGKeyCode = 0x1E
    static let o: CGKeyCode = 0x1F; static let u: CGKeyCode = 0x20
    static let leftBracket: CGKeyCode = 0x21; static let i: CGKeyCode = 0x22
    static let p: CGKeyCode = 0x23; static let l: CGKeyCode = 0x25
    static let j: CGKeyCode = 0x26; static let quote: CGKeyCode = 0x27
    static let k: CGKeyCode = 0x28; static let semicolon: CGKeyCode = 0x29
    static let backslash: CGKeyCode = 0x2A; static let comma: CGKeyCode = 0x2B
    static let slash: CGKeyCode = 0x2C; static let n: CGKeyCode = 0x2D
    static let m: CGKeyCode = 0x2E; static let period: CGKeyCode = 0x2F
    static let grave: CGKeyCode = 0x32

    // Control keys
    static let returnKey: CGKeyCode = 0x24; static let tab: CGKeyCode = 0x30
    static let space: CGKeyCode = 0x31; static let delete: CGKeyCode = 0x33 // Backspace
    static let escape: CGKeyCode = 0x35; static let capsLock: CGKeyCode = 0x39

    // Modifiers
    static let shift: CGKeyCode = 0x38; static let rightShift: CGKeyCode = 0x3C
    static let control: CGKeyCode = 0x3B; static let rightControl: CGKeyCode = 0x3E
    static let option: CGKeyCode = 0x3A; static let rightOption: CGKeyCode = 0x3D
    static let command: CGKeyCode = 0x37

    // Navigation
    static let insert: CGKeyCode = 0x72  // kVK_Help on Mac = Insert on Windows
    static let forwardDelete: CGKeyCode = 0x75
    static let home: CGKeyCode = 0x73; static let end: CGKeyCode = 0x77
    static let pageUp: CGKeyCode = 0x74; static let pageDown: CGKeyCode = 0x79
    static let upArrow: CGKeyCode = 0x7E; static let downArrow: CGKeyCode = 0x7D
    static let leftArrow: CGKeyCode = 0x7B; static let rightArrow: CGKeyCode = 0x7C

    // Function keys
    static let f1: CGKeyCode = 0x7A; static let f2: CGKeyCode = 0x78
    static let f3: CGKeyCode = 0x63; static let f4: CGKeyCode = 0x76
    static let f5: CGKeyCode = 0x60; static let f6: CGKeyCode = 0x61
    static let f7: CGKeyCode = 0x62; static let f8: CGKeyCode = 0x64
    static let f9: CGKeyCode = 0x65; static let f10: CGKeyCode = 0x6D
    static let f11: CGKeyCode = 0x67; static let f12: CGKeyCode = 0x6F
    static let printScreen: CGKeyCode = 0x69 // F13 on Mac
}

// MARK: - Keyboard State (Sticky Modifiers)
@MainActor
final class KeyboardState: ObservableObject {
    @Published var shiftActive = false
    @Published var ctrlActive = false
    @Published var altActive = false
    @Published var winActive = false
    @Published var statusMessage: String?

    private struct KeyRequest {
        let code: CGKeyCode
        let shift: Bool
        let control: Bool
        let option: Bool
        let command: Bool
    }

    private var pendingKeys: [KeyRequest] = []
    private var isSendingKeys = false

    enum Mod { case shift, ctrl, alt, win }

    func isActive(_ mod: Mod) -> Bool {
        switch mod {
        case .shift: return shiftActive
        case .ctrl: return ctrlActive
        case .alt: return altActive
        case .win: return winActive
        }
    }

    func toggle(_ mod: Mod) {
        switch mod {
        case .shift: shiftActive.toggle()
        case .ctrl: ctrlActive.toggle()
        case .alt: altActive.toggle()
        case .win: winActive.toggle()
        }
    }

    func clearModifiers() {
        shiftActive = false
        ctrlActive = false
        altActive = false
        winActive = false
    }

    func sendKey(_ code: CGKeyCode) {
        enqueueKey(
            code,
            shift: shiftActive,
            control: ctrlActive,
            option: altActive,
            command: winActive
        )
        clearModifiers()
    }

    func sendCopi() {
        // COPI = Ctrl + Insert (Windows Copy alternative)
        enqueueKey(VK.insert, control: true)
        clearModifiers()
    }

    func sendPasta() {
        // PASTA = Shift + Insert (Windows Paste alternative)
        enqueueKey(VK.insert, shift: true)
        clearModifiers()
    }

    private func enqueueKey(
        _ code: CGKeyCode,
        shift: Bool = false,
        control: Bool = false,
        option: Bool = false,
        command: Bool = false
    ) {
        pendingKeys.append(KeyRequest(code: code, shift: shift, control: control, option: option, command: command))
        guard !isSendingKeys else { return }

        isSendingKeys = true
        Task { @MainActor in
            while !pendingKeys.isEmpty {
                let request = pendingKeys.removeFirst()
                let sent = await KeystrokeEngine.sendSingleKey(
                    keyCode: request.code,
                    shift: request.shift,
                    control: request.control,
                    option: request.option,
                    command: request.command
                )
                statusMessage = sent ? nil : "Enable Accessibility in the main window to send keys."
            }
            isSendingKeys = false
        }
    }
}

// MARK: - Key Button View
struct KBtn: View {
    let label: String
    let subLabel: String?
    let widthUnits: CGFloat
    let heightUnits: CGFloat
    let isActive: Bool
    let accentColor: Color?
    let fontSize: CGFloat?
    let action: () -> Void

    static let unit: CGFloat = 38
    static let height: CGFloat = 30
    static let gap: CGFloat = 2

    init(_ label: String, _ sub: String? = nil, w: CGFloat = 1, h: CGFloat = 1,
         active: Bool = false, accent: Color? = nil, size: CGFloat? = nil,
         action: @escaping () -> Void) {
        self.label = label; self.subLabel = sub; self.widthUnits = w; self.heightUnits = h
        self.isActive = active; self.accentColor = accent; self.fontSize = size; self.action = action
    }

    private var keyWidth: CGFloat { widthUnits * (Self.unit + Self.gap) - Self.gap }
    private var keyHeight: CGFloat { heightUnits * (Self.height + Self.gap) - Self.gap }

    private var bgColor: Color {
        if isActive { return AppTheme.blue }
        if let accent = accentColor { return accent }
        return AppTheme.key
    }

    private var computedFontSize: CGFloat {
        if let s = fontSize { return s }
        if label.count > 5 { return 8 }
        if label.count > 3 { return 9 }
        if label.count > 1 { return 10 }
        return 13
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if let sub = subLabel {
                    Text(sub)
                        .font(.system(size: 8, weight: .regular, design: .default))
                        .foregroundColor(AppTheme.secondaryInk.opacity(0.72))
                        .offset(y: 1)
                }
                Text(label)
                    .font(.system(size: computedFontSize, weight: .medium, design: .default))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: keyWidth, height: keyHeight)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(bgColor)
                    .shadow(color: AppTheme.ink.opacity(0.12), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isActive ? AppTheme.blue.opacity(0.75) : AppTheme.line.opacity(0.75), lineWidth: 0.75)
            )
            .foregroundColor(isActive ? .white : AppTheme.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? "Space" : label)
    }
}

// MARK: - Virtual Keyboard View
struct VirtualKeyboardView: View {
    @StateObject private var state = KeyboardState()

    private let gap: CGFloat = 2
    private let sectionGap: CGFloat = 10

    var body: some View {
        VStack(spacing: 6) {
            // COPI / PASTA row
            copiPastaRow

            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 4)

            // Main keyboard
            VStack(spacing: gap) {
                functionRow
                numberRow
                HStack(spacing: sectionGap) { qwertyRowMain; navRow1 }
                HStack(spacing: sectionGap) { homeRowMain; navRow2 }
                HStack(spacing: sectionGap) { shiftRowMain; navRow3 }
                bottomRow
            }

            if let statusMessage = state.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        .padding(8)
        .preferredColorScheme(.light)
    }

    // MARK: - COPI & PASTA
    private var copiPastaRow: some View {
        HStack(spacing: 8) {
            Button(action: { state.sendCopi() }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("COPI").font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Ctrl + Insert").font(.system(size: 9, weight: .regular)).opacity(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [AppTheme.blue, Color(red: 0.16, green: 0.27, blue: 0.82)],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: AppTheme.blue.opacity(0.18), radius: 3, y: 1)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button(action: { state.sendPasta() }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PASTA").font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Shift + Insert").font(.system(size: 9, weight: .regular)).opacity(0.8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.37, green: 0.47, blue: 1.0), AppTheme.blue],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: AppTheme.blue.opacity(0.16), radius: 3, y: 1)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Function Row
    private var functionRow: some View {
        HStack(spacing: gap) {
            k("Esc", VK.escape)
            Spacer().frame(width: 6)
            k("F1", VK.f1); k("F2", VK.f2); k("F3", VK.f3); k("F4", VK.f4)
            Spacer().frame(width: 4)
            k("F5", VK.f5); k("F6", VK.f6); k("F7", VK.f7); k("F8", VK.f8)
            Spacer().frame(width: 4)
            k("F9", VK.f9); k("F10", VK.f10); k("F11", VK.f11); k("F12", VK.f12)
            Spacer().frame(width: 6)
            k("PrtSc", VK.printScreen)
            k("Ins", VK.insert, accent: AppTheme.blueSoft)
            k("Del", VK.forwardDelete)
        }
    }

    // MARK: - Number Row
    private var numberRow: some View {
        HStack(spacing: gap) {
            k2("~", "`", VK.grave); k2("!", "1", VK.n1); k2("@", "2", VK.n2)
            k2("#", "3", VK.n3); k2("$", "4", VK.n4); k2("%", "5", VK.n5)
            k2("^", "6", VK.n6); k2("&", "7", VK.n7); k2("*", "8", VK.n8)
            k2("(", "9", VK.n9); k2(")", "0", VK.n0)
            k2("_", "-", VK.minus); k2("+", "=", VK.equals)
            k("Backspace", VK.delete, w: 2.0)
        }
    }

    // MARK: - QWERTY Row (Main)
    private var qwertyRowMain: some View {
        HStack(spacing: gap) {
            k("Tab", VK.tab, w: 1.5)
            k("Q", VK.q); k("W", VK.w); k("E", VK.e); k("R", VK.r); k("T", VK.t)
            k("Y", VK.y); k("U", VK.u); k("I", VK.i); k("O", VK.o); k("P", VK.p)
            k2("{", "[", VK.leftBracket); k2("}", "]", VK.rightBracket)
            k2("|", "\\", VK.backslash, w: 1.5)
        }
    }

    // MARK: - Home Row (Main)
    private var homeRowMain: some View {
        HStack(spacing: gap) {
            k("CapsLk", VK.capsLock, w: 1.75)
            k("A", VK.a); k("S", VK.s); k("D", VK.d); k("F", VK.f); k("G", VK.g)
            k("H", VK.h); k("J", VK.j); k("K", VK.k); k("L", VK.l)
            k2(":", ";", VK.semicolon); k2("\"", "'", VK.quote)
            k("Enter", VK.returnKey, w: 2.25)
        }
    }

    // MARK: - Shift Row (Main)
    private var shiftRowMain: some View {
        HStack(spacing: gap) {
            modKey("Shift", .shift, w: 2.25)
            k("Z", VK.z); k("X", VK.x); k("C", VK.c); k("V", VK.v); k("B", VK.b)
            k("N", VK.n); k("M", VK.m)
            k2("<", ",", VK.comma); k2(">", ".", VK.period); k2("?", "/", VK.slash)
            modKey("Shift", .shift, w: 2.75)
        }
    }

    // MARK: - Bottom Row
    private var bottomRow: some View {
        HStack(spacing: gap) {
            modKey("Ctrl", .ctrl, w: 1.5)
            KBtn("Fn", w: 1, action: {})
                .disabled(true)
                .help("Fn is reserved by macOS and can't be forwarded as a physical key.")
            modKey("Win", .win, w: 1.25)
            modKey("Alt", .alt, w: 1.25)
            k("", VK.space, w: 6.0)  // Space bar
            modKey("Alt", .alt, w: 1.25)
            modKey("Ctrl", .ctrl, w: 1.5)
        }
    }

    // MARK: - Navigation Cluster (Right Side)
    private var navRow1: some View {
        HStack(spacing: gap) {
            k("Home", VK.home); k("↑", VK.upArrow); k("PgUp", VK.pageUp)
        }
    }
    private var navRow2: some View {
        HStack(spacing: gap) {
            k("←", VK.leftArrow)
            KBtn("·", w: 1, accent: AppTheme.blueSoft, action: {})
                .disabled(true)
                .help("There is no key in this position.")
            k("→", VK.rightArrow)
        }
    }
    private var navRow3: some View {
        HStack(spacing: gap) {
            k("End", VK.end); k("↓", VK.downArrow); k("PgDn", VK.pageDown)
        }
    }

    // MARK: - Key Helpers
    /// Standard key
    private func k(_ label: String, _ code: CGKeyCode, w: CGFloat = 1, accent: Color? = nil) -> KBtn {
        KBtn(label, w: w, accent: accent) { state.sendKey(code) }
    }
    /// Key with shifted sub-label
    private func k2(_ sub: String, _ main: String, _ code: CGKeyCode, w: CGFloat = 1) -> KBtn {
        KBtn(main, sub, w: w) { state.sendKey(code) }
    }
    /// Sticky modifier key
    private func modKey(_ label: String, _ mod: KeyboardState.Mod, w: CGFloat = 1) -> KBtn {
        KBtn(label, w: w, active: state.isActive(mod)) { state.toggle(mod) }
    }
}
