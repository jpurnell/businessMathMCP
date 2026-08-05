# Xcode Playground Format

**Purpose:** Specify the bundle layout and manifest contract that lets an Xcode playground open reliably and import the surrounding SPM package's library targets.

**When this applies:** Swift projects that ship Xcode playgrounds — library projects, financial/scientific/teaching material, books or tutorials with executable code samples. Skip this guide for CLI tools, server-side Swift, and apps that don't expose a playground entry point.

---

## TL;DR

For each playground:

1. Use `version='7.0'` in `contents.xcplayground` with `buildActiveScheme='true'`.
2. Include a `playground.xcworkspace/contents.xcworkspacedata` bundle that points at `self:`.
3. Place the playground anywhere under your SPM package's directory tree.
4. To use it: open `Package.swift` in Xcode **first**, then open the playground.

---

## The Format Contract

### `contents.xcplayground` manifest

Every `.playground` bundle must contain a `contents.xcplayground` file with the v7.0 attributes:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<playground version='7.0' target-platform='macos' swift-version='6' buildActiveScheme='true' executeOnSourceChanges='true' importAppTypes='true'/>
```

| Attribute | Required | What it does |
|---|---|---|
| `version='7.0'` | yes | Modern playground format. The older `version='6.0'` multi-page bundles are fragile in Xcode 16+ and not recommended. |
| `target-platform='macos'` | yes | macOS as the runtime — gives you AppKit and (with `importAppTypes='true'`) SwiftUI live views. Use `'ios'` only when the playground is iOS-specific. |
| `swift-version='6'` | yes | Forces Swift 6 language mode. Match your `Package.swift`'s `swiftLanguageModes`. |
| `buildActiveScheme='true'` | **yes — load-bearing** | Tells the playground to compile against the active scheme of the surrounding workspace. Without this, library imports do not resolve. |
| `executeOnSourceChanges='true'` | recommended | Auto-runs on source edits. Good for live demonstrations. |
| `importAppTypes='true'` | recommended | Lets the playground reach app-level types in the workspace. |

### `playground.xcworkspace/` bundle

Each playground must contain its own workspace bundle:

```
1.X-SectionName.playground/
└── playground.xcworkspace/
    └── contents.xcworkspacedata
```

With contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
```

The `<FileRef location="self:">` tells Xcode the playground is its own workspace root. Combined with `buildActiveScheme='true'`, Xcode resolves the active scheme from the surrounding SPM package and the playground inherits its build context — so `import YourLibrary` works.

Without this bundle, Xcode treats the playground as a free-floating fragment with no host workspace and library imports fail.

---

## Directory Layout

Place playgrounds at the project root in a `Playgrounds/` directory:

```
YourProject/
├── Package.swift
├── Sources/
├── Tests/
├── Playgrounds/
│   ├── README.md                        # Document the open-via-Package.swift workflow here
│   └── Chapter1/                        # Optional sub-grouping (per chapter, per feature)
│       ├── 1.1-Topic.playground/
│       └── 1.2-Topic.playground/
└── …
```

Sub-grouping is optional but useful when you have many playgrounds. Xcode walks up the directory tree to find the nearest `Package.swift`, so depth does not break imports.

---

## Single-page vs Multi-page

**Strongly prefer single-page** playgrounds (one `Contents.swift` directly inside `.playground/`).

- Multi-page playgrounds (`Pages/<name>.xcplaygroundpage/`) are more fragile under v7 — page navigation, source-change tracking, and live views are inconsistent across Xcode releases.
- Single-page playgrounds open, compile, and run faster.
- They are easier to verify in CI.
- Standard tooling — search, diffs, refactoring — works better.

If you need multiple pages of related demonstrations, ship them as **multiple single-page playgrounds** in a shared sub-directory. Cross-reference them in prose, not via `(@previous)` / `(@next)` markdown links — that navigation is the part that breaks first.

---

## Opening Workflow

Imports resolve only when Xcode has the host SPM package's workspace loaded.

### Reliable workflow

1. Open `Package.swift` in Xcode. This creates the SPM-generated workspace at `.swiftpm/xcode/package.xcworkspace` and makes every library target buildable.
2. With that workspace open, open any `.playground` from Finder or drag it into Xcode's navigator.
3. The playground's `buildActiveScheme='true'` resolves against the workspace's active scheme; library imports work.

### Failure mode

Opening a `.playground` **standalone** (no `Package.swift` loaded first) produces *"no such module"* errors. Fix: quit Xcode, reopen `Package.swift`, then reopen the playground.

Document this workflow in your `Playgrounds/README.md` so collaborators don't lose time chasing missing-module errors.

---

## Anti-patterns

- **`version='6.0'`** — Old format. Multi-page bundles using this version don't reliably open in Xcode 16+.
- **Missing `playground.xcworkspace/` bundle** — Playground opens but treats every import as unresolved.
- **`buildActiveScheme='false'`** — Playground uses its own minimal context; library imports fail with no recovery short of editing the manifest.
- **Playgrounds outside the package directory tree** — Xcode can't find the host package; imports fail.
- **Multi-page playgrounds with `(@previous)` / `(@next)` navigation** — Looks elegant in source, but the runtime behavior is brittle. Use multiple single-page playgrounds and a `README.md` index instead.

---

## Migration from v6.0 Multi-page Playgrounds

If your project already ships `version='6.0'` multi-page bundles:

1. For each `Pages/<name>.xcplaygroundpage/Contents.swift`, copy the contents to a new sibling directory named `<chapter>/<name>.playground/Contents.swift`.
2. Add a `contents.xcplayground` with the v7.0 attributes above.
3. Add a `playground.xcworkspace/contents.xcworkspacedata` with the `self:` reference.
4. Delete the old `Pages/` directory and the old top-level multi-page bundle.
5. Replace any `(@previous)` / `(@next)` markdown navigation with prose pointers in `Playgrounds/README.md`.

Typical migration time: about 10 minutes per chapter for a book-style playground tree.

---

## CI Verification (Optional)

Headless verification of playground compilation is possible via `xcodebuild` driving a small test target that imports each playground's content. This is not part of the standard SPM toolchain — it requires:

1. A small `.xcodeproj` (or workspace target) listing the playground sources.
2. A GitHub Actions workflow that runs `xcodebuild build -scheme PlaygroundsCI` on a macOS runner.

Ship this only when playground regressions become a real cost. For most projects, manual verification (open and run) is sufficient at the rate playgrounds change.

---

## Reference Implementation

A working example of this format lives in the **BusinessMath** project at `Playgrounds/BusinessMath.DocC - Chapter Playgrounds/`. Each playground there follows this spec exactly: single-page, v7.0 manifest, `playground.xcworkspace` bundle with `self:` reference. The **SICP-Swift Companion** project's `Playgrounds/Chapter1/` directory follows the same pattern.

---

## Why This Spec Exists

Without it, AI assistants and human collaborators routinely produce playgrounds that *look* right (the right files exist, the right names) but fail at the load-bearing details: missing the workspace bundle, leaving `buildActiveScheme` off, picking the wrong manifest version, or shipping a multi-page bundle whose page navigation falls apart. The result is a playground that opens but cannot import the library it's meant to demonstrate. Codifying the format eliminates that whole class of wasted time.
