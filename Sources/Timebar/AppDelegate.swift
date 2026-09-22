import AppKit
import SwiftUI
import TimebarCore

@main
@MainActor
struct TimebarApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = TimerController()
    private let overlay = OverlayController()
    private let popoverState = PopoverState()
    private var statusFingerprint = ""
    private var imageFingerprint = ""
    private var displayAwake = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let otherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let otherInstance {
            otherInstance.activate()
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.setAccessibilityLabel("Timebar")
            button.setAccessibilityIdentifier("timebar.status")
        }
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 364, height: 604)

        controller.onChange = { [weak self] in self?.update() }
        controller.onStart = { [weak self] in self?.popover.performClose(nil) }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wokeOrChangedSpace), name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wokeOrChangedSpace), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displaysSlept), name: NSWorkspace.screensDidSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displaysWoke), name: NSWorkspace.screensDidWakeNotification, object: nil
        )
        update()

        if !UserDefaults.standard.bool(forKey: "hasLaunched.v1") {
            UserDefaults.standard.set(true, forKey: "hasLaunched.v1")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.saveSession()
        overlay.close()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func popoverWillShow(_ notification: Notification) { controller.setPopoverVisible(true) }

    func popoverDidClose(_ notification: Notification) {
        controller.setPopoverVisible(false)
        popover.contentViewController = nil
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        controller.refresh()
        if popover.contentViewController == nil {
            popover.contentViewController = NSHostingController(
                rootView: PopoverView(controller: controller, state: popoverState)
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func screenChanged() {
        overlay.invalidateLayout()
        controller.refresh()
    }
    @objc private func wokeOrChangedSpace() { screenChanged() }
    @objc private func displaysSlept() {
        displayAwake = false
        controller.setDisplayAwake(false)
    }
    @objc private func displaysWoke() {
        displayAwake = true
        overlay.invalidateLayout()
        controller.setDisplayAwake(true)
    }

    private func update() {
        guard displayAwake else { return }
        overlay.update(session: controller.session, now: controller.now, appearance: controller.appearance)
        controller.setPixelWidth(overlay.maximumPixelWidth)
        let title = controller.appearance.showMenuCountdown && controller.session.isActive ? " \(controller.clock)" : ""
        let imageKey = "\(controller.session.phase)-\(controller.percent)"
        let fingerprint = "\(imageKey)-\(title)"
        guard fingerprint != statusFingerprint, let button = statusItem?.button else { return }
        statusFingerprint = fingerprint
        if imageFingerprint != imageKey {
            imageFingerprint = imageKey
            button.image = statusImage()
        }
        if button.title != title { button.title = title }
        let state: String
        switch controller.session.phase {
        case .idle: state = "Choose a timer"
        case .finished: state = "Time’s up"
        case .running: state = "\(controller.percent)% remaining · Click for timer controls"
        case .paused: state = "Paused · \(controller.clock) left · \(controller.percent)% remaining"
        }
        button.toolTip = "Timebar · \(state)"
        button.setAccessibilityValue(state)
    }

    private func statusImage() -> NSImage {
        if controller.session.phase == .finished {
            return NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Timer finished")!
        }
        if controller.session.phase == .paused {
            return NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Timer paused")!
        }
        if controller.session.phase == .idle {
            return NSImage(systemSymbolName: "timer", accessibilityDescription: "Timebar")!
        }
        let fraction = controller.fraction
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            NSColor.black.withAlphaComponent(0.25).setStroke()
            let track = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            track.lineWidth = 1.6
            track.stroke()
            NSColor.black.setStroke()
            let arc = NSBezierPath()
            arc.lineWidth = 1.6
            arc.lineCapStyle = .round
            arc.appendArc(withCenter: center, radius: 7, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
