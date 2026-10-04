import Foundation
import SwiftMCPServer

// MARK: - FormulaFailure

/// Why a formula a caller supplied produced no value.
///
/// Both cases are about text and numbers the caller sent, so both reach the caller. The
/// sentence at the end of each message is `ExpressionError`'s own, which names the position,
/// the name or the limit at fault.
public enum FormulaFailure: Error, Equatable, Sendable {
    /// The formula is outside the grammar, or uses a name, function or placeholder that has no
    /// value. No choice of inputs would make it evaluate.
    case invalid(argument: String, reason: ExpressionError)

    /// The formula is well formed and has no finite value at these inputs: it divides by zero
    /// there, or overflows.
    case undefined(argument: String, reason: ExpressionError, inputs: [FormulaInput])

    /// Sorts an evaluation error into the two cases by what kind of error it is.
    ///
    /// - Parameters:
    ///   - reason: What the evaluator reported.
    ///   - argument: The tool argument the formula arrived in, as the schema spells it.
    ///   - inputs: The values the formula was being evaluated at.
    init(_ reason: ExpressionError, argument: String, inputs: [FormulaInput]) {
        switch reason {
        case .divisionByZero, .notFinite:
            self = .undefined(argument: argument, reason: reason, inputs: inputs)
        default:
            self = .invalid(argument: argument, reason: reason)
        }
    }
}

extension FormulaFailure: CallerVisibleError {
    /// The message returned to the caller.
    public var callerMessage: String {
        switch self {
        case .invalid(let argument, let reason):
            return "Invalid arguments: \(argument) is not a valid formula. \(reason.callerMessage)"
        case .undefined(let argument, let reason, let inputs):
            guard !inputs.isEmpty else {
                return "Invalid arguments: \(argument) has no value. \(reason.callerMessage)"
            }
            let point = inputs.map(\.description).joined(separator: ", ")
            return "Invalid arguments: \(argument) has no value at \(point). \(reason.callerMessage)"
        }
    }
}

/// One input to a formula, as the caller would write it: `{0} = 2.5`, or `price = 2.5`.
public struct FormulaInput: Equatable, Sendable, CustomStringConvertible {
    /// How the formula refers to the input: a `{n}` placeholder, or a variable name.
    public let label: String
    /// The value it had.
    public let value: Double

    /// `label = value`.
    public var description: String { "\(label) = \(value)" }
}

// MARK: - CallerFormula

/// A formula from a tool argument, checked once and then evaluated as often as the tool needs.
///
/// Values reach the formula as values — `{0}`, `{1}`, … by position and variables by name —
/// and are never pasted into its text.
///
/// The tools that take formulas hand them to solvers and simulations whose callbacks cannot
/// throw. So there are two ways to evaluate. ``value(at:)`` throws, and is for the tool's own
/// loops. ``recordedValue(at:)`` does not: it remembers the first failure, returns `.nan` so the
/// solver has nothing to converge on, and leaves the tool to call ``throwIfFailed()`` when the
/// run is over. A failure in the middle of a run therefore fails the run, with the formula's own
/// error, rather than contributing a zero to it.
struct CallerFormula: Sendable {
    /// The tool argument the formula arrived in, as the schema spells it.
    let argument: String
    /// The formula as it is evaluated.
    let text: String
    /// The variable name each input is also known by, by position. `nil` where an input has no
    /// name a formula could use.
    let names: [String?]

    private let recorder = FormulaFailureRecorder()

    /// Checks a formula before anything is run with it.
    ///
    /// The formula is evaluated once at an arbitrary point. Anything wrong with the formula
    /// itself is thrown: a character outside the grammar, an unknown function or name, a
    /// placeholder beyond `inputCount`. A division by zero or an overflow at that point is not,
    /// because the point is arbitrary and says nothing about the caller's values.
    ///
    /// - Parameters:
    ///   - text: The formula text.
    ///   - argument: The tool argument it arrived in, for the error message.
    ///   - names: A variable name for each input, by position. A name that is not an
    ///     identifier is not bound; the input is still `{n}`.
    ///   - inputCount: How many inputs the formula will be given. Defaults to `names.count`.
    /// - Throws: ``FormulaFailure/invalid(argument:reason:)``.
    init(
        _ text: String,
        argument: String,
        names: [String] = [],
        inputCount: Int? = nil
    ) throws(FormulaFailure) {
        let count = max(inputCount ?? names.count, names.count)
        var bound: [String?] = []
        var seen: Set<String> = []
        for index in 0..<count {
            guard index < names.count, Self.isIdentifier(names[index]),
                seen.insert(names[index]).inserted
            else {
                bound.append(nil)
                continue
            }
            bound.append(names[index])
        }
        self.argument = argument
        self.text = text
        self.names = bound

        let probe = (0..<count).map { Self.probeValue(at: $0) }
        do {
            _ = try evaluate(at: probe)
        } catch {
            let failure = FormulaFailure(error, argument: argument, inputs: [])
            guard case .undefined = failure else { throw failure }
        }
    }

    /// The value of the formula at `inputs`.
    ///
    /// - Parameter inputs: One value per input, in order.
    /// - Returns: The value, which is always finite.
    /// - Throws: ``FormulaFailure`` naming the inputs if the formula has no value there.
    func value(at inputs: [Double]) throws(FormulaFailure) -> Double {
        do {
            return try evaluate(at: inputs)
        } catch {
            throw FormulaFailure(error, argument: argument, inputs: labelled(inputs))
        }
    }

    /// The value of the formula at `inputs`, for a callback that cannot throw.
    ///
    /// - Parameter inputs: One value per input, in order.
    /// - Returns: The value, or `.nan` if the formula has none there. The first failure is kept
    ///   for ``throwIfFailed()``.
    func recordedValue(at inputs: [Double]) -> Double {
        do {
            return try value(at: inputs)
        } catch {
            recorder.record(error)
            return .nan
        }
    }

    /// Throws the first failure ``recordedValue(at:)`` met, if there was one.
    ///
    /// Call it when a run that used ``recordedValue(at:)`` ends, whether the run returned or
    /// threw: a solver given `.nan` usually reports that it did not converge, and the formula's
    /// failure is the cause.
    func throwIfFailed() throws(FormulaFailure) {
        if let failure = recorder.first {
            throw failure
        }
    }

    // MARK: Evaluation

    private func evaluate(at inputs: [Double]) throws(ExpressionError) -> Double {
        var variables: [String: Double] = [:]
        for (name, value) in zip(names, inputs) {
            if let name {
                variables[name] = value
            }
        }
        return try ExpressionEvaluator.evaluate(text, variables: variables, positional: inputs)
    }

    private func labelled(_ inputs: [Double]) -> [FormulaInput] {
        inputs.enumerated().map { index, value in
            let name = index < names.count ? names[index] : nil
            return FormulaInput(label: name ?? "{\(index)}", value: value)
        }
    }

    /// An arbitrary, finite, distinct value for each input of the up-front check.
    private static func probeValue(at index: Int) -> Double {
        1.5 + Double(index) * 0.25
    }

    // MARK: Names

    /// Whether `name` can be written in a formula: a letter or underscore, then letters, digits
    /// and underscores, all ASCII.
    static func isIdentifier(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first, first == "_" || isASCIILetter(first) else {
            return false
        }
        return name.unicodeScalars.allSatisfy { scalar in
            scalar == "_" || isASCIILetter(scalar) || ("0"..."9").contains(scalar)
        }
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    /// Rewrites the `inputs[n]` spelling of a positional input as `{n}`.
    ///
    /// The replacement is padded to the length of what it replaces, so the character positions
    /// an `ExpressionError` reports are positions in the text the caller sent.
    ///
    /// - Parameter text: The formula as the caller wrote it.
    /// - Returns: The same formula with every `inputs[n]` written as `{n}`.
    static func replacingIndexedInputs(in text: String) -> String {
        text.replacing(#/\binputs\[([0-9]+)\]/#) { match in
            let placeholder = "{\(match.output.1)}"
            let padding = String(repeating: " ", count: match.output.0.count - placeholder.count)
            return padding + placeholder
        }
    }

    /// A sentence for a tool description: the formula grammar, from the evaluator's own lists.
    static let syntaxSummary: String = {
        let functions = ExpressionEvaluator.supportedFunctions.joined(separator: ", ")
        let constants = ExpressionEvaluator.supportedConstants.joined(separator: ", ")
        return """
            Formula syntax: numbers, + - * / and ^ (power, right-associative; -2 ^ 2 is -4), \
            parentheses. Division is floating-point (10 / 4 is 2.5). \
            Functions: \(functions) (log is base 10, ln is natural; min and max take one or \
            more arguments). Constants: \(constants). \
            Dividing by zero, or a result that is not a finite number, is an error.
            """
    }()
}

// MARK: - FormulaFailureRecorder

// Justification: `failure` is the only mutable state and is read and written only while holding `lock`.
private final class FormulaFailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var failure: FormulaFailure?

    /// The first failure recorded, if any.
    var first: FormulaFailure? {
        lock.lock()
        defer { lock.unlock() }
        return failure
    }

    /// Keeps `newFailure` if nothing has been recorded yet.
    func record(_ newFailure: FormulaFailure) {
        lock.lock()
        defer { lock.unlock() }
        if failure == nil {
            failure = newFailure
        }
    }
}
