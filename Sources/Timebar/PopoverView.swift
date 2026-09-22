import AppKit
import SwiftUI
import TimebarCore

enum PanelTab: String, CaseIterable {
    case timer = "Timer"
    case appearance = "Appearance"
}

/// Retain only the user's input between openings, not the SwiftUI view hierarchy.
@MainActor
final class PopoverState: ObservableObject {
    @Published var tab: PanelTab = .timer
    @Published var hours = "0"
    @Published var minutes = "25"
    @Published var seconds = "0"
}

@MainActor
struct PopoverView: View {
    @ObservedObject var controller: TimerController
    @ObservedObject var state: PopoverState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                Text("Timebar").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.tab = state.tab == .timer ? .appearance : .timer
                    }
                } label: {
                    Image(systemName: state.tab == .timer ? "slider.horizontal.3" : "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(state.tab == .timer ? "Appearance and options" : "Back to timer")
                .accessibilityLabel(state.tab == .timer ? "Appearance and options" : "Back to timer")
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().opacity(0.6)

            Group {
                if state.tab == .timer { TimerPane(controller: controller, state: state) }
                else { AppearancePane(controller: controller) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider().opacity(0.6)
            HStack {
                Text(state.tab == .timer ? "A little space to focus." : "Changes appear on your line instantly.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 364, height: 604)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.78))
        .tint(accent)
        .focusEffectDisabled()
    }

    private var accent: Color { Color(nsColor: controller.appearance.color.nsColor) }
}

@MainActor
private struct TimerPane: View {
    @ObservedObject var controller: TimerController
    @ObservedObject var state: PopoverState

    private let presets: [(minutes: Int, name: String)] = [
        (5, "Short break"), (15, "Quick focus"), (25, "Pomodoro"),
        (50, "Deep work"), (60, "One hour"), (90, "Long focus"),
    ]

    private var accent: Color { Color(nsColor: controller.appearance.color.nsColor) }
    private var isActive: Bool { controller.session.isActive }
    private var customDuration: TimeInterval? { DurationText.custom(hours: state.hours, minutes: state.minutes, seconds: state.seconds) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(controller.session.phase == .paused ? Color.orange : accent)
                            .frame(width: 5, height: 5)
                        Text(controller.status).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isActive {
                        Text("\(controller.percent)% left")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(controller.clock)
                    .font(.system(size: controller.clock.count > 5 ? 44 : 54, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1.5)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(controller.clock)
                    .frame(height: 60, alignment: .leading)

                HStack(spacing: 4) {
                    Text(sessionDetail)
                    Spacer()
                    if let deadline = controller.session.deadline {
                        Text("Until \(deadline, style: .time)")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(accent.opacity(0.10))
                        Capsule().fill(accent.opacity(controller.appearance.opacity))
                            .frame(width: geometry.size.width * (controller.session.phase == .idle ? 1 : controller.fraction))
                    }
                }
                .frame(height: 3)
                .padding(.top, 3)
                .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                if isActive {
                    Button(action: controller.pauseOrResume) {
                        Label(controller.session.phase == .paused ? "Resume" : "Pause", systemImage: controller.session.phase == .paused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionStyle(prominent: true, accent: accent))
                    .keyboardShortcut(.space, modifiers: [])

                    Button(action: controller.stop) {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionStyle(prominent: false, accent: accent))
                    .help("Stop and clear this timer")

                    Button(action: controller.restart) {
                        Image(systemName: "arrow.counterclockwise").frame(width: 18)
                    }
                    .buttonStyle(ActionStyle(prominent: false, accent: accent))
                    .help("Restart this timer")
                    .accessibilityLabel("Restart timer")
                } else {
                    Button(action: controller.restart) {
                        Label(controller.session.phase == .finished ? "Go again · \(DurationText.label(controller.session.duration))" : "Start \(DurationText.label(controller.session.duration)) timer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ActionStyle(prominent: true, accent: accent))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: isActive ? "Start a new timer" : "Quick start")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(presets, id: \.minutes) { preset in
                        Button { controller.start(TimeInterval(preset.minutes * 60)) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text("\(preset.minutes)").font(.system(size: 21, weight: .medium, design: .rounded))
                                    Text("min").font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Text(preset.name).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(tileBackground(preset.minutes), in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(accent.opacity(controller.session.duration == Double(preset.minutes * 60) ? 0.35 : 0), lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(preset.minutes) minute timer, \(preset.name)")
                        .help("Start a \(preset.minutes) minute timer immediately")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                SectionLabel(text: "Custom duration")
                HStack(alignment: .bottom, spacing: 8) {
                    DurationField("Hours", text: $state.hours, maximum: 24, onSubmit: startCustom)
                    DurationField("Minutes", text: $state.minutes, maximum: 59, onSubmit: startCustom)
                    DurationField("Seconds", text: $state.seconds, maximum: 59, onSubmit: startCustom)
                    Button(action: startCustom) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(ActionStyle(prominent: true, accent: accent))
                    .disabled(customDuration == nil)
                    .accessibilityLabel("Start custom timer")
                    .help("Start the custom duration")
                }
                if customDuration == nil {
                    Text("Enter 1 second to 24 hours. Minutes and seconds: 0–59.")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
    }

    private var sessionDetail: String {
        switch controller.session.phase {
        case .idle: return "Choose a preset or set your own duration."
        case .running: return "\(DurationText.label(controller.session.duration)) timer"
        case .paused: return "Paused · your remaining time is saved"
        case .finished: return "\(DurationText.label(controller.session.duration)) complete · 0% remaining"
        }
    }

    private func tileBackground(_ minutes: Int) -> Color {
        controller.session.duration == Double(minutes * 60) ? accent.opacity(0.09) : Color.primary.opacity(0.035)
    }

    private func startCustom() {
        guard let duration = customDuration else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        controller.start(duration)
    }
}

@MainActor
private struct AppearancePane: View {
    @ObservedObject var controller: TimerController
    private var accent: Color { Color(nsColor: controller.appearance.color.nsColor) }
    private let swatches: [(name: String, color: BarColor)] = [
        ("Blue", .blue), ("Mint", .mint), ("Amber", .amber),
        ("Rose", .rose), ("Lavender", .lavender), ("White", .white),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Make it your own")
                    LinePreview(appearance: controller.appearance)
                    HStack(spacing: 8) {
                        ForEach(AppearanceSettings.Preset.allCases, id: \.self) { preset in
                            Button(preset.rawValue) { controller.appearance.apply(preset) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    Text("Color").font(.system(size: 12, weight: .medium))
                    HStack(spacing: 6) {
                        ForEach(swatches, id: \.name) { swatch in
                            Button { controller.appearance.color = swatch.color } label: {
                                Circle()
                                    .fill(Color(nsColor: swatch.color.nsColor))
                                    .frame(width: 23, height: 23)
                                    .overlay {
                                        if controller.appearance.color == swatch.color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.7))
                                        }
                                    }
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(controller.appearance.color == swatch.color ? 0.35 : 0), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(swatch.name) line")
                            .help(swatch.name)
                        }
                        Spacer(minLength: 4)
                        ColorPicker("Custom", selection: customColor, supportsOpacity: false)
                            .font(.system(size: 11))
                            .controlSize(.mini)
                            .fixedSize()
                            .help("Choose any color")
                            .accessibilityLabel("Custom line color")
                    }
                }

                VStack(spacing: 13) {
                    sliderRow("Thickness", value: $controller.appearance.thickness, range: AppearanceSettings.thicknessRange, step: 0.5, valueLabel: "\(controller.appearance.thickness.formatted(.number.precision(.fractionLength(0...1)))) pt")
                    sliderRow("Opacity", value: $controller.appearance.opacity, range: 0.1...1, step: 0.05, valueLabel: "\(Int((controller.appearance.opacity * 100).rounded()))%")
                }

                Divider()

                VStack(spacing: 12) {
                    HStack {
                        Text("Position").font(.system(size: 12))
                        Spacer()
                        Picker("Position", selection: $controller.appearance.placement) {
                            ForEach(AppearanceSettings.Placement.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().fixedSize()
                    }
                    HStack {
                        Text("Show on").font(.system(size: 12))
                        Spacer()
                        Picker("Displays", selection: $controller.appearance.displays) {
                            ForEach(AppearanceSettings.Displays.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Faint track behind the line", isOn: $controller.appearance.showTrack)
                    Toggle("Countdown in menu bar", isOn: $controller.appearance.showMenuCountdown)
                    Toggle("Gentle sound when finished", isOn: $controller.appearance.playCompletionSound)
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

                Text("Your line stays visible while paused. With an auto-hidden menu bar, it keeps its position below the menu area.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var customColor: Binding<Color> {
        Binding {
            accent
        } set: { color in
            guard let color = NSColor(color).usingColorSpace(.sRGB) else { return }
            controller.appearance.color = BarColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, valueLabel: String) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(valueLabel).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step) { Text(title) }
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
        }
    }
}

private struct LinePreview: View {
    let appearance: AppearanceSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                Text("Finder").fontWeight(.semibold)
                Text("File").opacity(0.6)
                Text("Edit").opacity(0.6)
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
                Text("9:41")
            }
            .font(.system(size: 8))
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Color.white.opacity(0.07))
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    if appearance.showTrack {
                        Rectangle().fill(Color(nsColor: appearance.color.nsColor).opacity(0.08))
                            .frame(height: appearance.thickness)
                    }
                    Rectangle().fill(Color(nsColor: appearance.color.nsColor).opacity(appearance.opacity))
                        .frame(width: geometry.size.width * 0.68, height: appearance.thickness)
                }
            }
            .overlay(alignment: .center) {
                Text("Quietly keeping you on track.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
            .frame(height: 47)
        }
        .foregroundStyle(.white.opacity(0.85))
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.08)))
        .accessibilityLabel("Line appearance preview")
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
    }
}

private struct ActionStyle: ButtonStyle {
    let prominent: Bool
    let accent: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .frame(height: 37)
            .foregroundStyle(prominent ? Color(nsColor: .labelColor) : .primary)
            .background(
                prominent ? accent.opacity(configuration.isPressed ? 0.38 : 0.22) : Color.primary.opacity(configuration.isPressed ? 0.10 : 0.05),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(prominent ? accent.opacity(0.25) : .clear))
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
