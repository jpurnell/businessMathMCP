# Current Checklist: Dependency Version Pinning

**Created:** 2026-09-01
**Status:** BLOCKED — needs a release decision on two other repositories
**Context:** [2026-09-01_QualityGate_ToZero.md](../summaries/2026-09-01_QualityGate_ToZero.md)

---

## Why this exists

The quality gate is at **0 errors / 2 warnings**. Both remaining warnings are the same
thing, and neither can be fixed inside this repository:

```
Package.resolved :: 'businessmath'   is pinned to branch 'main' instead of a version tag
Package.resolved :: 'swiftmcpserver' is pinned to branch 'main' instead of a version tag
```

`Package.swift` declares both with `branch: "main"`. Switching to `.upToNextMinor(from:)`
against the *existing* tags would regress the build: the resolved `BusinessMath` revision
`44d37741` is 33 commits past `v2.6.0` and carries `Sendable` conformances on nine
distributions that this package depends on. New tags have to be cut first.

## State as of 2026-09-01

| Package | Resolved at | Last tag | Ahead | Ready? |
|---|---|---|---|---|
| `BusinessMath` | `44d37741` (main) | `v2.6.0` | 33 commits | yes — clean, pushed |
| `SwiftMCPServer` | `2b7da475` (main) | `1.1.5` | 3 commits | no — working tree on `docs/reloadable-file-resources`, `MCPCompat.swift` modified |

## Steps

- [ ] Decide the `BusinessMath` version number. 33 commits including new `Sendable`
      conformances — additive, so `v2.7.0` rather than `v2.6.1`, unless the 33 contain a
      break worth a major.
- [ ] Reconcile `BusinessMath`'s own CHANGELOG for that version before tagging.
- [ ] Tag and push `BusinessMath`.
- [ ] Settle `SwiftMCPServer`'s `docs/reloadable-file-resources` branch — land or shelve
      it — then tag and push `1.1.6`.
- [ ] Change both declarations in this `Package.swift` from `branch: "main"` to
      `.upToNextMinor(from: "…")`.
- [ ] `swift package update`, `swift build`, `swift test` (291 expected).
- [ ] Re-run the gate; expect **0 / 0**.

## Do not

Do not silence these with an override, a `.quality-gate.yml` exclusion, or a justification
comment. A branch pin is a real reproducibility gap — a fresh clone of this repo today and
in a month resolve to different code — and the warning is correctly reporting it.
