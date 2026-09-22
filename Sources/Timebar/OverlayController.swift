import AppKit
import QuartzCore
import TimebarCore

@MainActor
private final class LinePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class LineView: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    private var pixelScale: CGFloat = 1

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func configure(appearance: AppearanceSettings, scale: CGFloat) {
        pixelScale = scale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.contentsScale = scale
        fill.contentsScale = scale
        track.frame = bounds
        track.backgroundColor = appearance.color.nsColor.withAlphaComponent(0.08).cgColor
        track.isHidden = !appearance.showTrack
        fill.backgroundColor = appearance.color.nsColor.withAlphaComponent(appearance.opacity).cgColor
        CATransaction.commit()
    }

    func update(fraction: Double) {
        let width = (bounds.width * fraction * pixelScale).rounded() / pixelScale
        let frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        guard fill.frame != frame else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = frame
        CATransaction.commit()
    }
}

@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: LinePanel] = [:]
    private var configuredAppearance: AppearanceSettings?
    private(set) var maximumPixelWidth: Double = 1

    func invalidateLayout() { configuredAppearance = nil }

    func update(session: TimerSession, now: Date, appearance: AppearanceSettings) {
        guard session.isActive else {
            if !panels.isEmpty { close() }
            return
        }

        if configuredAppearance != appearance || panels.isEmpty { configure(appearance: appearance) }
        let fraction = session.fractionRemaining(at: now)
        for panel in panels.values {
            (panel.contentView as? LineView)?.update(fraction: fraction)
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
    }

    private func configure(appearance: AppearanceSettings) {
        configuredAppearance = appearance
        let screens = appearance.displays == .all ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        maximumPixelWidth = screens.map { $0.frame.width * $0.backingScaleFactor }.max() ?? 1
        let identifiers = Set(screens.map(\.displayID))
        for identifier in Array(panels.keys) where !identifiers.contains(identifier) {
            panels.removeValue(forKey: identifier)?.close()
        }

        for screen in screens {
            let panel = panels[screen.displayID] ?? makePanel(screen: screen)
            // visibleFrame gives the actual menu-bar inset even with a side Dock.
            // When the menu bar is hidden, retain its normal height to keep the line stable.
            let menuInset = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
            let frame = BarGeometry.frame(
                screen: screen.frame,
                menuBarInset: menuInset,
                safeAreaTop: screen.safeAreaInsets.top,
                thickness: appearance.thickness,
                placement: appearance.placement,
                scale: screen.backingScaleFactor
            )
            if panel.frame != frame { panel.setFrame(frame, display: true) }
            (panel.contentView as? LineView)?.configure(
                appearance: appearance,
                scale: screen.backingScaleFactor
            )
        }
    }

    func close() {
        for panel in panels.values { panel.close() }
        panels.removeAll()
        configuredAppearance = nil
        maximumPixelWidth = 1
    }

    private func makePanel(screen: NSScreen) -> LinePanel {
        let panel = LinePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.title = "Timebar progress line"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        if #available(macOS 14.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
        panel.contentView = LineView(frame: .zero)
        panels[screen.displayID] = panel
        return panel
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
