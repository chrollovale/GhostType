import SwiftUI
import AppKit

// MARK: - Minimal App Logo View
struct LogoView: View {
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(AppTheme.inset)
            .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
            .overlay(DotMatrixMark(dotSize: size * 0.11, spacing: size * 0.08))
        .frame(width: size, height: size)
    }
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @StateObject private var kbPanel = KeyboardPanelController.shared

    var body: some View {
        VStack(spacing: 12) {
            headerBar
                .padding(.horizontal, 14)
                .padding(.top, 14)

            HSplitView {
                // Left Column: Text Input & Mode Options
                VStack(alignment: .leading, spacing: 12) {
                    inputHeaderToolbar

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $vm.inputText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(AppTheme.inset)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(AppTheme.line, lineWidth: 1)
                            )

                        if vm.inputText.isEmpty {
                            Text("Paste or type the completed code/text you want to inject here...")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(AppTheme.secondaryInk.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                    }

                    // Mode Specific Configuration
                    modeConfigurationBox
                }
                .padding(14)
                .frame(minWidth: 390, maxWidth: .infinity, maxHeight: .infinity)
                .appCard()

                // Right Column: Settings & Live Preview
                VStack(alignment: .leading, spacing: 14) {
                    Text("Injection Settings")
                        .font(.headline)

                    // Countdown Setting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Focus Countdown:", systemImage: "timer")
                            Spacer()
                            Text("\(Int(vm.countdownSeconds)) seconds")
                                .fontWeight(.medium)
                        }
                        Slider(value: $vm.countdownSeconds, in: 2...10, step: 1)
                        Text("Time to click into your target window before typing.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    // Keystroke Pace Setting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Minimum Key Interval:", systemImage: "speedometer")
                            Spacer()
                            Text("\(Int(vm.keyIntervalMs)) ms")
                                .fontWeight(.medium)
                        }
                        Slider(value: $vm.keyIntervalMs, in: 8...100, step: 2)
                            .disabled(vm.selectedMode == .exactPaste)
                        Text(vm.selectedMode == .exactPaste
                             ? "A single paste is used, so key interval doesn't apply."
                             : "Minimum time between key starts; event hold time is included.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    Toggle(isOn: $vm.remoteCompatibleInput) {
                        Label("VM / remote target", systemImage: "display.2")
                    }
                    .help("Uses longer key holds for virtual machines and remote desktops.")

                    // Toggles
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $vm.playBeeps) {
                            Label("Audio beep on countdown", systemImage: "speaker.wave.2")
                        }

                        Toggle(isOn: $vm.isAlwaysOnTop) {
                            Label("Keep window on top", systemImage: "pin.fill")
                        }
                        .onChange(of: vm.isAlwaysOnTop) { newValue in
                            vm.updateWindowLevel(isTop: newValue)
                        }
                    }

                    Rectangle()
                        .fill(AppTheme.line)
                        .frame(height: 1)

                    // Live Payload Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Payload Preview:")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ScrollView {
                            Text(vm.generatedPayload.isEmpty ? "(Nothing to inject)" : vm.generatedPayload)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppTheme.line.opacity(0.7), lineWidth: 0.75))
                    }

                    Spacer()
                }
                .padding(14)
                .frame(minWidth: 280, maxWidth: 340, maxHeight: .infinity)
                .appCard()
            }
            .padding(.horizontal, 14)

            footerBar
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(minWidth: 900, minHeight: 640)
        .background(AppTheme.canvas.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.blue)
        .preferredColorScheme(.light)
        .onAppear {
            vm.updateWindowLevel(isTop: vm.isAlwaysOnTop)
            vm.engine.checkAccessibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.engine.checkAccessibility()
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            LogoView(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("GhostType")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Precise Text Injection")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Spacer()

            // Virtual Keyboard Toggle
            Button(action: { kbPanel.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard.fill")
                    Text(kbPanel.isVisible ? "Hide Keyboard" : "Keyboard")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(kbPanel.isVisible ? AppTheme.blue : AppTheme.secondaryInk)
            .disabled(vm.engine.isCountingDown || vm.engine.isInjecting)

            // Accessibility Badge
            if vm.engine.isAccessibilityTrusted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Color(red: 0.18, green: 0.53, blue: 0.34))
                    Text("Accessibility Granted")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.18, green: 0.53, blue: 0.34))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.88, green: 0.94, blue: 0.89), in: Capsule())
            } else {
                Button(action: { vm.engine.promptAccessibility() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(red: 0.65, green: 0.39, blue: 0.08))
                        Text("Enable Accessibility")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.65, green: 0.39, blue: 0.08))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.97, green: 0.92, blue: 0.82), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .appCard()
    }

    // MARK: - Input Toolbar
    private var inputHeaderToolbar: some View {
        HStack {
            Text("Source Code / Text")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Button(action: { vm.pasteFromClipboard() }) {
                Label("Paste Clipboard", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: { vm.clearInput() }) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.inputText.isEmpty)
        }
    }

    // MARK: - Mode Configuration
    private var modeConfigurationBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Injection Mode:", selection: $vm.selectedMode) {
                ForEach(InjectionMode.allCases) { mode in
                    Text(mode.pickerTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: vm.payloadValidationError == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(vm.payloadValidationError == nil ? AppTheme.blue : Color.red)
                    .font(.caption)
                Text(vm.payloadValidationError ?? vm.selectedMode.description)
                    .font(.caption)
                    .foregroundStyle(vm.payloadValidationError == nil ? AppTheme.secondaryInk : Color.red)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(vm.payloadValidationError == nil ? AppTheme.blueSoft.opacity(0.35) : Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            if vm.selectedMode.usesTargetPath {
                HStack {
                    Text("Target Path:")
                        .font(.caption)
                        .fontWeight(.medium)
                    TextField("e.g. src/SQLiteJDBCExample.java", text: $vm.targetFilePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .padding(10)
        .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(AppTheme.line, lineWidth: 0.8))
    }

    // MARK: - Footer & Action Button
    private var footerBar: some View {
        HStack(spacing: 16) {
            if vm.engine.isCountingDown {
                // Countdown View
                HStack(spacing: 12) {
                    Text("\(vm.engine.countdownRemaining)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.selectedMode == .base64 || vm.selectedMode == .heredoc
                             ? "Click into the TERMINAL window now!"
                             : "Click into your target editor now!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(vm.engine.progressText)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }

                    Spacer()

                    Button(action: { vm.engine.cancelInjection() }) {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            } else if vm.engine.isInjecting {
                // Progress View
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ProgressView(value: vm.engine.progress)
                            .progressViewStyle(.linear)
                            .tint(AppTheme.blue)
                        Button(action: { vm.engine.cancelInjection() }) {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    Text(vm.engine.progressText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            } else {
                // Idle State
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.engine.progressText.isEmpty ? "Ready to inject." : vm.engine.progressText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryInk)
                    Text("\(vm.inputText.count) characters prepared")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk.opacity(0.7))
                }

                Spacer()

                Button(action: { vm.triggerInjection() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("\(vm.selectedMode == .exactPaste ? "Paste" : "Inject") (in \(Int(vm.countdownSeconds))s)")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.generatedPayload.isEmpty || vm.payloadValidationError != nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCard()
    }
}

private extension View {
    func appCard() -> some View {
        background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 0.8))
    }
}
