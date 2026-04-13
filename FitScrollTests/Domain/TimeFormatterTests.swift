import XCTest
@testable import FitScroll

final class TimeFormatterTests: XCTestCase {

    func testFormatDurationMinutesAndSeconds() {
        XCTAssertEqual(TimeFormatter.formatDuration(seconds: 65), "01:05")
        XCTAssertEqual(TimeFormatter.formatDuration(seconds: 0), "00:00")
        XCTAssertEqual(TimeFormatter.formatDuration(seconds: 3600), "60:00")
    }

    func testFormatMinutesUnderOne() {
        let result = TimeFormatter.formatMinutes(0.5)
        XCTAssertEqual(result, "30 sec")
    }

    func testFormatMinutesWholeNumber() {
        let result = TimeFormatter.formatMinutes(5.0)
        XCTAssertEqual(result, "5 min")
    }

    func testFormatMinutesFractional() {
        let result = TimeFormatter.formatMinutes(5.5)
        XCTAssertEqual(result, "5.5 min")
    }
}
