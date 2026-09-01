# Current Checklist: What Is Still Open

**Created:** 2026-09-01
**Status:** ACTIVE — five items, none blocking this package's gate
**Context:** [2026-09-01_QualityGate_ToZero.md](../summaries/2026-09-01_QualityGate_ToZero.md)

> This package is at **0 errors / 0 warnings**, 291 tests green, pinned to
> `BusinessMath 2.7.0` and `SwiftMCPServer 1.1.6`. Everything below is elsewhere, or
> is a decision rather than work.

---

## 1. `businessMathMCP` is public and depends on a private package

**The most important item here, and the one a token quietly hides.**

| repo | visibility |
| :--- | :--- |
| `businessMathMCP` | **public** |
| `SwiftMCPServer` | **private** |
| `BusinessMath` | public |
| `quality-gate-swift` | private |

`README.md` says *"Add this package as a dependency in your `Package.swift`"* with
`from: "1.0.0"`. **Nobody outside the account can.** A clone hits the same
`could not read Username` that CI hit, because `Package.swift` requires
`jpurnell/SwiftMCPServer`.

The CI token (item 2) makes *our* builds resolve. It does not make the package
installable by anyone reading that README, and once CI is green there is no longer
any signal that this is true.

Three ways out, and it is a product decision, not a build fix:

- [ ] **Publish `SwiftMCPServer`.** Cleanest if nothing in it is meant to stay closed.
- [ ] **Vendor what is used.** This package touches a narrow slice — `MCPToolHandler`,
      `MCPTool`, `MCPSchemaProperty`, `MCPToolCallResult`, the transport builder.
- [ ] **Make `businessMathMCP` private** and stop advertising it as consumable.

## 2. Create the `SPM_PRIVATE_DEPS_TOKEN` secret here

- [ ] Fine-grained PAT, **`Contents: read` on `jpurnell/SwiftMCPServer`**, saved as
      `SPM_PRIVATE_DEPS_TOKEN` in this repository's Actions secrets.

The workflow side is **done** — `ci.yml` and `release.yml` configure git from it before
any `swift` command, and fail with a named error if the secret is missing rather than
letting the clone produce its unhelpful one. The name matches the secret that already
exists on `BusinessMath` (created 2026-08-06, wired to nothing).

CI stays red until this exists. That is deliberate: the failure now says what to do.

## 3. `BusinessMath` has two unpushed commits

```
39df7bcd  ci: documentation-only pushes should not run a macOS matrix   (Claude)
c4f8264c  docs: rollforward driver and conditionals in TypedModelAuthoring   (Justin)
```

- [ ] Push both, or push `c4f8264c` and let the CI commit follow.

Held because the CI commit sits on top of in-progress DSL work, and publishing someone
else's commit is not a call to make silently. Both are documentation-only, so under the
new filter they cost no CI minutes.

## 4. `BusinessMath`'s `quality-gate.yml` fails with 0 jobs — cause unknown

Every run, including today's release, ends in **0 seconds with 0 jobs created**. That is
`uses:` resolution failing before any job starts, which no secret can influence.

**The cause recorded in the workflow file is disproven.** Its comment asserts:

> this reference is why the workflow fails at startup in 0s. BusinessMath is public;
> jpurnell/quality-gate-swift is private.

But `businessMathMCP` is *also* public and successfully called the same private reusable
workflow — its 2026-05-09 run created 1 job and ran 12 minutes. Two further hypotheses
were tested and eliminated on 2026-09-01:

- every input `BusinessMath` passes (`checks`, `continue-on-failure`, `corpus-repo`, and
  the `corpus-token` secret) **is** declared by the callee;
- `BusinessMath`'s `default_workflow_permissions` is `write`, so the caller's
  `issues: write` is grantable;
- `quality-gate-swift`'s sharing setting is `access_level: "user"`, so both repos are
  inside the allowed set.

- [ ] Correct or delete the comment — it currently misleads the next reader.
- [ ] Find the real cause. `BusinessMathPro` and `SwiftMCPServer` have the same daily cron
      and have been in `startup_failure` since 2026-06-19; whatever changed that day is
      the likeliest lead.

## 5. `release-readiness` §3.2 — reachability is described but not implemented

`ReleaseTagInvariant.parity`'s boundary message claims *"and this push does not add one"*,
but the implementation only checks local tags and never inspects `pushedRefs`. A tag
created locally and left out of the push passes.

That is the **Reachability** case the same file's doc comment calls *"the exact failure
this checker was written for"* — and there is no implementation of it anywhere.

- [ ] Implement, using the `publishedTags` predicate the `identity` check already computes.
- [ ] Check against the fleet first: it **adds** a blocking failure rather than relaxing one.

Written up in
`quality-gate-swift/project/plans/proposals/ParityBelongsAtThePushBoundary.md` §3.2.
§3.1 shipped in `72ff699`.

---

## Done today, for context

- This package: 111 errors / 1,206 warnings → **0 / 0**, seven behavioural defects fixed
- `BusinessMath 2.7.0` — tagged, released, notes written
- `SwiftMCPServer 1.1.6` — branch merged, tagged, released
- Every 2.x tag on `BusinessMath` now has a GitHub release; no drafts
- `release-readiness` §3.1 — parity moved to the push boundary
- CI path filters on both repos, after a documentation-only release commit cost a
  19-minute macOS run at 10x billing
