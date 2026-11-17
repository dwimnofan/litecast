import Foundation

/// Recursive-descent calculator over `Double`.
///
/// Grammar (highest precedence last):
/// ```
/// expression = term (("+" | "-") term)*
/// term       = power (("*" | "/") power)*
/// power      = unary ("^" unary)*          // right-associative
/// unary      = "-" unary | postfix
/// postfix    = primary "%"?                // % ⇒ value / 100
/// primary    = number | "(" expression ")"
/// ```
///
/// Percent is a postfix operator: `50%` → `0.5`, `200 * 50%` → `100`.
/// It does **not** mean “percent of the left operand” in `a + b%`.
enum ExpressionParser {
    /// Parses `input` and returns the value, or `nil` when the input is not a
    /// complete expression that contains at least one operator, or when the
    /// result is non-finite (division by zero, overflow).
    static func evaluate(_ input: String) -> Double? {
        var parser = Parser(input)
        guard let value = parser.parseExpression(), parser.sawOperator, parser.atEnd else { return nil }
        guard value.isFinite else { return nil }
        return value
    }

    /// Formats a calculator answer: no trailing `.0`, up to 10 fraction digits.
    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Parser

private struct Parser {
    private let chars: [Character]
    private var index = 0
    private(set) var sawOperator = false

    init(_ input: String) {
        chars = Array(input.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var atEnd: Bool { index >= chars.count }

    mutating func parseExpression() -> Double? {
        skipWhitespace()
        guard var left = parseTerm() else { return nil }
        while true {
            skipWhitespace()
            if match("+") {
                sawOperator = true
                guard let right = parseTerm() else { return nil }
                left += right
            } else if match("-") {
                sawOperator = true
                guard let right = parseTerm() else { return nil }
                left -= right
            } else {
                return left
            }
        }
    }

    private mutating func parseTerm() -> Double? {
        skipWhitespace()
        guard var left = parsePower() else { return nil }
        while true {
            skipWhitespace()
            if match("*") {
                sawOperator = true
                guard let right = parsePower() else { return nil }
                left *= right
            } else if match("/") {
                sawOperator = true
                guard let right = parsePower() else { return nil }
                left /= right
            } else {
                return left
            }
        }
    }

    /// Right-associative exponentiation.
    private mutating func parsePower() -> Double? {
        skipWhitespace()
        guard let base = parseUnary() else { return nil }
        skipWhitespace()
        if match("^") {
            sawOperator = true
            guard let exp = parsePower() else { return nil }
            return pow(base, exp)
        }
        return base
    }

    private mutating func parseUnary() -> Double? {
        skipWhitespace()
        if match("-") {
            sawOperator = true
            guard let value = parseUnary() else { return nil }
            return -value
        }
        return parsePostfix()
    }

    private mutating func parsePostfix() -> Double? {
        skipWhitespace()
        guard var value = parsePrimary() else { return nil }
        skipWhitespace()
        if match("%") {
            sawOperator = true
            value /= 100
        }
        return value
    }

    private mutating func parsePrimary() -> Double? {
        skipWhitespace()
        if match("(") {
            guard let value = parseExpression() else { return nil }
            skipWhitespace()
            guard match(")") else { return nil }
            return value
        }
        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        skipWhitespace()
        let start = index
        var sawDigit = false
        var sawDot = false

        while let c = peek() {
            if c.isASCIIDigit {
                sawDigit = true
                advance()
            } else if c == "." || c == "," {
                if sawDot { break }
                sawDot = true
                advance()
            } else {
                break
            }
        }

        guard sawDigit, index > start else { return nil }
        var raw = String(chars[start..<index])
        raw = raw.replacingOccurrences(of: ",", with: ".")
        // Trailing decimal separator alone is invalid ("12.").
        if raw.hasSuffix(".") { return nil }
        return Double(raw)
    }

    // MARK: Helpers

    private mutating func skipWhitespace() {
        while let c = peek(), c.isWhitespace { advance() }
    }

    private func peek() -> Character? {
        index < chars.count ? chars[index] : nil
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func match(_ expected: Character) -> Bool {
        guard peek() == expected else { return false }
        advance()
        return true
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
