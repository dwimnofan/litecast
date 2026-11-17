import Foundation

/// Evaluates arithmetic queries and pins the answer above other results.
@MainActor
final class CalculatorProvider: SearchProvider {
    func results(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = ExpressionParser.evaluate(trimmed) else { return [] }
        let answer = ExpressionParser.format(value)
        return [
            SearchResult(
                id: "calculator.\(trimmed)",
                title: answer,
                subtitle: trimmed,
                accessory: "Calculator",
                icon: .symbol("equal.square"),
                action: .copyText(answer),
                score: 2000
            ),
        ]
    }
}
