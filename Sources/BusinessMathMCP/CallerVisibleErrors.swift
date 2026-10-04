import Foundation
import BusinessMath
import SwiftMCPServer

// What a tool's errors may say to whoever called it.
//
// SwiftMCPServer returns an error's text only if the error's type conforms to
// `CallerVisibleError`; anything else becomes a fixed sentence and a reference id. Every type
// here is thrown about the caller's own numbers — a series too short, a rate out of range, a
// matrix that is not square — so each conforms.
//
// The BusinessMath types are conformed here rather than in BusinessMath, which does not know
// about this protocol; `@retroactive` says so. Four of them already have an authored
// `errorDescription` and use it. The rest have none: without a conformance a caller would be
// told nothing, and with a one-line one they would be told
// "The operation couldn't be completed. (BusinessMath.ForecastError error 0.)". Each case has a
// sentence written for it instead.
//
// A case's associated text is included when BusinessMath wrote it about the caller's data, and
// left out where it can describe the library's own workings (`OptimizationError`, whose messages
// name solver types and GPU state, and `MatrixError.invalidDecomposition`, which quotes LAPACK).

// MARK: - This package's own errors

extension MarshallingError: CallerVisibleError {
    /// What was wrong with the time series the caller sent.
    public var callerMessage: String { errorDescription ?? "The time series is not valid." }
}

extension ResourceError: CallerVisibleError {
    /// The URI the caller asked for, and that it does not exist.
    public var callerMessage: String { errorDescription ?? "Resource not found." }
}

// MARK: - BusinessMath errors with an authored description

extension BusinessMathError: @retroactive CallerVisibleError {
    /// BusinessMath's own description of what was wrong with the calculation's inputs.
    public var callerMessage: String { errorDescription ?? "The calculation failed." }
}

extension FinancialModelError: @retroactive CallerVisibleError {
    /// BusinessMath's own description of what was wrong with the statement's accounts.
    public var callerMessage: String { errorDescription ?? "The financial model is not valid." }
}

extension SimulationError: @retroactive CallerVisibleError {
    /// BusinessMath's own description of why the simulation could not run.
    public var callerMessage: String { errorDescription ?? "The simulation could not be run." }
}

extension ScenarioError: @retroactive CallerVisibleError {
    /// BusinessMath's own description of what was wrong with the scenarios.
    public var callerMessage: String { errorDescription ?? "The scenarios are not valid." }
}

// MARK: - BusinessMath errors with no description

extension TrendModelError: @retroactive CallerVisibleError {
    /// What was wrong with the data a trend was fitted to or projected from.
    public var callerMessage: String {
        switch self {
        case .modelNotFitted:
            return "The trend model has not been fitted to data."
        case .insufficientData(let required, let provided):
            return "Not enough data to fit the trend: \(required) data point(s) are required and \(provided) were provided."
        case .invalidData(let detail):
            return "The data cannot be used for this trend model: \(detail)"
        case .projectionFailed(let detail):
            return "The trend could not be projected: \(detail)"
        }
    }
}

extension SeasonalityError: @retroactive CallerVisibleError {
    /// What was wrong with the series or the seasonal indices.
    public var callerMessage: String {
        switch self {
        case .insufficientData(let required, let provided):
            return "Not enough data for the seasonal calculation: \(required) data point(s) are required and \(provided) were provided."
        case .mismatchedSizes(let timeSeriesCount, let indicesCount):
            return "The seasonal indices do not fit the time series: \(indicesCount) indices were supplied for \(timeSeriesCount) data point(s). At least one index is required."
        case .invalidPeriodsPerYear(let periods):
            return "periodsPerYear must be greater than zero; got \(periods)."
        case .divisionByZero(let detail):
            return "The seasonal adjustment divides by zero: \(detail)"
        }
    }
}

extension OperationsError: @retroactive CallerVisibleError {
    /// What was wrong with the inventory or operations inputs.
    public var callerMessage: String {
        switch self {
        case .insufficientData(let required, let got):
            return "Not enough data: \(required) observation(s) are required and \(got) were provided."
        case .invalidParameter(let detail):
            return "Invalid parameter: \(detail)"
        case .invalidServiceLevel:
            return "The service level must be greater than 0 and less than 1."
        case .zeroDemand:
            return "Demand must be greater than zero."
        case .negativeCost:
            return "Every cost must be greater than zero."
        }
    }
}

extension ForecastError: @retroactive CallerVisibleError {
    /// What was wrong with the series or the forecast's settings.
    public var callerMessage: String {
        switch self {
        case .insufficientData(let required, let got):
            return "Not enough data to forecast: \(required) data point(s) are required and \(got) were provided."
        case .modelNotTrained:
            return "The forecast model has not been trained on data."
        case .invalidParameter(let detail):
            return "Invalid forecast parameter: \(detail)"
        case .invalidConfidenceLevel:
            return "The confidence level must be greater than 0 and no greater than 1."
        }
    }
}

extension ValuationError: @retroactive CallerVisibleError {
    /// What was wrong with the valuation's inputs or assumptions.
    public var callerMessage: String {
        switch self {
        case .invalidParameters(let detail):
            return "Invalid valuation parameters: \(detail)"
        case .invalidModelAssumptions(let detail):
            return "The valuation model's assumptions do not hold: \(detail)"
        case .insufficientData(let detail):
            return "Not enough data for the valuation: \(detail)"
        }
    }
}

extension PortfolioOptimizerError: @retroactive CallerVisibleError {
    /// What was wrong with the portfolio's inputs.
    public var callerMessage: String {
        switch self {
        case .emptyReturns:
            return "Expected returns must contain at least one asset."
        }
    }
}

extension AccountError: @retroactive CallerVisibleError {
    /// What was wrong with an account in a financial statement.
    public var callerMessage: String {
        switch self {
        case .invalidName:
            return "An account name must not be empty."
        case .emptyTimeSeries:
            return "An account must have a value for at least one period."
        case .invalidAccountType(let expected, let actual):
            return "Account type '\(actual.rawValue)' is not a '\(expected.rawValue)' account type."
        }
    }
}

extension ExperimentError: @retroactive CallerVisibleError {
    /// What was wrong with the experiment's design or its observed counts.
    public var callerMessage: String {
        switch self {
        case .invalidPower(let power):
            return "Power must be greater than 0 and less than 1; got \(power)."
        case .invalidAlpha(let alpha):
            return "The significance level must be greater than 0 and less than 1; got \(alpha)."
        case .nonPositiveEffect(let effect):
            return "The minimum detectable effect must be greater than zero; got \(effect)."
        case .invalidProportion(let proportion):
            return "A proportion must be between 0 and 1; got \(proportion). Check the baseline rate, and the baseline plus the effect."
        case .nonPositiveStandardDeviation(let deviation):
            return "The standard deviation must be greater than zero; got \(deviation)."
        case .emptyArm(let arm):
            return "The \(arm) arm has no observations."
        case .conversionsExceedObservations(let arm, let conversions, let observations):
            return "The \(arm) arm's conversions (\(conversions)) must be between 0 and its observations (\(observations))."
        case .nonPositiveSampleSize(let size):
            return "The sample size per arm must be greater than zero; got \(size)."
        }
    }
}

extension RegressionError: @retroactive CallerVisibleError {
    /// What was wrong with the regression's observations.
    public var callerMessage: String {
        switch self {
        case .insufficientData(let detail):
            return "Not enough data for the regression: \(detail)"
        case .dimensionMismatch(let expected, let actual):
            return "The regression's inputs disagree in size: \(expected); \(actual)."
        case .invalidPredictorMatrix(let detail):
            return "The predictor matrix is not valid: \(detail)"
        case .singularMatrix(let detail):
            return "The regression has no unique solution: \(detail)"
        case .noVariance(let detail):
            return "The regression cannot be fitted: \(detail)"
        }
    }
}

extension MatrixError: @retroactive CallerVisibleError {
    /// What was wrong with a matrix the caller supplied.
    public var callerMessage: String {
        switch self {
        case .notPositiveDefinite:
            return "The matrix must be positive definite."
        case .notSquare:
            return "The matrix must be square."
        case .invalidDimensions(let expected, let actual):
            return "The matrix's dimensions are not valid. Expected: \(expected). Got: \(actual)."
        case .notSymmetric:
            return "The matrix must be symmetric."
        case .singularMatrix:
            return "The matrix is singular, so it cannot be inverted."
        case .dimensionMismatch(let expected, let actual):
            return "The matrix dimensions do not match. Expected: \(expected). Got: \(actual)."
        case .invalidDecomposition:
            // The reason quotes the LAPACK routine and its status code.
            return "The matrix could not be decomposed. Check that every value is finite and that the matrix is well conditioned."
        }
    }
}

extension OptimizationError: @retroactive CallerVisibleError {
    /// What kind of failure stopped a solver, without the solver's own account of it.
    ///
    /// The associated messages name solver types, tableau state and GPU command buffers, so none
    /// is passed on.
    public var callerMessage: String {
        switch self {
        case .failedToConverge:
            return "The calculation did not converge. Check that the inputs describe a problem with a solution, or try different starting values or more iterations."
        case .invalidInput:
            return "The inputs do not describe a problem that can be solved. Check that every required value is present and that the numbers of variables, coefficients and constraints agree."
        case .dimensionMismatch:
            return "The inputs disagree in size. Check that the numbers of variables, coefficients and constraints agree."
        case .nonFiniteValue:
            return "The calculation produced a value that is not a finite number. Check the inputs for extreme or degenerate values."
        case .numericalInstability:
            return "The calculation is numerically unstable for these inputs. Rescaling the inputs may help."
        case .singularMatrix:
            return "The inputs form a singular matrix, so the problem has no unique solution."
        case .maxIterationsReached:
            return "The calculation reached its iteration limit without converging."
        case .unsupportedConstraints:
            return "The method does not support this kind of constraint."
        case .nonlinearModel:
            return "The method requires a linear model, and the one supplied is not linear."
        }
    }
}

extension XNPVError: @retroactive CallerVisibleError {
    /// What was wrong with dated cash flows.
    public var callerMessage: String {
        switch self {
        case .mismatchedArrays:
            return "There must be one date for each cash flow."
        case .invalidCashFlows:
            return "The cash flows must include at least one positive and one negative amount."
        case .insufficientData:
            return "At least two cash flows are required."
        case .convergenceFailed:
            return "The rate did not converge for these cash flows. Try a different guess."
        }
    }
}

extension BacktestError: @retroactive CallerVisibleError {
    /// What was wrong with the series or the backtest's settings.
    public var callerMessage: String {
        switch self {
        case .seriesTooShort(let required, let got):
            return "The series is too short to backtest: \(required) data point(s) are required and \(got) were provided."
        case .invalidConfig(let detail):
            return "Invalid backtest configuration: \(detail)"
        case .unforecastableSeries(let spectralEntropy, let threshold):
            return "The series is indistinguishable from noise (spectral entropy \(spectralEntropy) exceeds the threshold \(threshold)), so no forecast was produced."
        }
    }
}

extension CorrelatedNormalsError: @retroactive CallerVisibleError {
    /// What was wrong with the means or the correlation matrix.
    public var callerMessage: String {
        switch self {
        case .dimensionMismatch:
            return "The correlation matrix must have one row and one column for each input."
        case .invalidCorrelationMatrix:
            return "The correlation matrix is not valid. It must be symmetric, have 1 on its diagonal, hold values between -1 and 1, and be positive semi-definite."
        }
    }
}
