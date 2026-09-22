import Testing
@testable import TimebarCore

@Test func editingRemovesLeadingZeroesWithoutLosingMeaningfulZeroes() {
    #expect(DurationText.normalizedComponent("01") == "1")
    #expect(DurationText.normalizedComponent("005") == "5")
    #expect(DurationText.normalizedComponent("000") == "0")
    #expect(DurationText.normalizedComponent("10") == "10")
    #expect(DurationText.normalizedComponent("50") == "50")
    #expect(DurationText.normalizedComponent("") == "")
}

@Test func editingRejectsNonIntegerInputInsteadOfChangingItsMeaning() {
    #expect(DurationText.normalizedComponent("1.5") == nil)
    #expect(DurationText.normalizedComponent("-1") == nil)
    #expect(DurationText.normalizedComponent("abc") == nil)
    #expect(DurationText.normalizedComponent("9999999999999999999999999999") == nil)
    #expect(DurationText.normalizedComponent("60") == "60")
    #expect(DurationText.custom(hours: "0", minutes: "60", seconds: "0") == nil)
}

@Test func componentArrowsAdjustAndStayWithinTheirLimits() {
    #expect(DurationText.steppedComponent("0", by: 1, maximum: 24) == "1")
    #expect(DurationText.steppedComponent("24", by: 1, maximum: 24) == "24")
    #expect(DurationText.steppedComponent("0", by: -1, maximum: 59) == "0")
    #expect(DurationText.steppedComponent("58", by: 1, maximum: 59) == "59")
    #expect(DurationText.steppedComponent("59", by: 1, maximum: 59) == "59")
    #expect(DurationText.steppedComponent("45", by: -1, maximum: 59) == "44")
    #expect(DurationText.steppedComponent("", by: 1, maximum: 59) == "1")
}
