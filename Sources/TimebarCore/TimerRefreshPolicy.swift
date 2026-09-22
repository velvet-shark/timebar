import Foundation

/// Schedule visible changes, not a fixed polling loop. Deadlines remain the source of truth.
public enum TimerRefreshPolicy {
    public static func delay(
        for session: TimerSession,
        at date: Date,
        pixelWidth: Double,
        showsSeconds: Bool,
        displayAwake: Bool
    ) -> TimeInterval? {
        guard session.phase == .running else { return nil }
        let remaining = session.remaining(at: date)
        // Keep only the completion callback while the displays are asleep.
        guard displayAwake else { return remaining }
        let width = pixelWidth.isFinite ? max(1, pixelWidth) : 1
        let pixelInterval = min(60, max(0.25, session.duration / width))
        let interval = showsSeconds ? min(1, pixelInterval) : pixelInterval
        return min(remaining, interval)
    }
}
