import XCTest
@testable import LiteCast

final class CalculatorTests: XCTestCase {
    private func eval(_ input: String) -> Double? {
        ExpressionParser.evaluate(input)
    }

    // MARK: Precedence & grouping

    func testAdditionAndMultiplicationPrecedence() {
        XCTAssertEqual(eval("2 + 3 * 4"), 14)
        XCTAssertEqual(eval("2 * 3 + 4"), 10)
    }

    func testParentheses() {
        XCTAssertEqual(eval("(2 + 3) * 4"), 20)
        XCTAssertEqual(eval("2 * (3 + 4)"), 14)
        XCTAssertEqual(eval("((1 + 2))"), 3)
    }

    func testUnaryMinus() {
        XCTAssertEqual(eval("-5"), -5)
        XCTAssertEqual(eval("3 * -2"), -6)
        XCTAssertEqual(eval("--4"), 4)
        XCTAssertEqual(eval("-(2 + 3)"), -5)
    }

    func testPowerRightAssociative() {
        XCTAssertEqual(eval("2 ^ 3"), 8)
        XCTAssertEqual(eval("2 ^ 3 ^ 2"), 512) // 2^(3^2), not (2^3)^2
        XCTAssertEqual(eval("4 ^ 0.5"), 2)
    }

    /// `%` is postfix ÷100: `50%` → 0.5. Not “percent of left operand”.
    func testPercentSemantics() {
        XCTAssertEqual(eval("50%"), 0.5)
        XCTAssertEqual(eval("200 * 50%"), 100)
        XCTAssertEqual(eval("100 + 50%"), 100.5)
    }

    func testDecimalsAndCommaSeparator() {
        XCTAssertEqual(eval("1.5 + 2.5"), 4)
        XCTAssertEqual(eval("1,5 + 2,5"), 4)
    }

    func testFormatDropsTrailingZero() {
        XCTAssertEqual(ExpressionParser.format(4.0), "4")
        XCTAssertEqual(ExpressionParser.format(1.5), "1.5")
    }

    // MARK: Invalid / edge cases → nil

    func testBareNumberReturnsNil() {
        XCTAssertNil(eval("12"))
        XCTAssertNil(eval("3.14"))
        XCTAssertNil(eval("(12)"))
    }

    func testNonExpressionReturnsNil() {
        XCTAssertNil(eval("safari"))
        XCTAssertNil(eval("1 +"))
        XCTAssertNil(eval("* 2"))
        XCTAssertNil(eval("1 + + 2"))
        XCTAssertNil(eval(""))
        XCTAssertNil(eval("   "))
    }

    func testDivisionByZeroReturnsNil() {
        XCTAssertNil(eval("1 / 0"))
        XCTAssertNil(eval("0 / 0"))
    }

    func testOverflowReturnsNil() {
        XCTAssertNil(eval("2 ^ 2000"))
    }

    // MARK: Provider

    @MainActor
    func testProviderPinsValidExpression() {
        let provider = CalculatorProvider()
        let results = provider.results(for: "2 + 2")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "4")
        XCTAssertEqual(results[0].subtitle, "2 + 2")
        XCTAssertEqual(results[0].accessory, "Calculator")
        XCTAssertEqual(results[0].score, 2000)
        XCTAssertEqual(results[0].action, .copyText("4"))
        XCTAssertEqual(results[0].icon, .symbol("equal.square"))
    }

    @MainActor
    func testProviderIgnoresBareNumberAndText() {
        let provider = CalculatorProvider()
        XCTAssertTrue(provider.results(for: "12").isEmpty)
        XCTAssertTrue(provider.results(for: "safari").isEmpty)
        XCTAssertTrue(provider.results(for: "1 / 0").isEmpty)
    }
}
