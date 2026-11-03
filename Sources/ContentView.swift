import SwiftUI
import AppKit

// MARK: - Minimal App Logo View
struct LogoView: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            // Dark Squircle Base
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.12, green: 0.14, blue: 0.20), Color(red: 0.05, green: 0.06, blue: 0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)

            // Inner Keycap Top Face
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.19, green: 0.22, blue: 0.30), Color(red: 0.11, green: 0.13, blue: 0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.10)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        .padding(size * 0.10)
                )

            // Minimalist Neon Glyph: Chevron > and Downward Arrow
            HStack(spacing: size * 0.02) {
                Text(">")
                    .font(.system(size: size * 0.38, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.95, blue: 0.90), Color(red: 0.3, green: 0.6, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "arrow.down")
                    .font(.system(size: size * 0.30, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.95, blue: 0.90), Color(red: 0.4, green: 0.5, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @StateObject private var kbPanel = KeyboardPanelController.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Content Area
            HSplitView {
                // Left Column: Text Input & Mode Options
                VStack(alignment: .leading, spacing: 12) {
                    inputHeaderToolbar

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $vm.inputText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        if vm.inputText.isEmpty {
                            Text("Paste or type the completed code/text you want to inject here...")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }
                    }

                    // Mode Specific Configuration
                    modeConfigurationBox
                }
                .padding()
                .frame(minWidth: 380, maxWidth: .infinity)

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
                            .foregroundColor(.secondary)
                    }

                    // Typing Speed Setting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Keystroke Delay:", systemImage: "speedometer")
                            Spacer()
                            Text("\(Int(vm.charDelayMs)) ms")
                                .fontWeight(.medium)
                        }
                        Slider(value: $vm.charDelayMs, in: 15...80, step: 5)
                        Text("25–40ms is required for Parallels VM to prevent dropped keys.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

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

                    Divider()

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
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }

                    Spacer()
                }
                .padding()
                .frame(minWidth: 260, maxWidth: 320)
            }

            Divider()

            // Bottom Action & Status Footer
            footerBar
        }
        .frame(minWidth: 720, minHeight: 540)
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
                Text("KeyInjector")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Hardware KeyCode & Code Injector")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            .tint(kbPanel.isVisible ? .accentColor : nil)

            // Accessibility Badge
            if vm.engine.isAccessibilityTrusted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Accessibility Granted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .cornerRadius(12)
            } else {
                Button(action: { vm.engine.promptAccessibility() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Enable Accessibility")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
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
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Informational guidance per mode
            if vm.selectedMode == .raw {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Direct Typing into smart editors (Monaco/VS Code) triggers auto-closing brackets {} and double-indentation. Use **Base64 One-Liner** into the Terminal for 100% accuracy.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            } else if vm.selectedMode == .base64 {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Recommended: Focus the **Terminal** prompt (`chef@...:~$`). Writes the full file in 1 single line without bracket or indentation errors.")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }

            if vm.selectedMode == .base64 || vm.selectedMode == .heredoc {
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Footer & Action Button
    private var footerBar: some View {
        HStack(spacing: 16) {
            if vm.engine.isCountingDown {
                // Countdown View
                HStack(spacing: 12) {
                    Text("\(vm.engine.countdownRemaining)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.selectedMode == .base64 ? "Click into the TERMINAL window now!" : "Click into your target window now!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(vm.engine.progressText)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        Button(action: { vm.engine.cancelInjection() }) {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    Text(vm.engine.progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Idle State
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.engine.progressText.isEmpty ? "Ready to inject." : vm.engine.progressText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(vm.inputText.count) characters prepared")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                Button(action: { vm.triggerInjection() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Inject (in \(Int(vm.countdownSeconds))s)")
                    }
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.generatedPayload.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
