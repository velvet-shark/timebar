import CoreGraphics
import Foundation
import Testing
@testable import TimebarCore

@Test func aHalfPointLineUsesOnePhysicalPixelOnRetina() {
    let frame = BarGeometry.frame(
        screen: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        menuBarInset: 24, safeAreaTop: 0, thickness: 0.5,
        placement: .belowMenuBar, scale: 2
    )
    #expect(frame == CGRect(x: 0, y: 1055.5, width: 1920, height: 0.5))
    #expect(frame.height * 2 == 1)
    #expect(frame.maxY == 1056)
}

@Test func aHalfPointLineStaysVisibleOnStandardResolutionDisplays() {
    let frame = BarGeometry.frame(
        screen: CGRect(x: -1920, y: -100, width: 1920, height: 1080),
        menuBarInset: 24, safeAreaTop: 0, thickness: 0.5,
        placement: .belowMenuBar, scale: 1
    )
    #expect(frame == CGRect(x: -1920, y: 955, width: 1920, height: 1))
}

@Test func halfPointSettingsSurviveRelaunch() throws {
    var settings = AppearanceSettings()
    settings.thickness = 0.5
    settings.color = .amber
    settings.opacity = 0.75
    let restored = AppearanceSettings.restored(from: try JSONEncoder().encode(settings))
    #expect(restored == settings)
}
