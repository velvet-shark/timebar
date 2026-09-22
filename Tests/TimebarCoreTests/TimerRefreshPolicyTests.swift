import Foundation
import Testing
@testable import TimebarCore

private let start = Date(timeIntervalSince1970: 1_800_000_000)

private func delay(_ session: TimerSession, elapsed: Double = 0, pixels: Double = 3840,
                   seconds: Bool = false, awake: Bool = true) -> Double? {
    TimerRefreshPolicy.delay(for: session, at: start.addingTimeInterval(elapsed),
                             pixelWidth: pixels, showsSeconds: seconds, displayAwake: awake)
}

@Test func inactiveTimersNeverSchedulePolling() {
    var session = TimerSession()
    #expect(delay(session) == nil)
    session.start(seconds: 60, at: start)
    session.pause(at: start.addingTimeInterval(10))
    #expect(delay(session) == nil)
    session.resume(at: start)
    session.refresh(at: start.addingTimeInterval(60))
    #expect(delay(session) == nil)
}

@Test func longTimersWaitUntilTheLineCanMoveOnePixel() {
    var session = TimerSession()
    session.start(seconds: 86_400, at: start)
    #expect(delay(session) == 22.5)
    #expect(delay(session, pixels: 7680) == 11.25)
    #expect(delay(session, pixels: 0) == 60)
    #expect(delay(session, pixels: .nan) == 60)
}

@Test func visibleSecondsStillRefreshAtLeastEverySecond() {
    var session = TimerSession()
    session.start(seconds: 86_400, at: start)
    #expect(delay(session, seconds: true) == 1)
}

@Test func shortTimersBoundVisualUpdatesButFinishOnTime() {
    var session = TimerSession()
    session.start(seconds: 1, at: start)
    #expect(delay(session) == 0.25)
    #expect(abs((delay(session, elapsed: 0.9) ?? 0) - 0.1) < 0.0001)
    #expect(delay(session, elapsed: 2) == 0)
}

@Test func sleepingDisplaysKeepOnlyTheDeadlineCallback() {
    var session = TimerSession()
    session.start(seconds: 1500, at: start)
    #expect(delay(session, elapsed: 100, seconds: true, awake: false) == 1400)
    #expect(delay(session, elapsed: 1600, awake: false) == 0)
}
