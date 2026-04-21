import XCTest
@testable import CatBar

final class ValueFormatterTests: XCTestCase {
    func testSpeedCompactNoSpaceRemovesGapBetweenValueAndUnit() {
        XCTAssertEqual(ValueFormatter.speedCompactNoSpace(0), "0KB/s")
        XCTAssertEqual(ValueFormatter.speedCompactNoSpace(1024), "1KB/s")
        XCTAssertEqual(ValueFormatter.speedCompactNoSpace(7_120_855), "6.79MB/s")
    }
}
