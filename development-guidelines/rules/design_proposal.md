# Design Proposal Phase

**Purpose:** Validate architectural approach BEFORE writing tests or code.

> **This phase is MANDATORY for all non-trivial features.**
>
> Skipping this phase leads to wasted effort when the implementation violates
> project constraints, module boundaries, or architectural patterns.

---

## When to Use This Phase

| Situation | Design Proposal Required? |
|-----------|---------------------------|
| New feature with multiple components | Yes |
| Changes to existing architecture | Yes |
| New module or subsystem | Yes |
| Performance-critical code | Yes |
| Simple bug fix | No |
| Adding a single function with clear requirements | No |
| Documentation-only changes | No |

**Rule of thumb:** If you need to make decisions about *where* code goes or *how* components interact, write a design proposal first.

---

## Design Proposal Template

**Where to save proposals:** `project/plans/proposals/FeatureName.md`
Proposals remain in `PROPOSALS/` until user approval, then move to `UPCOMING/`.

Before writing any tests or implementation code, create a brief proposal covering:

### 1. Objective

*What problem does this solve? Reference the Master Plan if applicable.*

```markdown
**Objective:** Add Monte Carlo simulation capability to support risk analysis.
**Master Plan Reference:** Phase 2 - Simulation & Risk Analytics
```

### 2. Motivation

*What are the current pain points? How do developers work around this limitation today, and what are the drawbacks of those workarounds?*

```markdown
**Current situation:** Risk analysis requires manual iteration loops with no
convergence checking or reproducibility guarantees.

**Workaround:** Developers write ad-hoc for-loops with inline statistics,
leading to duplicated code and non-deterministic results across runs.

**Drawback:** No seedable randomness, no standard result format, and
statistical summaries are recomputed from scratch each time.
```

### 3. Proposed Architecture

*Where will the code live? What modules/files will be created or modified?*

```markdown
**New Files:**
- Sources/[Project]/Simulation/MonteCarloEngine.swift
- Sources/[Project]/Simulation/SimulationResult.swift

**Modified Files:**
- Sources/[Project]/Statistics/Distributions.swift (add sampling methods)

**Module Placement:** Simulation/ (new module)
```

### 4. API Surface

*What will the public interface look like? Show key types and functions.*

```swift
// Proposed API
public struct MonteCarloEngine<T: Real> {
    public init(iterations: Int, seed: UInt64?)
    public func simulate(_ model: () -> T) -> SimulationResult<T>
}

public struct SimulationResult<T: Real> {
    public let values: [T]
    public let statistics: SimulationStatistics<T>
}
```

### 5. MCP Schema

> **Why MCP?** In an AI-integrated development environment, every public API should
> be consumable by AI tools. Designing with machine-readable schemas from the start
> improves clarity and future-proofs the project.

*How will this API be consumed by AI models? Define the JSON schema.*

```markdown
**Tool Description:** Run Monte Carlo simulation with configurable iterations.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "iterations": 10000,
  "seed": 42,
  "model": {
    "type": "normal",
    "parameters": {"mean": 100, "stdDev": 15}
  }
}
```

**Parameter Types:**
- iterations (integer): Number of simulation runs. Must be > 0.
- seed (integer): Random seed for reproducibility. Required for deterministic results.
- model (object): Distribution configuration.
  - type (string): "normal", "uniform", or "triangular"
  - parameters (object): Distribution-specific parameters
```

### 6. Constraints & Compliance

*How does this design comply with project rules?*

```markdown
**Concurrency:** SimulationResult is Sendable (immutable value type)
**Determinism:** Accepts optional seed for reproducible results
**Generics:** Generic over Real protocol per coding rules
**Safety:** No force unwraps, bounded iteration, validates inputs
**MCP Ready:** JSON schema defined, all types explicit
```

### 7. Source & API Compatibility

*Does this change affect existing callers? Can it be adopted incrementally?*

```markdown
**Breaking changes:** None — this is a new module with no existing API surface.
**Incremental adoption:** Yes — consumers can import Simulation independently.
**Type-checking risk:** No overloads of existing functions introduced.
```

> **When this matters most:** Any change that modifies, overloads, or shadows
> an existing public API. New modules with no prior surface can state
> "N/A — entirely new API with no existing callers."

### 8. Backend Abstraction (If Compute-Intensive)

*For compute-intensive operations, define the backend protocol. Most Swift code runs on Apple platforms where Metal and Accelerate are available—design for this default.*

```markdown
**Backend Protocol:** SimulationBackend
**CPU Implementation:** Default, always available
**GPU Implementation:** Metal-accelerated for n > 10,000
**Accelerate Implementation:** SIMD-optimized for batch operations

**Auto-switching Threshold:** n > 10,000 triggers GPU backend
**Fallback:** CPU backend if Metal unavailable
```

> **Note:** This section is optional—include only for compute-intensive features.
> GPU/Accelerate backends are the default assumption for Apple platforms.
> For Linux server deployments, ensure CPU-only fallback is explicitly defined.

### 9. Dependencies

*What existing code does this depend on? Any new external dependencies?*

```markdown
**Internal Dependencies:**
- Statistics/Distributions.swift (for sampling)
- Utilities/DeterministicRNG.swift (for seeded randomness)

**External Dependencies:** None (uses swift-numerics only)
```

### 10. Test Strategy

*What categories of tests will be written? What is the source of truth for validation?*

```markdown
**Test Categories:**
- Golden path: Known distribution → expected statistics
- Edge cases: Zero iterations, single iteration, very large n
- Determinism: Same seed → identical results
- Performance: 100k iterations completes in <1s

**Reference Truth:** [Specify the validation source]
- Example: "Excel NPV() function", "scipy.stats.norm", "Equation 4.12 from Hull (2018)"
- Must be independently verifiable — no hallucinated expected values

**Validation Trace (REQUIRED):** Show specific inputs → expected outputs
- Example: "Validate futureValue against Excel's FV(0.05/12, 60, -100, 0) = 6,800.61"
- This exact value becomes the Golden Path test assertion
- Prevents LLM from "hallucinating" correctness
```

### 11. Architecture Decision Review

*Does this proposal require a new ADR or supersede an existing one?*

```markdown
**ADR Check:**
- [ ] Reviewed `architecture_decisions.md` for related decisions
- [ ] Does this supersede an existing ADR? [No / Yes → ADR-NNN]
- [ ] Does this amend an existing ADR? [No / Yes → ADR-NNN]
- [ ] New ADR required? [No / Yes → draft entry below]

**New ADR Draft (if required):**
- Title: [Decision title]
- Category: [concurrency | storage | api | testing | performance | architecture]
- Key decision: [One sentence]
```

> **Why here?** Checking ADRs during design — not at session end — ensures the
> decisions log stays current and the AI doesn't re-discover rejected approaches.

### 12. Adversarial Review

*Argue against this design before accepting it. Per `project/master_plan.md` (Collaboration Principles), high confidence in a proposal triggers harder questions, not faster acceptance.*

Required before the proposal can be approved. Answer each prompt directly — "none" is a valid answer only if you can defend it.

```markdown
**Strongest case for a different approach:**
- What alternative module placement, API shape, or backend would a thoughtful reviewer push for?
- Why might that alternative actually be better than what's proposed above?

**Where this design is most likely wrong:**
- Which assumption, if violated, breaks the design? (e.g., "assumes inputs are always pre-validated")
- Which constraint did we accept without challenging? (e.g., "took the first Sendable design without checking if a value type would suffice")

**What an experienced critic would say:**
- One sentence summarizing the most credible objection.
- One sentence on why we're proceeding anyway (or what we changed in response).
```

> **Why this exists:** Confident-sounding AI proposals are the most expensive kind to be wrong about, because they short-circuit the human review that would catch the error. Forcing a counterargument here — at the cheapest point in the workflow — is the highest-leverage check in the process.

### 13. Alternatives Considered

*What other approaches were considered? Present them fairly, then explain why this proposal is preferred.*

```markdown
**Alternative 1: Extend existing Statistics module instead of new Simulation module**
- Advantage: No new module boundary; simpler imports
- Disadvantage: Conflates descriptive statistics with generative simulation;
  the Statistics module grows unbounded
- Why rejected: Separation of concerns — simulation has distinct lifecycle
  (setup → run → collect) that doesn't fit the functional style of Statistics

**Alternative 2: Use an external library (e.g., swift-numerics random distributions)**
- Advantage: Less code to maintain
- Disadvantage: No library provides the full simulate-and-summarize pipeline;
  we'd still need the engine and result types
- Why rejected: External dependency adds risk for marginal code savings
```

> **Relationship to Adversarial Review:** The Adversarial Review (section 12) argues
> against *this* design to stress-test it. This section fairly presents
> *other* designs to show the reviewer why they were not chosen.

### 14. Future Directions

*What could build on this feature in the future? Describe possibilities without committing to them.*

```markdown
- **Correlated random variables:** Multi-asset simulation with correlation matrices
- **Convergence detection:** Auto-stop when statistics stabilize within tolerance
- **Streaming results:** Yield partial statistics during long-running simulations
```

> **Keep this neutral.** Use "could" or "might," not "will" or "should."
> If an item listed here feels essential, it probably belongs in the main proposal.
> This section prevents scope creep during review while acknowledging the larger vision.

### 15. Open Questions

*Anything that needs clarification before proceeding? Items surfaced by the Adversarial Review or Alternatives Considered often land here.*

```markdown
- Should SimulationResult store all values or just statistics?
- Should we support correlated random variables in v1?
```

### 16. Documentation Strategy

*Will this feature require API docs only, or a narrative article?*

```markdown
**Documentation Type:** [API Docs Only / Narrative Article Required]

**Complexity Threshold Check:**
- Does it combine 3+ APIs? [Yes/No]
- Does explanation require 50+ lines? [Yes/No]
- Does it need theory/background context? [Yes/No]

If any answer is "Yes" → Narrative Article Required (.md in .docc)

**Article Name (if required):** [FeatureName]Guide.md
(Must NOT match any Swift symbol name to avoid DocC parser conflicts)
```

---

## Proposal Review Checklist

Before proceeding to TDD, verify:

### Architecture
- [ ] **Module placement** follows existing project structure
- [ ] **API design** follows naming conventions from Coding Rules
- [ ] **Concurrency model** is Swift 6 compliant (Sendable, actor isolation)
- [ ] **Generic constraints** use appropriate protocols (Real, Comparable, etc.)
- [ ] **No forbidden patterns** in proposed implementation
- [ ] **Usage examples reviewed** — verify `usage_examples.md` patterns are not broken

### Compatibility & Evolution
- [ ] **Source compatibility** assessed — breaking changes identified or confirmed absent
- [ ] **Adoption path** documented — incremental adoption is possible
- [ ] **Future directions** listed without commitments — "could" not "will"
- [ ] **Alternatives considered** with fair assessment — at least one alternative with pros/cons

### MCP Readiness
- [ ] **MCP JSON schema** defined with REQUIRED STRUCTURE example
- [ ] **All parameter types** mapped to JSON Schema types
- [ ] **Stochastic functions** include seed parameter
- [ ] **Nested objects** fully documented with all properties
- [ ] **Enum values** listed exhaustively
- [ ] **Date formats** specified as ISO 8601

### Backend Abstraction (if compute-intensive)
- [ ] **Backend protocol** defined for CPU/GPU switching
- [ ] **Threshold** specified for auto-switching to GPU (default on Apple)
- [ ] **Fallback behavior** defined for Linux server deployments

### Testing & Dependencies
- [ ] **Test strategy** covers required categories (golden path, edge, invalid, determinism)
- [ ] **Reference truth** identified (Excel function, academic paper, external library)
- [ ] **Dependencies** are acceptable (no unapproved external packages)
- [ ] **Open questions** resolved or deferred explicitly

### Adversarial Review
- [ ] **Counter-design** articulated — strongest case for a different approach is on the page
- [ ] **Failure mode** named — at least one assumption whose violation would break this design
- [ ] **Critic's objection** captured in one sentence, with response or accepted tradeoff

---

## Workflow Integration

The Design Proposal phase fits into the TDD workflow as **Step 0**:

> **Full Workflow:** See [Implementation Checklist Template](../templates/checklist.md) for the complete Design-First TDD cycle.

---

## Example: Minimal Design Proposal

For smaller features, the proposal can be brief:

```markdown
# Design Proposal: Add `median()` function

**Objective:** Add median calculation to Statistics module.

**Motivation:** Callers currently sort the array and index manually,
which is error-prone for even-length arrays and duplicated across modules.

**Location:** Sources/[Project]/Statistics/CentralTendency.swift

**API:**
```swift
public func median<T: Real>(_ values: [T]) -> T
```

**Compliance:**
- Generic over Real
- Returns T(0) for empty arrays
- No force unwraps

**Source Compatibility:** New function — no existing callers affected.

**Tests:** Golden path, empty array, single element, even count, odd count

**Dependencies:** None

**Alternatives:** Could add to existing `mean()` file, but median has
distinct sorting behavior that warrants its own home.

**Future Directions:** Weighted median, running median over streaming data.

**Open Questions:** None
```

---

## Anti-Patterns

### Wrong: Starting to Code Without Proposal

```
User: "Add caching to the API"
AI: [Immediately writes Cache.swift]
```

### Right: Proposing First

```
User: "Add caching to the API"
AI: "Before implementing, let me propose an approach:
     - Location: Utilities/Cache.swift
     - API: Generic Cache<Key, Value> with TTL support
     - Concurrency: Actor-based for thread safety
     - Dependencies: None

     I'll save this proposal to project/plans/proposals/Caching.md.
     Does this approach align with your expectations?"
```

---

## Related Documents

- [Master Plan](project/master_plan.md) — Project vision and priorities
- [Coding Rules](coding_rules.md) — Implementation constraints
- [Implementation Checklist](../templates/checklist.md) — Development workflow
- [Test-Driven Development](test_driven_development.md) — Testing requirements
