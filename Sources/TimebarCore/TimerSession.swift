import Foundation

public struct TimerSession: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case idle, running, paused, finished
    }

    public static let maximumDuration: TimeInterval = 24 * 60 * 60
    public private(set) var phase: Phase = .idle
    public private(set) var duration: TimeInterval = 25 * 60
    public private(set) var deadline: Date?
    public private(set) var pausedRemaining: TimeInterval = 0

    public init() {}

    public var isActive: Bool { phase == .running || phase == .paused }

    public func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .idle, .finished: return 0
        case .paused: return min(duration, max(0, pausedRemaining))
        case .running: return min(duration, max(0, deadline?.timeIntervalSince(date) ?? 0))
        }
    }

    public func fractionRemaining(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / duration))
    }

    @discardableResult
    public mutating func start(seconds: TimeInterval, at date: Date) -> Bool {
        guard seconds.isFinite, (1...Self.maximumDuration).contains(seconds) else { return false }
        duration = seconds
        deadline = date.addingTimeInterval(seconds)
        pausedRemaining = 0
        phase = .running
        return true
    }

    /// Returns true only on the transition into the finished state.
    @discardableResult
    public mutating func refresh(at date: Date) -> Bool {
        guard phase == .running, remaining(at: date) <= 0 else { return false }
        phase = .finished
        deadline = nil
        pausedRemaining = 0
        return true
    }

    public mutating func pause(at date: Date) {
        guard phase == .running else { return }
        if refresh(at: date) { return }
        pausedRemaining = remaining(at: date)
        deadline = nil
        phase = .paused
    }

    public mutating func resume(at date: Date) {
        guard phase == .paused else { return }
        deadline = date.addingTimeInterval(pausedRemaining)
        pausedRemaining = 0
        phase = .running
    }

    public mutating func stop() {
        phase = .idle
        deadline = nil
        pausedRemaining = 0
    }

    public mutating func restart(at date: Date) {
        start(seconds: duration, at: date)
    }

    public static func restored(from data: Data?, at date: Date) -> Self {
        guard let data, var session = try? JSONDecoder().decode(Self.self, from: data),
              session.duration.isFinite,
              (1...maximumDuration).contains(session.duration),
              session.pausedRemaining.isFinite,
              (0...session.duration).contains(session.pausedRemaining),
              session.phase != .running || session.deadline?.timeIntervalSinceReferenceDate.isFinite == true,
              session.phase != .paused || session.pausedRemaining > 0
        else { return Self() }
        session.refresh(at: date)
        return session
    }
}

public enum DurationText {
    /// Keep a blank while editing, reject non-integers, and remove redundant zeroes.
    public static func normalizedComponent(_ text: String) -> String? {
        guard !text.isEmpty else { return "" }
        guard text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text) else { return nil }
        return String(value)
    }

    public static func steppedComponent(_ text: String, by delta: Int, maximum: Int) -> String {
        let value = min(maximum, max(0, Int(text) ?? 0))
        let step = min(1, max(-1, delta))
        return String(min(maximum, max(0, value + step)))
    }

    public static func clock(_ seconds: TimeInterval) -> String {
        let safe = seconds.isFinite ? min(TimerSession.maximumDuration, max(0, seconds)) : 0
        let whole = Int(ceil(safe))
        if whole >= 3600 {
            return String(format: "%d:%02d:%02d", whole / 3600, (whole % 3600) / 60, whole % 60)
        }
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    public static func label(_ seconds: TimeInterval) -> String {
        let whole = Int(min(TimerSession.maximumDuration, max(0, seconds.isFinite ? seconds : 0)))
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let seconds = whole % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }

    public static func custom(hours: String, minutes: String, seconds: String) -> TimeInterval? {
        func component(_ value: String, maximum: Int) -> Int? {
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { return 0 }
            guard value.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let result = Int(value), (0...maximum).contains(result) else { return nil }
            return result
        }
        guard let h = component(hours, maximum: 24),
              let m = component(minutes, maximum: 59),
              let s = component(seconds, maximum: 59) else { return nil }
        let duration = TimeInterval(h * 3600 + m * 60 + s)
        return (1...TimerSession.maximumDuration).contains(duration) ? duration : nil
    }
}
