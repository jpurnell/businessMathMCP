# Release Checklist

**Purpose:** Reproducible process for preparing and publishing a new release.
**Applies to:** Every tagged release (patch, minor, major).

---

## Quick Reference

| Stage | Command / Action | Output |
|-------|-----------------|--------|
| **All quality checks** | `quality-gate` | All checks PASSED |
| Dependency audit | `swift package show-dependencies` | Dependency tree |
| Count test cases | `swift test --list-tests \| wc -l` | Integer count |
| JSON output (CI) | `quality-gate --format json` | JSON report |
| GitHub SARIF | `quality-gate --format sarif > results.sarif` | SARIF file |

**Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Complete
- ⚠️ Needs Attention
- 🔴 Blocking — do not release

**Release Type Guidelines:**
- **Patch (x.y.Z):** Phases 1, 4, 5 required
- **Minor (x.Y.0):** All phases required
- **Major (X.0.0):** All phases required; migration guide recommended

---

## Phase 1: Code Quality Gates

### 1.1 Run Quality Gate ✅ required

> **Setup & usage details:** See [Implementation Checklist](../templates/checklist.md#quality-gate-setup) for installation, configuration, and manual fallback commands.

```bash
quality-gate
```

- [ ] All checks show **PASSED**
- [ ] No warnings or errors in any check

> **Note:** At this phase the CHANGELOG's pending section must still be `## [Unreleased]`
> (not yet a dated version). The `release-readiness` check flags a dated `## [X.Y.Z]`
> heading with no matching tag — the version heading is created and tagged together in
> Phase 5.3–5.5, not here.

### 1.2 Verify Test Count

```bash
swift test --list-tests | wc -l
```

- [ ] Note the test count for README update
- [ ] No unexpected skips

### 1.3 Manual Verification

- [ ] All targets build (main library + macros if present)
- [ ] Every public API has a `///` doc comment

> **Rule:** No symbol ships undocumented.

---

### 1.4 Generic Expression Type-Checker Verification ✅ required

```bash
swift build -Xswiftc -Xfrontend -Xswiftc -solver-expression-time-threshold=500 2>&1 | grep -E "error:" | head -20
```

- [ ] Build completes with **zero type-check timeout errors**
- [ ] No `unable to type-check this expression in reasonable time` errors
- [ ] If any fail: break compound generic arithmetic into intermediate `let` bindings (see Section 10 of `coding_rules.md`)

> **Why:** Local Swift 6.3 type-checks expressions ~10× faster than CI (Swift 6.0.3 / Xcode 16.x). The 500ms threshold simulates CI behavior locally. Compound generic arithmetic (4+ operators on `T: Real`) is the #1 cause of CI-only build failures.

---

### 1.5 Concurrency Verification

The `quality-gate` build check includes strict concurrency. Additionally verify:

- [ ] `@Sendable` conformances verified for types crossing isolation boundaries
- [ ] Actor isolation is correct for shared mutable state

---

### 1.6 Dependency Security Audit ✅ required

```bash
swift package show-dependencies --format json
swift package update --dry-run
```

- [ ] All dependencies resolve successfully
- [ ] No dependencies are yanked or deprecated
- [ ] Review dependency versions for known security vulnerabilities
- [ ] If using GitHub, review Dependabot alerts (if enabled)

---

## Phase 2: Platform Verification

### 2.1 macOS Build and Test ✅ required

```bash
swift build
swift test
swift build -c release
```

- [ ] Debug build succeeds
- [ ] Release build succeeds
- [ ] All tests pass

---

### 2.2 Linux Build and Test ✅ required for cross-platform libraries

```bash
# Using Docker (from macOS)
docker run --rm -v "$PWD":/workspace -w /workspace swift:6.0 swift build
docker run --rm -v "$PWD":/workspace -w /workspace swift:6.0 swift test
```

Or verify via CI:
- [ ] GitHub Actions Linux job passes
- [ ] Platform-specific code paths tested (`#if os(Linux)` branches)

---

### 2.3 Additional Platform Archives ⚠️ recommended for Apple platform libraries

```bash
# iOS
xcodebuild archive -scheme [SCHEME] -destination "generic/platform=iOS" SKIP_INSTALL=NO

# tvOS
xcodebuild archive -scheme [SCHEME] -destination "generic/platform=tvOS" SKIP_INSTALL=NO

# watchOS
xcodebuild archive -scheme [SCHEME] -destination "generic/platform=watchOS" SKIP_INSTALL=NO

# visionOS
xcodebuild archive -scheme [SCHEME] -destination "generic/platform=visionOS" SKIP_INSTALL=NO
```

- [ ] iOS archive builds successfully
- [ ] tvOS archive builds successfully
- [ ] watchOS archive builds successfully
- [ ] visionOS archive builds successfully (if supporting)

---

### 2.4 Performance Regression Testing ⚠️ required for major releases

```bash
swift test --filter "Performance"
```

- [ ] Benchmark suite executed (if available)
- [ ] No significant performance regressions (>10% slowdown)
- [ ] Memory usage within acceptable bounds

---

## Phase 3: Documentation Verification

### 3.0 Capability Map Review ✅ required

Review `project/capability_map.md` against shipped changes:

- [ ] New feature areas added for any new capabilities
- [ ] Key types updated for renamed/added/removed types
- [ ] Interfaces updated (new MCP tools, API endpoints, CLI commands)
- [ ] Removed capabilities deleted from the map
- [ ] "Last reviewed" date updated

> **Format reference:** See `development-guidelines/rules/capability_map.md`

### 3.1 DocC Documentation Build ✅ required

```bash
swift package generate-documentation --target [PROJECT_NAME]
```

- [ ] Documentation builds without errors
- [ ] Documentation builds without warnings
- [ ] All public API symbols appear in generated documentation
- [ ] Code examples in documentation compile correctly
- [ ] Navigation structure is correct

---

### 3.2 Example Code Verification ✅ required

- [ ] All Swift Playgrounds open without errors in Xcode
- [ ] Example code compiles
- [ ] README code snippets are accurate and would compile

---

## Phase 4: README Update

### 4.1 Update Metrics

- [ ] Test count updated
- [ ] Documentation coverage updated (if tracked)
- [ ] Version number updated in installation instructions

### 4.2 Manual Review

- [ ] Version headline updated if version changed
- [ ] New feature bullets added for significant features
- [ ] Installation version updated: `from: "X.Y.Z"`
- [ ] Release notes link correct
- [ ] Requirements section accurate

### 4.3 Content Guardrails

These items must **never appear** in README.md:

- [ ] No placeholder text (`TODO`, `TBD`, `FIXME`)
- [ ] No broken relative links
- [ ] No internal references (instruction set paths, session notes)

---

## Phase 5: Git Operations

### 5.1 Final Checks Before Commit

- [ ] `swift test` passes
- [ ] `swift build` is clean with **zero warnings**
- [ ] `docc-lint` reports **zero issues**
- [ ] `git diff` reviewed — only expected changes

---

### 5.2 Package.resolved Verification ✅ required

```bash
swift package resolve
git diff Package.resolved
```

- [ ] `Package.resolved` is up to date
- [ ] No unexpected dependency version changes

---

### 5.3 Changelog Review ✅ required

> 🔴 **Tag-parity invariant:** A dated `## [X.Y.Z]` heading and its `vX.Y.Z` git tag
> must be created together and pushed atomically. The `release-readiness` gate fails
> (`release-untagged-version`) for as long as a version heading exists without a matching
> tag — locally *or* on the remote. Keep the heading as `## [Unreleased]` throughout
> development (the gate skips `Unreleased`); rename it to the dated version **here**, then
> proceed straight through 5.4 → 5.5 without pushing in between.

- [ ] Until now, the pending section was titled `## [Unreleased]`
- [ ] Rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD` for this release
- [ ] All significant changes documented:
  - [ ] Added (new features)
  - [ ] Changed (changes to existing functionality)
  - [ ] Deprecated (features to be removed)
  - [ ] Removed (removed features)
  - [ ] Fixed (bug fixes)
  - [ ] Security (security fixes)

> **Format:** Follow [Keep a Changelog](https://keepachangelog.com/) conventions.

---

### 5.4 Release Commit + Tag ✅ required

Commit the release, then tag it **before pushing anything** — this closes the window
where the version heading is committed but not yet tagged.

```bash
git add .
git commit -m "Release vX.Y.Z: <one-line summary>"
git tag -a vX.Y.Z -m "Version X.Y.Z"   # tag the release commit locally, before any push
```

- [ ] Commit message follows convention: `Release vX.Y.Z: ...`
- [ ] All modified files staged
- [ ] Tag created with correct version number, pointing at the release commit
- [ ] Nothing pushed yet

---

### 5.5 Atomic Push ✅ required

Push the commit and its tag in a single operation so the remote never sees the
CHANGELOG version without the matching tag.

```bash
git push origin main --follow-tags
```

- [ ] `--follow-tags` used (main branch and annotated tag pushed together)
- [ ] `git ls-remote --tags origin vX.Y.Z` confirms the tag reached the remote
- [ ] `quality-gate --check release-readiness` passes on the tagged commit

> **Enforcement:** The `setup.swift`-installed `pre-push` hook runs
> `quality-gate --check release-readiness` and blocks the push if a version heading
> lacks its tag — a backstop for this ordering.

---

## Phase 6: Post-Release Verification

- [ ] CI build passes on tagged commit
- [ ] Documentation builds cleanly
- [ ] README renders correctly on GitHub
- [ ] Package resolves correctly when added to a new project:
  ```swift
  .package(url: "https://github.com/[USER]/[PROJECT]", from: "X.Y.Z")
  ```

---

## Completion Criteria

A release is ready when **all of the following are true**:

### Code Quality
- [ ] `swift build` → zero errors, zero warnings (Swift 6 enforces strict concurrency)
- [ ] `swift test` → all pass, zero failures
- [ ] `docc-lint` → zero issues
- [ ] Documentation coverage = 100%

### Documentation
- [ ] DocC documentation builds without errors
- [ ] Example code verified
- [ ] README updated with correct version and metrics

### Git
- [ ] CHANGELOG.md updated (dated heading created together with its tag)
- [ ] Package.resolved current
- [ ] Release commit created
- [ ] Git tag created before pushing, and pushed atomically (`git push --follow-tags`)
- [ ] No window where a dated CHANGELOG heading exists without its `vX.Y.Z` tag

### Cross-Platform (if applicable)
- [ ] macOS build and tests pass
- [ ] Linux build passes
- [ ] Platform archives build (iOS, tvOS, watchOS, visionOS)

### Major Release Additional Requirements (X.0.0)
- [ ] Performance regression testing completed
- [ ] Migration guide created (if breaking changes exist)

---

## Related Documents

- [Coding Rules](coding_rules.md)
- [DocC Guidelines](docc_guidelines.md)
- [Test-Driven Development](test_driven_development.md)
- [Implementation Checklist](../templates/checklist.md)
