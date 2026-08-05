# UI Testing: State-Matrix Coverage & View Model Testing
### SwiftUI • Swift Testing Framework • Zero External Dependencies

---

## Purpose

This document extends the testing contract ([test_driven_development.md](test_driven_development.md)) and application testing patterns ([application_testing_patterns.md](application_testing_patterns.md)) with **UI-specific testing requirements** for SwiftUI views.

It addresses the verification gap where views compile and type-check correctly but fail at runtime due to state propagation bugs, missing conditions, wrong transitions, or broken bindings.

---

## Core Principle

**Test the view model, not the view hierarchy.**

View models contain all state logic, transitions, and computed properties. By exhaustively testing the view model against a documented state matrix, we catch the bugs that matter — wrong state, wrong transition, missing condition — without depending on third-party libraries that track SwiftUI's internal implementation.

The view itself should be a thin, declarative mapping from view model state to UI. Simple enough to verify by inspection.

---

## Testing Layers for UI Code

| Layer | Tool | What it catches | Dependencies |
|-------|------|----------------|-------------|
| **View model unit tests** | Swift Testing | State logic, transitions, computed properties, async operations | None |
| **State-matrix coverage** | Swift Testing | Missing states, untested transitions, impossible state combinations | None |
| **Manual testing** | Human | Animation feel, gesture responsiveness, layout, platform-specific behavior | Simulator |

View model tests and state-matrix coverage are **mandatory**. Manual testing covers what automation cannot — visual layout, animations, and platform behavior.

---

## Required Framework

```swift
import Testing
@testable import MyApp
```

Never use XCTest. View model tests may require `@MainActor` if the view model is `@MainActor`-isolated.

---

## State-Matrix Coverage

### The Rule

Every SwiftUI view must have a **documented state matrix** and corresponding view model tests covering all states before being marked "complete."

### Writing the State Matrix

Enumerate every meaningful state the view can be in. Document it as a table in the test file:

```swift
// MARK: - State Matrix
//
// | State     | Properties                                    | Expected Behavior                              |
// |-----------|-----------------------------------------------|------------------------------------------------|
// | Idle      | state=.idle, error=nil, data=[]               | Can start recording, shows empty placeholder   |
// | Recording | state=.recording, error=nil, startTime!=nil   | Can stop, timer incrementing, data streaming   |
// | Error     | state=.idle, error!=nil                       | Shows error message, can retry                 |
// | Loaded    | state=.idle, error=nil, data=populated        | Can export, can start new recording            |
// | Loading   | isLoading=true                                | All actions disabled                           |
```

### State Matrix Rules

1. **Every `@State`, `@Binding`, `@Published`, `@Observable`, and `@Environment` property that affects rendering must appear in at least one matrix column.**

2. **Minimum states to cover:**

   | State Category | When Required | Description |
   |---------------|--------------|-------------|
   | **Default** | Always | Initial state on first render |
   | **Active/Primary** | If interactive | Primary interactive state |
   | **Loading** | If async | While waiting for data |
   | **Empty** | If data-driven | No data available |
   | **Error** | If fallible | Error condition displayed |
   | **Disabled** | If conditional | Interaction disabled |
   | **Edge** | If bounded | Boundary values (max items, long text, zero) |

3. **State transitions must be tested, not just static states.** If `startRecording()` should transition from `.idle` to `.recording`, test that the method produces the expected state change.

4. **The state matrix must be written BEFORE implementation** (during the Design Proposal phase) and updated if the implementation reveals new states.

### Combinatorial Coverage Strategy

| View complexity | Strategy |
|----------------|----------|
| **≤ 3 state dimensions** | Full cross-product (exhaustive) |
| **> 3 state dimensions** | Refactor the view — this is a complexity signal |
| **Always** | Every enum case and boolean value appears in at least one test |
| **Always** | "Impossible" state combinations verified not to crash |

A view needing more than 3 state dimensions is too complex. Decompose it into smaller views, each testable with full cross-product coverage.

---

## View Model Architecture

### Separation of Concerns

```
┌─────────────────────────────┐
│  View (thin, declarative)   │  SwiftUI body — maps state to UI
│  No logic, no computation   │  Verified by inspection + manual testing
├─────────────────────────────┤
│  View Model (@Observable)   │  All state, transitions, computed properties
│  Fully testable with TDD    │  Verified by state-matrix tests
├─────────────────────────────┤
│  Domain / Service Layer     │  Business logic, networking, persistence
│  Covered by unit/int tests  │  Verified by existing TDD contract
└─────────────────────────────┘
```

### View Model Requirements

- All state-driving properties live in the view model, not in `@State` on the view
- Computed properties derive UI-relevant values (e.g., `canStartRecording`, `buttonTitle`, `isExportEnabled`)
- Actions are methods on the view model (e.g., `startRecording()`, `dismiss()`)
- The view's `body` should contain no conditional logic beyond `if`/`switch` on view model properties

### Exception: Simple Views

Views with no state (pure layout, static content) get a minimal state matrix with one row: default state. The "test" is confirming the view has no state to test:

```swift
// MARK: - State Matrix
//
// | State   | Properties | Expected Behavior          |
// |---------|-----------|----------------------------|
// | Default | (none)    | Renders header and tagline |

@Suite("HeaderView")
struct HeaderViewTests {
    @Test("view has no state-driving properties")
    func stateless() {
        // HeaderView is a pure presentation view with no state.
        // State-matrix coverage satisfied: single default state.
    }
}
```

---

## Patterns

### Basic State Matrix Test

```swift
import Testing
@testable import MyApp

@Suite("RecordingViewModel State Matrix")
struct RecordingViewModelStateMatrixTests {

    // MARK: - State Matrix
    //
    // | State     | Properties                                  | Expected Behavior                     |
    // |-----------|---------------------------------------------|---------------------------------------|
    // | Idle      | state=.idle, error=nil, data=[]             | Can start recording                   |
    // | Recording | state=.recording, startTime!=nil            | Can stop, cannot start                |
    // | Error     | state=.idle, error!=nil                     | Shows error, can retry                |
    // | Loaded    | state=.idle, data=populated                 | Can export, can start new             |

    @Test("initial state is idle with empty data")
    func initialState() {
        let vm = RecordingViewModel()

        #expect(vm.state == .idle)
        #expect(vm.error == nil)
        #expect(vm.data.isEmpty)
        #expect(vm.canStartRecording)
    }

    @Test("start transitions to recording")
    func startTransition() async {
        let vm = RecordingViewModel()

        await vm.startRecording()

        #expect(vm.state == .recording)
        #expect(vm.startTime != nil)
        #expect(!vm.canStartRecording)
        #expect(vm.canStopRecording)
    }

    @Test("error resets to idle with message")
    func errorTransition() async {
        let vm = RecordingViewModel()
        await vm.startRecording()

        vm.handleError(AppError.connectionFailed)

        #expect(vm.state == .idle)
        #expect(vm.errorMessage == "Connection failed")
        #expect(vm.canStartRecording)
    }
}
```

### Parameterized Computed Properties

```swift
@Test("computed properties correct per state",
      arguments: [
        (state: ViewState.idle,      canStart: true,  canStop: false, canExport: false),
        (state: ViewState.recording, canStart: false, canStop: true,  canExport: false),
        (state: ViewState.loaded,    canStart: true,  canStop: false, canExport: true),
      ])
func computedPropertiesPerState(
    state: ViewState,
    canStart: Bool,
    canStop: Bool,
    canExport: Bool
) {
    let vm = RecordingViewModel()
    vm.state = state

    #expect(vm.canStartRecording == canStart)
    #expect(vm.canStopRecording == canStop)
    #expect(vm.canExport == canExport)
}
```

### Defensive: Impossible State Combinations

```swift
@Test("start while already recording is no-op")
func startWhileRecordingIsNoOp() async {
    let vm = RecordingViewModel()
    await vm.startRecording()
    let originalStartTime = vm.startTime

    await vm.startRecording()

    #expect(vm.startTime == originalStartTime)
    #expect(vm.state == .recording)
}

@Test("stop while idle is no-op")
func stopWhileIdleIsNoOp() async {
    let vm = RecordingViewModel()

    await vm.stopRecording()

    #expect(vm.state == .idle)
    #expect(vm.data.isEmpty)
}
```

### Async State Transitions

```swift
@Test("loading state while fetching data")
func loadingStateDuringFetch() async {
    let vm = DataViewModel(service: MockService(delay: .milliseconds(100)))

    let task = Task { await vm.fetchData() }

    // After starting fetch, should be loading
    try? await Task.sleep(for: .milliseconds(10))
    #expect(vm.isLoading)
    #expect(!vm.canRefresh)

    await task.value

    #expect(!vm.isLoading)
    #expect(!vm.data.isEmpty)
    #expect(vm.canRefresh)
}
```

---

## Anti-Patterns

### State Logic in the View

```swift
// Wrong — untestable conditional logic in the view body
var body: some View {
    if items.count > 0 && !isLoading && error == nil {
        ListView(items: items)
    } else if isLoading {
        ProgressView()
    }
}
```

```swift
// Right — view model exposes the state, view maps it
// In ViewModel:
var displayState: DisplayState {
    if isLoading { return .loading }
    if let error { return .error(error) }
    if items.isEmpty { return .empty }
    return .loaded(items)
}

// In View:
var body: some View {
    switch viewModel.displayState {
    case .loading: ProgressView()
    case .error(let e): ErrorView(error: e)
    case .empty: EmptyView()
    case .loaded(let items): ListView(items: items)
    }
}
```

### Testing Only the Happy Path

```swift
// Wrong — only tests default state
@Test func viewModelWorks() {
    let vm = RecordingViewModel()
    #expect(vm.state == .idle) // "It initializes" is not state-matrix coverage
}
```

Every state in the matrix needs tests. Every transition between states needs tests.

### Skipping Impossible States

```swift
// Wrong — assumes bad input can't happen
// If a caller can set state = .recording while error != nil,
// the view model should handle it gracefully
```

Test that impossible combinations are handled (no-op, reset, or error) rather than assuming they can't happen.

### More Than 3 State Dimensions

```swift
// Wrong — too many independent state variables
@Observable class ComplexViewModel {
    var isRecording = false
    var isLoading = false
    var isPaused = false
    var hasError = false
    var isExporting = false  // 5 booleans = 32 combinations
}
```

Decompose into smaller view models with focused responsibilities. The 3-dimension limit is a design constraint, not just a testing convenience.

---

## Definition of Done (UI Features)

A view is not "implemented" until:

1. View model exists with all state as `@Observable` properties
2. State matrix documented in test file
3. View model tests cover all states in the matrix
4. State transitions tested for all user-triggerable actions
5. Computed properties verified per state (parameterized where possible)
6. "Impossible" state combinations tested defensively
7. View body contains only declarative state-to-UI mapping
8. All tests pass in `swift test` (no simulator required)

---

## Integration with Development Workflow

The state matrix fits into the Design-First TDD workflow as part of **Step 0 (Design)**:

```
0. DESIGN   → Propose architecture + write state matrix for each view
1. RED      → Write failing view model tests from state matrix
2. GREEN    → Implement view model to pass tests
3. REFACTOR → Decompose views exceeding 3 state dimensions
4. DOCUMENT → DocC comments on public view model types
5. VERIFY   → Zero warnings gate + all state matrix states covered
```

---

## Future Considerations

If view-to-view-model wiring bugs prove to be a recurring problem in practice — where the view model is correct but the view doesn't reflect it — consider adding a lightweight, owned inspection utility. Analysis of options is preserved in `project/plans/IDEAS/ViewInspectorUITesting.md`. Any inspection tooling should be built and maintained in-house rather than depending on third-party libraries that track SwiftUI's internal implementation.

---

## Related Documents

- [Test-Driven Development](test_driven_development.md) — unit-level TDD contract
- [Application Testing Patterns](application_testing_patterns.md) — integration, E2E, benchmarks
- [Design Proposal](design_proposal.md) — architecture validation before coding
- [Testing Guide](TESTING.md) — test execution, parallelism, CI/CD
