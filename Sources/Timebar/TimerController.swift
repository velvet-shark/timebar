import AppKit
import Combine
import TimebarCore

@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var session: TimerSession
    private(set) var now = Date()
    @Published var appearance: AppearanceSettings {
        didSet {
            guard appearance != oldValue else { return }
            if let data = try? JSONEncoder().encode(appearance) {
                defaults.set(data, forKey: "appearance.v1")
            }
            onChange?()
            scheduleNextRefresh()
        }
    }

    var onChange: (() -> Void)?
    var onStart: (() -> Void)?
    private let defaults: UserDefaults
    private var ticker: Timer?
    private var completionSound: NSSound?
    private var popoverVisible = false
    private var displayAwake = true
    private var pixelWidth: Double = 1
    private var displayedSecond = -1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.session = .restored(from: defaults.data(forKey: "session.v1"), at: Date())
        self.appearance = .restored(from: defaults.data(forKey: "appearance.v1"))
        saveSession()
        scheduleNextRefresh()
    }

    var remaining: TimeInterval { session.remaining(at: now) }
    var fraction: Double { session.fractionRemaining(at: now) }
    var percent: Int { Int(ceil(fraction * 100)) }
    var clock: String { DurationText.clock(session.phase == .idle ? session.duration : remaining) }

    var status: String {
        switch session.phase {
        case .idle: return "Ready when you are"
        case .running: return "Time to focus"
        case .paused: return "Take your time"
        case .finished: return "Time’s up. Nicely done."
        }
    }

    func start(_ seconds: TimeInterval) {
        now = Date()
        guard session.start(seconds: seconds, at: now) else { return }
        commit()
        onStart?()
    }

    func pauseOrResume() {
        now = Date()
        if session.refresh(at: now) { finish(); return }
        if session.phase == .running { session.pause(at: now) }
        else if session.phase == .paused { session.resume(at: now) }
        commit()
    }

    func stop() {
        session.stop()
        commit()
    }

    func restart() { start(session.duration) }

    func refresh() {
        now = Date()
        // Mutating a @Published struct publishes even when refresh changes nothing.
        var refreshed = session
        if refreshed.refresh(at: now) {
            session = refreshed
            finish()
        } else {
            let second = Int(ceil(remaining))
            if popoverVisible, second != displayedSecond {
                displayedSecond = second
                objectWillChange.send()
            }
            onChange?()
            scheduleNextRefresh()
        }
    }

    func setPopoverVisible(_ visible: Bool) {
        popoverVisible = visible
        displayedSecond = -1
        refresh()
    }

    func setDisplayAwake(_ awake: Bool) {
        displayAwake = awake
        refresh()
    }

    func setPixelWidth(_ width: Double) {
        guard pixelWidth != width else { return }
        pixelWidth = width
        scheduleNextRefresh()
    }

    func saveSession() {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: "session.v1")
        }
    }

    private func finish() {
        commit()
        if appearance.playCompletionSound {
            completionSound = NSSound(named: "Glass")
            completionSound?.volume = 0.35
            completionSound?.play()
        }
    }

    private func commit() {
        saveSession()
        onChange?()
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        ticker?.invalidate()
        ticker = nil
        let date = Date()
        guard let delay = TimerRefreshPolicy.delay(
            for: session, at: date, pixelWidth: pixelWidth,
            showsSeconds: popoverVisible || appearance.showMenuCountdown,
            displayAwake: displayAwake
        ) else { return }
        let timer = Timer(timeInterval: max(0.001, delay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = delay >= session.remaining(at: date) ? 0 : min(0.1, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }
}

extension BarColor {
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}
