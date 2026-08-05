# businessMathMCP Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

> **Provenance:** Written 2026-08-05 from README, `Package.swift`, and the source tree.

---

## Project Overview

### Mission

An MCP server exposing BusinessMath's financial and statistical library as tools an AI agent
can call.

### Target Users
- AI agents doing financial analysis — valuation, statistics, optimisation, forecasting
- MCP-capable hosts such as Claude Desktop and Claude Code
- Anyone who wants BusinessMath's results without writing Swift

### Key Differentiators
- **A large, coherent tool surface** rather than a handful of calculator endpoints — the
  library's breadth is the product
- **Deterministic, auditable answers.** Every result comes from tested library code, so the
  same inputs give the same output and the derivation is inspectable — the opposite of an
  LLM estimating a discount rate
- Financial correctness is the library's problem, already solved and tested there

---

## Architecture

- **Language:** Swift 6 · **Build:** SwiftPM · **Testing:** Swift Testing

```
Sources/BusinessMathMCP/
├── Tools/                 # one file per tool family
└── BusinessMathMCP.docc/
```

57 source files, 26 test files.

### A note on dependencies

`Package.swift` declares no external package dependencies, which is unusual for an MCP
server — the sibling servers build on `SwiftMCPServer`. **[NEEDS INPUT]** — whether that is
deliberate (a self-contained implementation) or historical. If historical, adopting
`SwiftMCPServer` would remove a duplicate protocol implementation and inherit its
authentication.

---

## Current Status

- [x] Tool surface implemented and tested — 26 test files
- [x] CI configured

### Priorities
**[NEEDS INPUT]**

## Quality Standards

`coding_rules.md`, Swift 6 strict concurrency, zero warnings, DocC on public types.
**Every tool documents its JSON schema** — required fields, units, enum cases. An agent
cannot introspect intent from a Swift signature, and a financial tool whose units are
ambiguous will be called wrongly with confident-looking results.

## Roadmap

**[NEEDS INPUT]**

---

**Last Updated:** 2026-08-05
