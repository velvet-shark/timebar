import Foundation
import CoreGraphics
import Testing
@testable import TimebarCore

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

@Test func aTimerShrinksFromTheRightToZero() {
    var timer = TimerSession()
    let started = timer.start(seconds: 1500, at: epoch)
    #expect(started)
    #expect(timer.fractionRemaining(at: epoch) == 1)
    #expect(timer.remaining(at: epoch.addingTimeInterval(375)) == 1125)
    #expect(timer.fractionRemaining(at: epoch.addingTimeInterval(375)) == 0.75)
    #expect(timer.fractionRemaining(at: epoch.addingTimeInterval(1500)) == 0)
}

@Test func aLongSleepFinishesOnceInsteadOfDrifting() {
    var timer = TimerSession()
    timer.start(seconds: 1500, at: epoch)
    let finished = timer.refresh(at: epoch.addingTimeInterval(4000))
    #expect(finished)
    #expect(timer.phase == .finished)
    #expect(timer.remaining(at: epoch.addingTimeInterval(4001)) == 0)
    let finishedAgain = timer.refresh(at: epoch.addingTimeInterval(4002))
    #expect(!finishedAgain)
}

@Test func pauseAndResumePreserveTheRemainingDuration() {
    var timer = TimerSession()
    timer.start(seconds: 60, at: epoch)
    timer.pause(at: epoch.addingTimeInterval(15.25))
    #expect(timer.phase == .paused)
    #expect(timer.remaining(at: epoch.addingTimeInterval(1000)) == 44.75)
    timer.resume(at: epoch.addingTimeInterval(1000))
    #expect(timer.remaining(at: epoch.addingTimeInterval(1005)) == 39.75)
    #expect(timer.duration == 60)
}

@Test func pauseAtTheDeadlineCannotResurrectATimer() {
    var timer = TimerSession()
    timer.start(seconds: 60, at: epoch)
    timer.pause(at: epoch.addingTimeInterval(60))
    timer.resume(at: epoch.addingTimeInterval(100))
    #expect(timer.phase == .finished)
}

@Test func stopClearsTheLineAndRestartUsesTheLastDuration() {
    var timer = TimerSession()
    timer.start(seconds: 3600, at: epoch)
    timer.stop()
    #expect(timer.phase == .idle)
    #expect(!timer.isActive)
    #expect(timer.remaining(at: epoch) == 0)
    timer.restart(at: epoch.addingTimeInterval(100))
    #expect(timer.phase == .running)
    #expect(timer.remaining(at: epoch.addingTimeInterval(100)) == 3600)
}

@Test func selectingAPresetReplacesThePreviousTimer() {
    var timer = TimerSession()
    timer.start(seconds: 3600, at: epoch)
    timer.pause(at: epoch.addingTimeInterval(100))
    timer.start(seconds: 300, at: epoch.addingTimeInterval(200))
    #expect(timer.phase == .running)
    #expect(timer.duration == 300)
    #expect(timer.remaining(at: epoch.addingTimeInterval(200)) == 300)
}

@Test(arguments: [0.0, -1, Double.nan, Double.infinity, 86_401])
func invalidDurationsLeaveAnExistingTimerUntouched(seconds: Double) {
    var timer = TimerSession()
    timer.start(seconds: 60, at: epoch)
    let original = timer
    let started = timer.start(seconds: seconds, at: epoch)
    #expect(!started)
    #expect(timer == original)
}

@Test func aRunningTimerSurvivesRelaunch() throws {
    var timer = TimerSession()
    timer.start(seconds: 1500, at: epoch)
    let data = try JSONEncoder().encode(timer)
    let restored = TimerSession.restored(from: data, at: epoch.addingTimeInterval(300))
    #expect(restored.phase == .running)
    #expect(restored.remaining(at: epoch.addingTimeInterval(300)) == 1200)
    let expired = TimerSession.restored(from: data, at: epoch.addingTimeInterval(1501))
    #expect(expired.phase == .finished)
}

@Test func aPausedTimerSurvivesRelaunch() throws {
    var timer = TimerSession()
    timer.start(seconds: 1500, at: epoch)
    timer.pause(at: epoch.addingTimeInterval(300))
    let data = try JSONEncoder().encode(timer)
    var restored = TimerSession.restored(from: data, at: epoch.addingTimeInterval(9000))
    #expect(restored.phase == .paused)
    #expect(restored.remaining(at: epoch.addingTimeInterval(9000)) == 1200)
    restored.resume(at: epoch.addingTimeInterval(9000))
    #expect(restored.remaining(at: epoch.addingTimeInterval(9100)) == 1100)
}

@Test func corruptSavedDataFallsBackToAnIdleTimer() {
    #expect(TimerSession.restored(from: Data("broken".utf8), at: epoch).phase == .idle)
    let noDeadline = Data(#"{"phase":"running","duration":60,"pausedRemaining":0}"#.utf8)
    #expect(TimerSession.restored(from: noDeadline, at: epoch).phase == .idle)
    let negativePause = Data(#"{"phase":"paused","duration":60,"pausedRemaining":-1}"#.utf8)
    #expect(TimerSession.restored(from: negativePause, at: epoch).phase == .idle)
}

@Test func clockChangesCannotOverflowTheLine() {
    var timer = TimerSession()
    timer.start(seconds: 60, at: epoch)
    #expect(timer.fractionRemaining(at: epoch.addingTimeInterval(-100)) == 1)
    #expect(timer.fractionRemaining(at: epoch.addingTimeInterval(100)) == 0)
}

@Test func countdownRoundsUpUntilTheActualDeadline() {
    #expect(DurationText.clock(0.01) == "00:01")
    #expect(DurationText.clock(59.1) == "01:00")
    #expect(DurationText.clock(3600) == "1:00:00")
    #expect(DurationText.clock(86_400) == "24:00:00")
    #expect(DurationText.clock(-5) == "00:00")
    #expect(DurationText.clock(.nan) == "00:00")
}

@Test func customDurationsValidateWholeComponentsAndBounds() {
    #expect(DurationText.custom(hours: "1", minutes: "30", seconds: "5") == 5405)
    #expect(DurationText.custom(hours: "", minutes: "", seconds: "1") == 1)
    #expect(DurationText.custom(hours: "24", minutes: "0", seconds: "0") == 86_400)
    #expect(DurationText.custom(hours: "24", minutes: "0", seconds: "1") == nil)
    #expect(DurationText.custom(hours: "0", minutes: "60", seconds: "0") == nil)
    #expect(DurationText.custom(hours: "0", minutes: "0", seconds: "0") == nil)
    #expect(DurationText.custom(hours: "0", minutes: "1.5", seconds: "0") == nil)
    #expect(DurationText.custom(hours: "-1", minutes: "25", seconds: "0") == nil)
    #expect(DurationText.custom(hours: "0", minutes: "abc", seconds: "0") == nil)
    #expect(DurationText.custom(hours: " 1 ", minutes: "5", seconds: "0") == 3900)
}

@Test func appearanceRoundTripsWithoutChangingDisplayChoices() throws {
    var settings = AppearanceSettings()
    settings.displays = .primary
    settings.placement = .bottom
    settings.apply(.warm)
    #expect(settings.displays == .primary)
    #expect(settings.placement == .bottom)
    let restored = AppearanceSettings.restored(from: try JSONEncoder().encode(settings))
    #expect(restored == settings)
}

@Test func corruptAppearanceCannotHideTheLine() throws {
    var settings = AppearanceSettings()
    settings.opacity = 0
    settings.thickness = -3
    #expect(AppearanceSettings.restored(from: try JSONEncoder().encode(settings)) == AppearanceSettings())
}

@Test func lineSitsBelowTheMenuAndNotchOnEachDisplay() {
    let normal = BarGeometry.frame(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), menuBarInset: 24, safeAreaTop: 0, thickness: 2, placement: .belowMenuBar, scale: 2)
    #expect(normal == CGRect(x: 0, y: 1054, width: 1920, height: 2))
    let notched = BarGeometry.frame(screen: CGRect(x: -1512, y: -100, width: 1512, height: 982), menuBarInset: 24, safeAreaTop: 38, thickness: 1, placement: .belowMenuBar, scale: 2)
    #expect(notched == CGRect(x: -1512, y: 843, width: 1512, height: 1))
}

@Test func edgePositionsRespectDisplayOriginAndNotch() {
    let screen = CGRect(x: 1920, y: 300, width: 1512, height: 982)
    let top = BarGeometry.frame(screen: screen, menuBarInset: 24, safeAreaTop: 38, thickness: 3, placement: .top, scale: 2)
    #expect(top == CGRect(x: 1920, y: 1241, width: 1512, height: 3))
    let bottom = BarGeometry.frame(screen: screen, menuBarInset: 24, safeAreaTop: 38, thickness: 3, placement: .bottom, scale: 2)
    #expect(bottom == CGRect(x: 1920, y: 300, width: 1512, height: 3))
}
