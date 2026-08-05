# Logging & Instrumentation Rules

**Updated:** May 5, 2026
**Purpose:** Ensure consumer-facing applications produce structured, queryable runtime telemetry by default. Code without logging is code you cannot debug.

**Applicability:**
- **Applications** (`projectType: "application"`): All rules enforced
- **Libraries** (`projectType: "library"`): Exempt — libraries should accept a `Logger` parameter but not force instrumentation on consumers
- **Test code**: Exempt

**Dependencies:** None. Uses only `import os` and `ContinuousClock`, which ship with every Apple platform.

---

## The Problem

A user says "this screen takes 6 seconds to load." Without instrumentation, debugging is guesswork: add a print, rerun, add another print, rerun, speculate, suggest Instruments. Forty-five minutes later, still no diagnosis.

**Uninstrumented code:**

```swift
func loadMainScreen() async throws {
    let user = try await fetchUser()
    let preferences = try await fetchPreferences(for: user.id)
    let feed = try await fetchFeed(category: preferences.defaultCategory)
    let enriched = try await enrichFeedItems(feed, with: user.subscriptions)
    let sorted = rankItems(enriched, using: preferences.rankingWeights)
    await updateUI(with: sorted)
}
```

Six steps, no visibility. Which one is slow? You have no idea.

**Instrumented code (12 extra lines):**

```swift
import os

struct MainScreenLoader {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app",
        category: "MainScreen"
    )
    private let api: APIClient

    func load() async throws -> ScreenData {
        let total = ContinuousClock.now
        logger.info("loadMainScreen started")

        var step = ContinuousClock.now
        let user = try await api.fetchUser()
        logger.info("fetchUser: \(step.duration(to: .now), privacy: .public)")

        step = ContinuousClock.now
        let preferences = try await api.fetchPreferences(for: user.id)
        logger.info("fetchPreferences: \(step.duration(to: .now), privacy: .public)")

        step = ContinuousClock.now
        let feed = try await api.fetchFeed(category: preferences.defaultCategory)
        logger.info("fetchFeed: \(step.duration(to: .now), privacy: .public) — \(feed.count, privacy: .public) items")

        step = ContinuousClock.now
        let enriched = try await enrichFeedItems(feed, with: user.subscriptions)
        logger.info("enrichFeedItems: \(step.duration(to: .now), privacy: .public) — \(enriched.count, privacy: .public) items")

        step = ContinuousClock.now
        let sorted = rankItems(enriched, using: preferences.rankingWeights)
        logger.info("rankItems: \(step.duration(to: .now), privacy: .public)")

        step = ContinuousClock.now
        await updateUI(with: sorted)
        logger.info("updateUI: \(step.duration(to: .now), privacy: .public)")

        logger.info("loadMainScreen complete: \(total.duration(to: .now), privacy: .public)")
        return ScreenData(items: sorted, user: user)
    }
}
```

**What you see in Console.app:**

```
[MainScreen] loadMainScreen started
[MainScreen] fetchUser: 0.340s
[MainScreen] fetchPreferences: 0.180s
[MainScreen] fetchFeed: 4.200s              ← here's your problem
[MainScreen] enrichFeedItems: 0.090s (47 items)
[MainScreen] rankItems: 0.003s
[MainScreen] updateUI: 0.012s
[MainScreen] loadMainScreen complete: 4.825s
```

Diagnosis takes 10 seconds: `fetchFeed` is the bottleneck. Investigation shifts immediately to "why is this specific API call slow?" — a tractable question, not a haystack search.

---

## 1. The 2-Await Rule

**When to instrument:** Any function that meets either condition:

1. Contains **2 or more `await` calls**
2. Is the **entry point of a user-visible operation**

User-visible entry points include:
- `onAppear` / `.task` view modifiers
- Button action handlers
- `@main App.init()`
- `applicationDidFinishLaunching`
- Navigation destination handlers
- Pull-to-refresh handlers

**How to instrument:** The step-timing pattern. Three lines per step:

```swift
var step = ContinuousClock.now
let result = try await someOperation()
logger.info("someOperation: \(step.duration(to: .now), privacy: .public)")
```

For the function as a whole, add a total timer:

```swift
let total = ContinuousClock.now
logger.info("functionName started")
// ... steps ...
logger.info("functionName complete: \(total.duration(to: .now), privacy: .public)")
```

Single-await functions that are user-visible entry points get the total timer even without per-step timing.

---

## 2. Catch Block Rule

**Every `catch` block must log the error** before recovering or rethrowing. Silent catch blocks hide failures that compound downstream.

```swift
// ✅ Error logged before rethrowing
} catch {
    logger.error("fetchFeed failed: \(error.localizedDescription, privacy: .public)")
    throw error
}

// ✅ Error logged before recovery
} catch {
    logger.warning("fetchFeed failed, using cached data: \(error.localizedDescription, privacy: .public)")
    return cachedFeed
}

// ❌ Silent recovery — failure is invisible
} catch {
    return cachedFeed
}

// ❌ Silent swallow — error disappears entirely
} catch { }
```

The same applies to `try?` — if the `nil` case represents a failure that someone might need to diagnose, log it:

```swift
// ❌ Silent nil — was this a network error, a decode error, or expected?
let profile = try? await fetchProfile()

// ✅ Nil path is visible
let profile: Profile?
do {
    profile = try await fetchProfile()
} catch {
    logger.warning("fetchProfile failed, proceeding without: \(error.localizedDescription, privacy: .public)")
    profile = nil
}
```

---

## 3. Logger Declaration

One logger per type. Subsystem is the bundle identifier. Category is the type name.

```swift
// ✅ Identifiable in Console.app filters and OSLogStore queries
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.app",
    category: "MainScreenLoader"
)

// ❌ Anonymous — impossible to filter
private let logger = Logger()

// ❌ Shared singleton — everything shows up as one category
static let logger = Logger(subsystem: "com.app", category: "App")
```

For libraries that accept a logger parameter:

```swift
public struct FeedParser {
    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "com.mylib", category: "FeedParser")) {
        self.logger = logger
    }
}
```

---

## 4. Privacy Annotations (MANDATORY)

Every interpolated value in a `Logger` call must have an explicit `privacy:` annotation:

```swift
// ✅ Every interpolation annotated
logger.info("Loaded \(items.count, privacy: .public) for \(userId, privacy: .private)")

// ❌ Missing annotation — defaults to .private but intent is unclear
logger.info("Loaded \(items.count) for \(userId)")
```

| Data Type | Privacy Level | Rationale |
|-----------|--------------|-----------|
| Counts, sizes, status codes | `.public` | Numeric operational data, no PII |
| Hostnames, API paths | `.public` | Needed for debugging, not user-specific |
| Timing/duration | `.public` | Performance data, no PII |
| Error descriptions | `.public` | Needed for debugging |
| State enum values | `.public` | Operational state, not user data |
| User IDs, emails, names | `.private` | Personally identifiable |
| Auth tokens, passwords | `.private` | Security-sensitive |
| File paths (user directories) | `.private` | May contain username |

---

## 5. Log Levels

| Level | Use When | Example |
|-------|----------|---------|
| `.fault` | Programmer error, impossible state | Guard clause failure in a code path that "can't happen" |
| `.error` | Operation failed, user-visible impact | Network timeout, decode failure, save failed |
| `.warning` | Degraded but functional | Fallback path taken, cache miss, retry needed |
| `.notice` | Significant events | State transitions, startup, shutdown, feature flag change |
| `.info` | Routine operations | Step timing, I/O boundaries, successful completion |
| `.debug` | Active investigation detail | Variable values, loop iterations, intermediate state |

Step-timing logs use `.info`. Catch-block logs use `.error` (if rethrowing) or `.warning` (if recovering). Startup context uses `.notice`.

---

## 6. Startup Logging

Every application entry point logs context before any other work:

```swift
@main
struct MyApp: App {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app",
        category: "App"
    )

    init() {
        logger.notice("App launched — v\(Bundle.main.shortVersion, privacy: .public) build \(Bundle.main.buildNumber, privacy: .public)")
        logger.notice("OS: \(ProcessInfo.processInfo.operatingSystemVersionString, privacy: .public)")
    }

    var body: some Scene { ... }
}
```

This is the first thing you check when diagnosing a production issue — "what version was running, on what OS?"

---

## 7. Banned Patterns

| Banned Pattern | Required Alternative | Why |
|---------------|---------------------|-----|
| `print()` / `debugPrint()` | `logger.debug()` | Console output is not queryable or filterable |
| `NSLog()` | `os.Logger` | NSLog has no privacy controls, no level filtering |
| Silent `catch { }` | `logger.error()` or `logger.warning()` in catch | Errors must not be swallowed invisibly |
| `try?` without logging | `do/catch` with logged recovery, or explicit comment | Silent failures must be visible |

---

## 8. Auditor Rules

The LoggingAuditor enforces the mechanical rules via `quality-gate`. Step-level instrumentation (the 2-await rule) is behavioral guidance — it can't be reliably detected by AST analysis.

| Rule ID | Severity | What It Catches |
|---------|----------|-----------------|
| `logging.print-statement` | error | Bare `print()`/`debugPrint()` in application code |
| `logging.silent-try` | warning | `try?` without adjacent logging |
| `logging.no-os-logger-import` | warning | File has print/NSLog but no `import os` |
| `logging.missing-privacy` | warning | Logger call with interpolation but no `privacy:` annotation |
| `logging.bare-logger-init` | info | `Logger()` with no subsystem/category |
| `logging.catch-without-logging` | warning | `catch` block with no logger call and no `throw` |

---

## 9. Reading Logs

### Console.app

Filter by your app's subsystem to see only your logs:

```
subsystem == "com.myapp"
```

Filter by category for a specific screen or component:

```
subsystem == "com.myapp" AND category == "MainScreen"
```

### Terminal (`log stream`)

```bash
log stream --predicate 'subsystem == "com.myapp"' --level info
```

### Programmatic (`OSLogStore`)

```swift
import OSLog

let store = try OSLogStore(scope: .currentProcessIdentifier)
let position = store.position(timeIntervalSinceLatestBoot: -60) // last 60 seconds
let entries = try store.getEntries(at: position)
    .compactMap { $0 as? OSLogEntryLog }
    .filter { $0.subsystem == "com.myapp" }
```

---

## Advanced: Structural Observability Primitives

For teams that want deeper structural enforcement — wrapping network I/O, data pipelines, and state transitions in types that make logging automatic — see your project's structural-observability plan, if it has one. Those primitives (`InstrumentedClient`, `Pipeline`, `@Logged`, `withObservability`, `ResourceScope`) are optional tools that build on top of the patterns in this document.

---

## Related Documents

- [Coding Rules](coding_rules.md) — General coding standards
- An "observable code playbook" — the debugging experience this document is designed to produce — is worth writing per project, in `project/plans/`.
- [Fail-Silent Principle](coding_rules.md#fail-silent-principle-prefer-no-answer-over-wrong-answer) — Why silent errors are dangerous
