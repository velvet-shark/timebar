import Foundation

public struct BarColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let blue = Self(red: 0.32, green: 0.64, blue: 0.98)
    public static let mint = Self(red: 0.31, green: 0.78, blue: 0.65)
    public static let amber = Self(red: 0.97, green: 0.69, blue: 0.32)
    public static let rose = Self(red: 0.94, green: 0.47, blue: 0.57)
    public static let lavender = Self(red: 0.69, green: 0.57, blue: 0.93)
    public static let white = Self(red: 0.94, green: 0.95, blue: 0.98)

    var isValid: Bool {
        [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public static let thicknessRange: ClosedRange<Double> = 0.5...8

    public enum Displays: String, Codable, CaseIterable, Sendable {
        case all = "All displays"
        case primary = "Primary display"
    }

    public enum Placement: String, Codable, CaseIterable, Sendable {
        case belowMenuBar = "Below menu bar"
        case top = "Top edge"
        case bottom = "Bottom edge"
    }

    public enum Preset: String, CaseIterable, Sendable {
        case subtle = "Subtle"
        case focus = "Focus"
        case warm = "Warm"
    }

    public var color: BarColor = .blue
    public var thickness: Double = 1
    public var opacity: Double = 0.65
    public var showTrack = false
    public var displays: Displays = .all
    public var placement: Placement = .belowMenuBar
    public var showMenuCountdown = false
    public var playCompletionSound = true

    public init() {}

    public mutating func apply(_ preset: Preset) {
        switch preset {
        case .subtle: color = .blue; thickness = 1; opacity = 0.65
        case .focus: color = .mint; thickness = 3; opacity = 0.85
        case .warm: color = .amber; thickness = 2; opacity = 0.75
        }
        showTrack = false
    }

    public static func restored(from data: Data?) -> Self {
        guard let data, let settings = try? JSONDecoder().decode(Self.self, from: data),
              settings.color.isValid, settings.thickness.isFinite, thicknessRange.contains(settings.thickness),
              settings.opacity.isFinite, (0.1...1).contains(settings.opacity) else { return Self() }
        return settings
    }
}
