import Foundation

/// Per-million-token pricing for the model families this widget understands.
/// Numbers are USD and approximate as of early 2026 — adjust freely.
enum Pricing {
    struct Price {
        let input: Double
        let output: Double
        let cacheRead: Double
        let cacheWrite: Double
    }

    /// Patterns are matched as case-insensitive `contains` against the model id,
    /// in order — put more specific patterns first.
    static let table: [(pattern: String, price: Price)] = [
        // Anthropic
        ("opus-4-7",   Price(input: 15.0, output: 75.0, cacheRead: 1.50, cacheWrite: 18.75)),
        ("opus-4-6",   Price(input: 15.0, output: 75.0, cacheRead: 1.50, cacheWrite: 18.75)),
        ("opus-4",     Price(input: 15.0, output: 75.0, cacheRead: 1.50, cacheWrite: 18.75)),
        ("opus",       Price(input: 15.0, output: 75.0, cacheRead: 1.50, cacheWrite: 18.75)),
        ("sonnet-4-6", Price(input:  3.0, output: 15.0, cacheRead: 0.30, cacheWrite:  3.75)),
        ("sonnet-4-5", Price(input:  3.0, output: 15.0, cacheRead: 0.30, cacheWrite:  3.75)),
        ("sonnet-4",   Price(input:  3.0, output: 15.0, cacheRead: 0.30, cacheWrite:  3.75)),
        ("sonnet",     Price(input:  3.0, output: 15.0, cacheRead: 0.30, cacheWrite:  3.75)),
        ("haiku-4-5",  Price(input:  0.80, output: 4.0, cacheRead: 0.08, cacheWrite:  1.0)),
        ("haiku",      Price(input:  0.80, output: 4.0, cacheRead: 0.08, cacheWrite:  1.0)),
        // OpenAI / Codex (best-effort approximations)
        ("gpt-5.3-codex", Price(input: 1.25, output: 10.0, cacheRead: 0.125, cacheWrite: 1.25)),
        ("gpt-5-codex",   Price(input: 1.25, output: 10.0, cacheRead: 0.125, cacheWrite: 1.25)),
        ("gpt-5-pro",     Price(input: 10.0, output: 60.0, cacheRead: 1.0,   cacheWrite: 10.0)),
        ("gpt-5-mini",    Price(input:  0.25, output: 2.0, cacheRead: 0.025, cacheWrite: 0.25)),
        ("gpt-5",         Price(input: 1.25, output: 10.0, cacheRead: 0.125, cacheWrite: 1.25)),
        ("o4",            Price(input: 3.0,  output: 12.0, cacheRead: 0.30,  cacheWrite: 3.0)),
        ("o3",            Price(input: 2.0,  output: 8.0,  cacheRead: 0.20,  cacheWrite: 2.0)),
    ]

    static func price(for model: String) -> Price? {
        let lower = model.lowercased()
        for entry in table where lower.contains(entry.pattern) {
            return entry.price
        }
        return nil
    }

    static func cost(model: String,
                     input: Int,
                     output: Int,
                     cacheRead: Int,
                     cacheWrite: Int) -> Double {
        guard let p = price(for: model) else { return 0 }
        return (Double(input)      * p.input
              + Double(output)     * p.output
              + Double(cacheRead)  * p.cacheRead
              + Double(cacheWrite) * p.cacheWrite) / 1_000_000.0
    }
}
