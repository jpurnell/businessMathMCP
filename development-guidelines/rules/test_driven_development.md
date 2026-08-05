# [PROJECT_NAME] Test-Driven Development & Evaluation Directive
### Swift Testing Framework • Deterministic • Auditable • Playground-Executable

---

# Purpose

This document defines the **mandatory Test-Driven Development (TDD) and evaluation standard** for all analytical, statistical, modeling, optimization, and financial functionality in this project.

It is designed to:

- ✅ Enforce deterministic, auditable testing  
- ✅ Guarantee statistical and numerical robustness  
- ✅ Prevent stochastic flakiness  
- ✅ Ensure examples compile in Playgrounds  
- ✅ Ensure documentation examples are executable  
- ✅ Enable LLM-driven, machine-actionable evaluation  
- ✅ Protect against numerical instability and adversarial inputs  

This document stands as the **authoritative testing contract** for this repository.

---

# Core Principles

> No analytical code is complete without deterministic, reproducible, adversarially validated tests.

> Every example in documentation must compile and execute.

> Every stochastic function must be seed-controlled and auditable.

> A statistical library is only as reliable as its worst numerical edge case.

---

# Required Framework

All tests must use:

```swift
import Testing
```

Never use XCTest.

Required constructs:

- `@Suite`
- `@Test`
- `@Test(arguments:)`
- `#expect`
- `#expect(throws:)`
- `.timeLimit(...)`
- `@Suite(.serialized)` when necessary

---

# Deterministic Randomness Standard (MANDATORY)

All stochastic functions must:

1. Accept an explicit seed parameter.
2. Default to deterministic behavior in tests.
3. Never rely on implicit randomness during testing.
4. Produce auditable results.

---

## Required Seeded Generator

All tests must use the same canonical deterministic generator:

```swift
public struct DeterministicRNG: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}
```

---

## Mandatory Rule

Every stochastic test must:

- Use a fixed seed
- Use sufficient sample size
- Compute tolerance from theory
- Never assert exact equality on Monte Carlo results

---

## Example (Playground-Executable)

```swift
import Testing
@testable import [PROJECT_NAME]

@Suite("Monte Carlo Tests")
struct MonteCarloTests {

    @Test("Deterministic integration of x^2")
    func integrateXSquared() {
        func f(_ x: Double) -> Double { x * x }

        var rng = DeterministicRNG(seed: 42)
        let result = integrate(f, iterations: 50_000, using: &rng)

        let expected = 1.0 / 3.0
        let tolerance = 0.01

        #expect(abs(result - expected) < tolerance)
    }
}
```

This example must compile in:

- Xcode test target
- Swift Playgrounds
- Documentation builds

---

# Documentation Executability Requirement

All code examples in documentation must:

- Compile without modification
- Include necessary imports
- Use deterministic seeds
- Avoid pseudocode
- Avoid ellipses (`...`)
- Avoid placeholders

If documentation cannot compile, it is invalid.

---

# Floating Point Safety (MANDATORY)

Never use direct equality for `Double`.

❌ Forbidden:

```swift
#expect(result == 0.3989)
```

✅ Required:

```swift
#expect(abs(result - 0.3989) < 1e-6)
```

---

## Recommended Helper

```swift
public func approxEqual(
    _ a: Double,
    _ b: Double,
    tolerance: Double = 1e-6
) -> Bool {
    abs(a - b) <= tolerance
}
```

---

# Required Test Coverage Per Function

Every public function must include:

---

## 1️⃣ Golden Path Test

Validate expected behavior with known values.

---

## 2️⃣ Edge Case Tests

### Distributions
- x below support
- x above support
- x = 0
- p = 0
- p = 1
- n = 0
- n = 1
- very large parameters
- very small parameters

### Correlation
- Perfect positive correlation
- Perfect negative correlation
- Constant vector
- Unequal length arrays
- Empty arrays
- NaN input
- Infinity input

### Confidence Intervals
- CI = 0
- CI = 1
- n = 1
- n extremely large
- stdDev = 0
- population < sample
- negative population

---

## 3️⃣ Invalid Input Tests

All public APIs must explicitly reject:

- Empty arrays
- NaN
- Infinity
- Negative sizes
- Probabilities outside [0, 1]
- Dimension mismatch
- Invalid statistical parameters

Example:

```swift
@Test("Reject negative stdDev")
func rejectNegativeStdDev() {
    #expect(throws: StatisticsError.invalidStandardDeviation.self) {
        _ = normalPDF(x: 0, mean: 0, stdDev: -1)
    }
}
```

---

## 4️⃣ Property-Based Tests

Where mathematically applicable:

- CDF monotonicity
- Symmetry
- Normalization
- Variance ≥ 0
- Correlation ∈ [-1, 1]

Example:

```swift
@Test("Normal CDF monotonicity")
func normalCDFMonotonicity() {
    for x in stride(from: -4.0, to: 4.0, by: 0.1) {
        #expect(normalCDF(x) <= normalCDF(x + 0.1))
    }
}
```

---

## 5️⃣ Numerical Stability Tests

Must test:

- Very small inputs (1e-12)
- Very large inputs (1e12)
- Underflow risk
- Overflow risk
- Catastrophic cancellation scenarios

---

## 6️⃣ Stress Tests

For large n:

```swift
@Test(.timeLimit(.seconds(2)))
func largeInputPerformance() {
    let values = Array(repeating: 1.0, count: 1_000_000)
    #expect(mean(values) == 1.0)
}
```

---

## 7️⃣ Fault Injection Tests

> *Inspired by NASA's Artemis II verification process, which uses large-scale fault injection
> to emulate catastrophic hardware failures and verify the software can "fail silent" and recover.*

Fault injection tests deliberately corrupt intermediate state, inject invalid values mid-pipeline, or simulate resource exhaustion to verify the system fails gracefully rather than producing wrong results.

### Numerical Corruption

Inject NaN or Inf into intermediate values (not just inputs) to verify propagation is caught:

```swift
@Test("Optimizer handles NaN gradient mid-computation")
func optimizerNaNGradient() throws {
    // Objective function that produces NaN gradient at a specific point
    let poisonedObjective: ([Double]) -> Double = { x in
        if x[0] > 5.0 { return .nan }
        return x[0] * x[0] + x[1] * x[1]
    }

    let result = try optimizer.minimize(
        poisonedObjective,
        startingPoint: [6.0, 1.0]
    )

    // Must signal degradation, not return NaN as a "solution"
    #expect(result.terminationReason == .numericalInstability)
    #expect(result.bestSolution.allSatisfy { $0.isFinite })
}
```

### State Corruption

Feed malformed data to subsystems that process structured input:

```swift
@Test("Expression evaluator rejects corrupted bytecode")
func corruptedBytecode() {
    var bytecode = validExpression.compiledBytecode
    bytecode[bytecode.count / 2] = 0xFF  // Corrupt mid-stream

    #expect(throws: CompilationError.self) {
        try ExpressionEvaluator(bytecode: bytecode).evaluate(inputs: sampleInputs)
    }
}
```

### Resource Exhaustion

Verify graceful handling under constrained conditions:

```swift
@Test("Simulation handles timeout gracefully", .timeLimit(.seconds(5)))
func simulationTimeout() throws {
    // Intentionally slow model that would take minutes to converge
    let result = try simulator.run(
        model: extremelySlowModel,
        maxIterations: 1_000_000
    )

    // Should terminate within time limit with partial results, not crash
    #expect(result.executionNotes.contains { $0.contains("timeout") || $0.contains("partial") })
}
```

---

# Parallel Test Safety (MANDATORY)

All tests run with `--parallel` in CI. A single `fatalError` or precondition failure crashes the **entire test runner**, failing all suites — not just the offending test.

### Range Guard Rule

Never construct a `Range` from a value that could be zero or negative:

```swift
// ❌ Crashes test runner if spectrum.count == 0
let peak = (1..<spectrum.count).max(by: { spectrum[$0] < spectrum[$1] })
```

```swift
// ✅ Guard first — fails gracefully
guard spectrum.count > 1 else { return }
let peak = (1..<spectrum.count).max(by: { spectrum[$0] < spectrum[$1] })
```

### Test Mocks and Sendable

Test mock classes that conform to `Sendable` protocols but need mutable tracking state should use `@unchecked Sendable`:

```swift
final class MockProvider: SomeProvider, @unchecked Sendable {
    var callCount = 0  // Mutable tracking for test assertions
    // ...
}
```

This is acceptable for **test-only** code where instances are used single-threaded within a test function. Production code must use proper synchronization.

### Thread Sanitizer in CI

Add a scheduled Thread Sanitizer job to your CI workflow:

```yaml
- name: Build + Test with Thread Sanitizer
  run: |
    swift test --sanitize thread --enable-swift-testing --parallel
```

Key constraints:
- Runs in **Debug mode** (TSan is incompatible with Release optimizations)
- **macOS only** (Xcode includes TSan; Linux support is less reliable)
- Adds **2-20x overhead**, hence scheduled rather than per-push
- Detects data races with exact file/line for both conflicting accesses

### Crash-Resistant Test Design

Tests must never allow precondition-triggering code to run on unvalidated data:

1. **Validate array counts** before indexing or creating ranges
2. **Guard optional unwraps** rather than force-unwrapping
3. **Use `#expect(throws:)`** for expected failures rather than letting them propagate
4. **Use `@Suite(.serialized)`** for test suites that mutate shared state (e.g., singletons, global configuration)

---

# Concurrency Determinism Testing

> *NASA's Artemis II uses a strictly deterministic, time-triggered architecture where
> "each FCM sees the same inputs, runs the same application code, and produces the same outputs."
> Non-determinism itself is treated as a fault mode.*

Swift 6 structured concurrency (`async/await`, `TaskGroup`, actors) introduces non-deterministic interleaving that makes tests flaky. Concurrent code must be **testable in a deterministic order**.

### Required Patterns

**1. Serial executor for deterministic async tests:**

Use `@Suite(.serialized)` for any test suite that exercises async code with ordering dependencies:

```swift
@Suite(.serialized, "Pipeline stage ordering")
struct PipelineOrderingTests {
    @Test func stagesExecuteInDeclaredOrder() async throws {
        var log: [String] = []
        let pipeline = Pipeline(stages: [
            Stage("parse") { log.append("parse") },
            Stage("validate") { log.append("validate") },
            Stage("compute") { log.append("compute") }
        ])

        try await pipeline.execute()
        #expect(log == ["parse", "validate", "compute"])
    }
}
```

**2. TaskGroup determinism — verify order-independence:**

For TaskGroup-based parallelism, first establish a baseline with a single element, then verify the aggregate result is identical regardless of completion order:

```swift
@Test("Parallel reduction is order-independent",
      arguments: [1, 2, 4, 8])
func parallelReductionDeterminism(concurrency: Int) async throws {
    let input = Array(1...1000).map { Double($0) }
    var rng = DeterministicRNG(seed: 42)

    let result = try await parallelReduce(
        input,
        concurrency: concurrency,
        using: &rng
    )

    let sequential = input.reduce(0.0, +)
    #expect(abs(result - sequential) < 1e-10,
            "Parallel result must match sequential for concurrency=\(concurrency)")
}
```

**3. Actor invariant testing — verify across await points:**

Test that actor invariants hold after concurrent access, not specific interleaving order:

```swift
@Test("Account balance is consistent under concurrent access")
func actorInvariant() async {
    let account = BankAccount(balance: 1000.0)

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 {
            group.addTask { await account.deposit(10.0) }
            group.addTask { await account.withdraw(10.0) }
        }
    }

    let balance = await account.balance
    #expect(balance == 1000.0, "Balance must be unchanged after equal deposits and withdrawals")
}
```

---

# Security & Adversarial Safeguards

Tests must guard against:

- Integer overflow
- Memory exhaustion
- Infinite loops
- Non-convergence
- log(0)
- sqrt(negative)
- exp(large)
- division by zero

Iterative algorithms must include:

```swift
@Test(.timeLimit(.seconds(2)))
func convergenceTest() {
    let result = optimize(...)
    #expect(result.converged)
}
```

---

# Parameterized Tests (Preferred)

Avoid duplication:

```swift
@Test("NPV scenarios",
      arguments: [
        (0.05, 297.59),
        (0.10, 146.87),
        (0.15, 20.42)
      ])
func npvScenarios(rate: Double, expected: Double) {
    let flows = [-1000.0, 300.0, 300.0, 300.0, 300.0]
    let result = npv(discountRate: rate, cashFlows: flows)
    #expect(abs(result - expected) < 0.01)
}
```

---

# Required Global Test Types

Each module must include:

- ✅ Golden path tests
- ✅ Edge case tests
- ✅ Invalid input tests
- ✅ Property tests
- ✅ Deterministic Monte Carlo tests
- ✅ Numerical stability tests
- ✅ Stress tests
- ✅ Regression tests
- ✅ Cross-validation tests (dissimilar algorithm or external reference)
- ✅ Fault injection tests (numerical corruption, state corruption, resource exhaustion)
- ✅ Concurrency determinism tests (for async/concurrent code)

---

# Integration Testing Patterns

Unit tests verify individual functions. Integration tests verify that **multiple components produce consistent results** when combined.

---

## When to Write Integration Tests

- Two or more components derive the same value independently (e.g., round-trip encode/decode)
- A pipeline transforms data through multiple stages
- Outputs from one module feed into another

---

## Pattern: Cross-Component Consistency

```swift
import Testing

@Suite struct RoundTripIntegrationTests {
    @Test func encodedDataDecodesIdentically() throws {
        let original = SampleModel(name: "Test", value: 42.5)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SampleModel.self, from: encoded)

        #expect(decoded == original)
    }

    @Test func derivedValueMatchesDirect() throws {
        let dataA = computeViaPathA(input)
        let dataB = computeViaPathB(input)

        #expect(dataA.result.isApproximatelyEqual(to: dataB.result, absoluteTolerance: 0.01))
    }
}
```

---

# Cross-Validation / Dissimilar Redundancy Testing

> *NASA's Artemis II carries a Backup Flight Software system that is "intentionally different —
> implemented on different hardware, running a different operating system, and utilizing
> independently developed flight software" — to guard against common-mode failures.*

Critical numerical functions must be validated against at least one **independent reference** computed by a different algorithm, published table, or external tool. This catches the dangerous scenario where an implementation *and* its test share the same flawed assumption.

---

## Three Tiers of Cross-Validation

### Tier 1: Algorithm Dissimilarity

Run the same problem through two different algorithms and compare solutions within tolerance:

```swift
@Suite("Optimizer Cross-Validation")
struct OptimizerCrossValidation {

    @Test("Gradient descent and Newton-Raphson agree on Rosenbrock minimum")
    func rosenbrockCrossValidation() throws {
        let rosenbrock: ([Double]) -> Double = { x in
            (1 - x[0]) * (1 - x[0]) + 100 * (x[1] - x[0] * x[0]) * (x[1] - x[0] * x[0])
        }
        let start = [-1.0, 1.0]

        let gdResult = try GradientDescent().minimize(rosenbrock, from: start)
        let nrResult = try NewtonRaphson().minimize(rosenbrock, from: start)

        for i in 0..<2 {
            #expect(abs(gdResult.solution[i] - nrResult.solution[i]) < 0.01,
                    "Solvers must agree on dimension \(i)")
        }
        // Both should be near [1.0, 1.0]
        #expect(abs(gdResult.solution[0] - 1.0) < 0.05)
    }
}
```

### Tier 2: External Reference

Validate against published values from authoritative sources (Excel, R, scipy, Wolfram Alpha, Bloomberg):

```swift
@Test("Bond duration matches Bloomberg reference",
      arguments: [
        // (coupon, yield, maturity, expectedDuration) from Bloomberg terminal
        (0.05, 0.04, 10, 8.1109),
        (0.03, 0.05, 5, 4.5797),
        (0.07, 0.06, 30, 13.0576)
      ])
func bondDurationReference(coupon: Double, yield: Double, maturity: Int, expected: Double) {
    let duration = bondDuration(couponRate: coupon, yieldToMaturity: yield, periods: maturity)
    #expect(abs(duration - expected) < 0.01,
            "Must match Bloomberg reference within 0.01")
}
```

### Tier 3: Analytical Cross-Check

Verify against closed-form solutions where they exist:

```swift
@Test("Monte Carlo converges to analytical Black-Scholes price")
func monteCarloBlackScholes() throws {
    let analytical = blackScholesCall(S: 100, K: 100, r: 0.05, sigma: 0.2, T: 1.0)

    var rng = DeterministicRNG(seed: 42)
    let simulated = try monteCarloOptionPrice(
        S: 100, K: 100, r: 0.05, sigma: 0.2, T: 1.0,
        iterations: 100_000, using: &rng
    )

    #expect(abs(simulated - analytical) < 0.50,
            "MC price \(simulated) must converge to analytical \(analytical)")
}
```

---

# Golden Master / Regression Testing

Detect **unintended changes** to computation outputs by comparing against a stored reference ("golden master").

---

## Pattern

1. Compute the result.
2. Compare against a previously approved snapshot.
3. Fail if different.

```swift
@Test func goldenMasterProjection() throws {
    let result = model.compute(input: knownInput)

    let goldenMaster = try loadGoldenMaster("projection_v1")

    #expect(result == goldenMaster, "Regression detected — output changed from approved baseline")
}
```

**Updating golden masters:** Only update when the output change is intentional. Require explicit approval (code review or design sign-off) before overwriting a golden master file.

---

# Test Data Management

Organize test fixtures and generators consistently across projects.

---

## Directory Convention

```
Tests/
  Fixtures/
    <category>/
      sample_input.json
      known_output.json
  TestHelpers/
    DataGenerator.swift
    TestConstants.swift
  <ModuleName>Tests/
    ...
```

---

## Guidelines

- **Generators** for deterministic synthetic data — use seeded RNGs, parameterize key values
- **Fixtures** for real-world samples — keep files small, anonymize sensitive data
- **Load fixtures** via `Bundle.module.url(forResource:withExtension:)` in SPM test targets
- **Golden master files** live in `Fixtures/` alongside their category

```swift
struct TestDataGenerator {
    static func generateSample(
        count: Int = 10,
        seed: UInt64 = 42
    ) -> [SampleModel] {
        var rng = DeterministicRNG(seed: seed)
        return (0..<count).map { i in
            SampleModel(
                name: "Item \(i)",
                value: Double.random(in: 0...1000, using: &rng)
            )
        }
    }
}
```

---

# Anti-Patterns (Forbidden)

- `try!`
- Direct equality for floating point
- Unseeded randomness
- Tests asserting only `!= 0`
- Rounding before comparison
- Duplicate test names
- Missing NaN tests
- Missing stress tests
- Non-compiling documentation examples

---

# Machine-Readable Evaluation Contract

All test suite evaluations must produce:

```json
{
  "summary": {
    "overall_quality_score": 0,
    "coverage_score": 0,
    "edge_case_score": 0,
    "invalid_input_score": 0,
    "security_score": 0,
    "systemic_risks": [],
    "high_priority_gaps": []
  },
  "per_test_analysis": [],
  "missing_global_tests": {},
  "systematic_improvement_actions": []
}
```

---

# Test Quality Gate (Automated + LLM Evaluation)

Test quality is enforced at two levels:

## Level 1: Automated (quality-gate --check test-quality)

The `test-quality` auditor runs as part of the standard quality gate and catches syntactic anti-patterns in test files via SwiftSyntax AST analysis:

| Rule ID | Severity | What It Catches |
|---------|----------|-----------------|
| `exact-double-equality` | error | `#expect(result == 0.3989)` — must use tolerance |
| `force-try-in-test` | error | `try!` in test code |
| `unseeded-random` | warning | `.random` or `SystemRandomNumberGenerator` without seed |
| `missing-assertion` | warning | `@Test` function with no `#expect`/`#require` |
| `weak-assertion` | warning | `#expect(x != 0)` or `#expect(x != nil)` without bounds |

Suppress false positives with `// SAFETY:` or `// TEST-QUALITY:` comments.

```bash
# Run as part of full quality gate
quality-gate

# Or run test quality check alone
quality-gate --check test-quality
```

## Level 2: Semantic Evaluation (/evaluate-tests)

The `/evaluate-tests` skill performs deeper semantic analysis that AST scanning cannot:

- Are the **right things** being tested? (appropriateness)
- Are all **expected behaviors** covered? (golden path)
- Are **boundary conditions** tested? (edge cases)
- Are **invalid inputs** rejected? (input validation)
- Could inputs cause **crashes or hangs**? (security/robustness)

Run during the RED phase, after writing tests but before implementing:

```bash
/evaluate-tests Tests/MyFeatureTests/MyFeatureTests.swift
```

All 5 dimensions must score >= 75 (Good) before moving to GREEN.

| Score | Meaning | Action |
|-------|---------|--------|
| 90-100 | Production-grade | Proceed |
| 75-89 | Good, minor gaps | Proceed, address gaps in refactor |
| 50-74 | Moderate weaknesses | Add missing test categories before GREEN |
| 0-49 | Significant/high risk | Stop — major test gaps must be filled first |

---

# System-Level Monte Carlo Testing

> *NASA uses "full-environment simulations and Monte Carlo stress testing to model worst-case
> latencies and communication outages" — testing the entire system, not just individual functions.*

System-level Monte Carlo differs from unit-level Monte Carlo (which tests a single function) and stress tests (which test performance). It runs **entire pipelines** thousands of times with randomized inputs to find emergent failure modes that unit tests miss.

---

## Required Pattern

```swift
@Suite("Full Pipeline Monte Carlo")
struct PipelineMonteCarlo {

    @Test("Monte Carlo simulation pipeline produces valid results across randomized inputs",
          .timeLimit(.seconds(30)))
    func simulationPipelineRobustness() throws {
        var rng = DeterministicRNG(seed: 12345)
        let iterations = 1000

        for i in 0..<iterations {
            // Randomize inputs within valid ranges
            let mean = Double.random(in: -1000...1000, using: &rng)
            let stdDev = Double.random(in: 0.001...100, using: &rng)
            let sampleCount = Int.random(in: 10...10_000, using: &rng)

            let result = try runSimulation(
                distribution: .normal(mean: mean, stdDev: stdDev),
                iterations: sampleCount
            )

            // Assert invariants — no run should violate these
            #expect(result.statistics.mean.isFinite,
                    "NaN/Inf mean at iteration \(i) with mean=\(mean), stdDev=\(stdDev)")
            #expect(result.statistics.variance >= 0,
                    "Negative variance at iteration \(i)")
            #expect(result.statistics.sampleCount == sampleCount,
                    "Sample count mismatch at iteration \(i)")
        }
    }
}
```

## Key Principles

1. **Seed the RNG** for reproducibility — a failing iteration must be replay-able.
2. **Randomize all inputs** within valid ranges. Include boundary-adjacent values.
3. **Assert invariants, not specific values** — no NaN, no negative variance, balance sheets balance, optimizers converge-or-throw.
4. **Log iteration context on failure** — include the randomized parameters in the assertion message so failures can be reproduced.
5. **Bound runtime** with `.timeLimit()` — system Monte Carlo is expensive; 30-60 seconds per test is reasonable.

## When to Write System Monte Carlo Tests

- Multi-stage pipelines (simulation, optimization, financial modeling)
- Any system where inputs flow through 3+ transformations before producing output
- Code paths with fallback logic (GPU/CPU, algorithm switching)

---

# LLM Implementation Contract

When generating code, an LLM must:

1. Write tests first.
2. Include deterministic seeds for stochastic code.
3. Include golden path + edge + invalid tests.
4. Use floating-point tolerances.
5. Include property-based tests where applicable.
6. Ensure examples compile in Playground.
7. Avoid pseudocode.
8. Avoid anti-patterns.
9. Mirror directory structure.
10. Ensure documentation examples are executable.
11. Verify `swift-tools-version` compatibility — no Swift 6.0-only syntax without explicit approval.
12. Include cross-validation against independent references for critical numerical code.
13. Include fault injection tests for multi-stage pipelines.
14. Ensure concurrent/async code is testable in deterministic order.
15. Run `/evaluate-tests` on the test file and achieve >= 75 on all 5 dimensions before moving to GREEN phase.
16. Ensure `quality-gate --check test-quality` passes with zero diagnostics.

---

# Final Guiding Rule

> Determinism enables auditability.  
> Auditability enables trust.  
> Trust requires adversarial validation.

No analytical function is production-ready until it is:

- Deterministic
- Statistically validated
- Numerically stable
- Edge-case hardened
- Adversarially tested
- Cross-validated against independent references
- Fault-injection tested across pipeline stages
- Fully executable in documentation

---
