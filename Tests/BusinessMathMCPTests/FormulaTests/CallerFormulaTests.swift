import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// `CallerFormula` is what stands between a formula argument and `ExpressionEvaluator`: it
/// passes values as values, checks the formula once, and makes a failure in the middle of a run
/// fail the run.
@Suite("CallerFormula")
struct CallerFormulaTests {

    // MARK: - Values are passed, not pasted

    @Test("^ is power and / is floating-point")
    func operators() throws {
        let power = try CallerFormula("{0} ^ 2", argument: "formula", inputCount: 1)
        #expect(try power.value(at: [3]).isEqual(to: 9))

        let division = try CallerFormula("{0} / 4", argument: "formula", inputCount: 1)
        #expect(try division.value(at: [10]).isEqual(to: 2.5))
    }

    @Test("A negative value keeps the formula's meaning")
    func negativeValueIsNotPasted() throws {
        // Pasted as text, "-3.0 ^ 2" is -(3 ^ 2) = -9. Passed as a value, (-3) ^ 2 = 9.
        let formula = try CallerFormula("{0} ^ 2", argument: "formula", inputCount: 1)
        #expect(try formula.value(at: [-3]).isEqual(to: 9))
    }

    @Test("x is a variable, and exp and max are still functions")
    func xBesideFunctionsThatContainX() throws {
        let formula = try CallerFormula("exp(x) + max(x, 1)", argument: "formula", names: ["x"])
        #expect(try formula.value(at: [0]).isEqual(to: 2))
        #expect(try formula.value(at: [3]).isEqual(to: Foundation.exp(3.0) + 3))
    }

    @Test("An input is reachable by name and by position at once")
    func nameAndPosition() throws {
        let formula = try CallerFormula(
            "revenue - {1} + costs * 0", argument: "model", names: ["revenue", "costs"])
        #expect(try formula.value(at: [100, 40]).isEqual(to: 60))
    }

    @Test("A name that is a substring of another is its own variable")
    func namesAreNotSubstrings() throws {
        // Replaced as text, "rate" inside "rate_cap" was rewritten too.
        let formula = try CallerFormula(
            "rate_cap - rate", argument: "model", names: ["rate", "rate_cap"])
        #expect(try formula.value(at: [0.25, 1]).isEqual(to: 0.75))
    }

    @Test("A name that is not an identifier is not bound, and its input is still {n}")
    func nonIdentifierNameIsPositionalOnly() throws {
        let formula = try CallerFormula(
            "{0} * 2", argument: "calculation", names: ["Sales Volume"])
        #expect(formula.names == [nil])
        #expect(try formula.value(at: [21]).isEqual(to: 42))
    }

    @Test("Of two inputs with one name, the first has it")
    func duplicateNames() throws {
        let formula = try CallerFormula("a + {1}", argument: "calculation", names: ["a", "a"])
        #expect(formula.names == ["a", nil])
        #expect(try formula.value(at: [1, 10]).isEqual(to: 11))
    }

    @Test("pi and e are constants")
    func constants() throws {
        let formula = try CallerFormula("pi + e", argument: "formula")
        #expect(try formula.value(at: []).isEqual(to: Double.pi + Foundation.exp(1.0)))
    }

    // MARK: - Checked once, up front

    @Test("A formula outside the grammar is refused before anything runs")
    func invalidFormulaIsRefusedAtInit() {
        #expect(throws: FormulaFailure.invalid(
            argument: "formula", reason: .unexpectedToken("*", offset: 3))
        ) {
            _ = try CallerFormula("x +* 2", argument: "formula", names: ["x"])
        }
    }

    @Test("Every way a formula can be wrong in itself is refused at init",
          arguments: [
            ("", ExpressionError.empty),
            ("2 +", .unexpectedEnd),
            ("2 ** 3", .unexpectedToken("*", offset: 3)),
            ("5 & 3", .unexpectedCharacter("&", offset: 2)),
            ("sum(1, 2)", .unknownFunction("sum")),
            ("random()", .unknownFunction("random")),
            ("revenue - costs", .unknownVariable("revenue")),
            ("{0} + {2}", .placeholderOutOfRange(index: 2, count: 1)),
            ("pow(2)", .wrongArgumentCount(function: "pow", expected: "2", actual: 1)),
          ])
    func invalidFormulas(text: String, reason: ExpressionError) {
        #expect(throws: FormulaFailure.invalid(argument: "calculation", reason: reason)) {
            _ = try CallerFormula(text, argument: "calculation", inputCount: 1)
        }
    }

    @Test("A division by zero at the arbitrary check point is not the caller's error yet")
    func undefinedAtProbeIsNotRefused() throws {
        // The check evaluates at {0} = 1.5; this formula divides by zero exactly there and
        // nowhere else, which says nothing about the values the caller will run it with.
        let formula = try CallerFormula("1 / ({0} - 1.5)", argument: "formula", inputCount: 1)
        #expect(try formula.value(at: [2]).isEqual(to: 2))
    }

    // MARK: - A failure at a value

    @Test("A division by zero names the inputs it happened at")
    func undefinedNamesTheInputs() throws {
        let formula = try CallerFormula(
            "1 / (revenue - {1})", argument: "calculation", names: ["revenue", "Total Costs"])
        #expect(throws: FormulaFailure.undefined(
            argument: "calculation",
            reason: .divisionByZero,
            inputs: [
                FormulaInput(label: "revenue", value: 100),
                FormulaInput(label: "{1}", value: 100),
            ])
        ) {
            _ = try formula.value(at: [100, 100])
        }
    }

    @Test("A result that is not finite is an error, not a result")
    func notFinite() throws {
        let formula = try CallerFormula("exp(x)", argument: "formula", names: ["x"])
        #expect(throws: FormulaFailure.undefined(
            argument: "formula", reason: .notFinite,
            inputs: [FormulaInput(label: "x", value: 1000)])
        ) {
            _ = try formula.value(at: [1000])
        }
    }

    // MARK: - Inside a callback that cannot throw

    @Test("recordedValue returns nan, never zero, and keeps the first failure")
    func recordedValueKeepsFirstFailure() throws {
        let formula = try CallerFormula("1 / x", argument: "formula", names: ["x"])

        #expect(formula.recordedValue(at: [4]).isEqual(to: 0.25))
        #expect(throws: Never.self) { try formula.throwIfFailed() }

        #expect(formula.recordedValue(at: [0]).isNaN)
        // A later failure does not replace the first.
        #expect(formula.recordedValue(at: [.infinity]).isNaN)

        #expect(throws: FormulaFailure.undefined(
            argument: "formula", reason: .divisionByZero,
            inputs: [FormulaInput(label: "x", value: 0)])
        ) {
            try formula.throwIfFailed()
        }
    }

    @Test("A copy captured by a closure records into the same run")
    func copiesShareTheRecord() throws {
        let formula = try CallerFormula("1 / {0}", argument: "calculation", inputCount: 1)
        let model: @Sendable ([Double]) -> Double = { formula.recordedValue(at: $0) }

        #expect(model([0]).isNaN)
        #expect(throws: FormulaFailure.undefined(
            argument: "calculation", reason: .divisionByZero,
            inputs: [FormulaInput(label: "{0}", value: 0)])
        ) {
            try formula.throwIfFailed()
        }
    }

    // MARK: - What the caller reads

    @Test("An invalid formula's message says which argument and what is wrong with it")
    func invalidMessage() {
        let failure = FormulaFailure.invalid(
            argument: "formula", reason: .unexpectedToken("*", offset: 3))
        #expect(failure.callerMessage
            == "Invalid arguments: formula is not a valid formula. Unexpected '*' at position 3.")
    }

    @Test("An unknown name's message names it")
    func unknownVariableMessage() {
        let failure = FormulaFailure.invalid(argument: "model", reason: .unknownVariable("margin"))
        #expect(failure.callerMessage
            == "Invalid arguments: model is not a valid formula. 'margin' has no value. It is not a supplied variable or a constant.")
    }

    @Test("An undefined value's message gives the point")
    func undefinedMessage() {
        let failure = FormulaFailure.undefined(
            argument: "calculation", reason: .divisionByZero,
            inputs: [
                FormulaInput(label: "revenue", value: 100),
                FormulaInput(label: "{1}", value: 2.5),
            ])
        #expect(failure.callerMessage
            == "Invalid arguments: calculation has no value at revenue = 100.0, {1} = 2.5. The formula divides by zero.")
    }

    @Test("An undefined value with no inputs says so without a point")
    func undefinedMessageWithoutInputs() {
        let failure = FormulaFailure.undefined(
            argument: "formula", reason: .notFinite, inputs: [])
        #expect(failure.callerMessage
            == "Invalid arguments: formula has no value. The formula does not evaluate to a finite number.")
    }

    // MARK: - Names

    @Test("Identifiers are a letter or underscore, then letters, digits and underscores",
          arguments: [
            ("x", true), ("_x", true), ("rate_2", true), ("Revenue", true),
            ("", false), ("2x", false), ("Sales Volume", false), ("a-b", false),
            ("café", false), ("x{0}", false),
          ])
    func identifiers(name: String, expected: Bool) {
        #expect(CallerFormula.isIdentifier(name) == expected)
    }

    @Test("inputs[n] becomes {n} without moving anything else")
    func indexedInputs() {
        #expect(CallerFormula.replacingIndexedInputs(in: "inputs[0] * (1 + inputs[12])")
            == "      {0} * (1 +       {12})")
        // Only the whole word, so a variable that merely ends in "inputs" is left alone.
        #expect(CallerFormula.replacingIndexedInputs(in: "my_inputs[0]") == "my_inputs[0]")
        #expect(CallerFormula.replacingIndexedInputs(in: "a + b") == "a + b")
    }

    @Test("The syntax summary lists exactly what the evaluator supports")
    func syntaxSummary() {
        #expect(ExpressionEvaluator.supportedFunctions == [
            "abs", "ceiling", "cos", "exp", "floor", "ln", "log", "log10", "max", "min", "pow",
            "sin", "sqrt", "tan", "trunc",
        ])
        #expect(ExpressionEvaluator.supportedConstants == ["e", "pi"])
        #expect(CallerFormula.syntaxSummary.contains(
            "Functions: abs, ceiling, cos, exp, floor, ln, log, log10, max, min, pow, sin, sqrt, tan, trunc (log is base 10"))
        #expect(CallerFormula.syntaxSummary.contains("Constants: e, pi."))
    }
}
