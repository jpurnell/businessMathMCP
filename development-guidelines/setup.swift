#!/usr/bin/env swift

// setup.swift — Generate .claude/ bridge layer and .quality-gate.yml for a project
//
// Usage:
//   From your project root, after cloning development-guidelines:
//     swift development-guidelines/setup.swift
//
//   Or with a custom guidelines path:
//     swift setup.swift --guidelines-path .guidelines

import Foundation

// MARK: - Configuration

struct Config {
    let projectRoot: URL
    let guidelinesPath: String
    let projectName: String
}

// MARK: - Helpers

func fileManager() -> FileManager { .default }

func writeFile(at path: String, content: String, relativeTo root: URL) {
    let url = root.appendingPathComponent(path)
    let dir = url.deletingLastPathComponent()
    try! fileManager().createDirectory(at: dir, withIntermediateDirectories: true)
    try! content.write(to: url, atomically: true, encoding: .utf8)
    print("  \u{2713} \(path)")
}

func fileExists(at path: String, relativeTo root: URL) -> Bool {
    fileManager().fileExists(atPath: root.appendingPathComponent(path).path)
}

func readExisting(at path: String, relativeTo root: URL) -> String? {
    try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

// MARK: - Parse Arguments

func parseArgs() -> Config {
    let args = CommandLine.arguments
    let cwd = URL(fileURLWithPath: fileManager().currentDirectoryPath)

    var guidelinesRelPath: String?
    var projectRoot = cwd

    for i in 1..<args.count {
        if args[i] == "--guidelines-path", i + 1 < args.count {
            guidelinesRelPath = args[i + 1]
        }
        if args[i] == "--project-root", i + 1 < args.count {
            projectRoot = URL(fileURLWithPath: args[i + 1])
        }
    }

    if guidelinesRelPath == nil {
        let scriptPath = URL(fileURLWithPath: args[0]).resolvingSymlinksInPath().path
        let cwdPath = projectRoot.path

        if scriptPath.hasPrefix(cwdPath) {
            let relative = String(scriptPath.dropFirst(cwdPath.count + 1))
            if let lastSlash = relative.lastIndex(of: "/") {
                guidelinesRelPath = String(relative[..<lastSlash])
            } else {
                guidelinesRelPath = "."
            }
        }
    }

    let guidelinesPath = guidelinesRelPath ?? "development-guidelines"

    guard fileExists(at: "\(guidelinesPath)/README.md", relativeTo: projectRoot) else {
        print("Error: Cannot find guidelines at '\(guidelinesPath)/README.md'")
        print("Run this script from your project root, e.g.:")
        print("  swift \(guidelinesPath)/setup.swift")
        exit(1)
    }

    let projectName = projectRoot.lastPathComponent

    return Config(
        projectRoot: projectRoot,
        guidelinesPath: guidelinesPath,
        projectName: projectName
    )
}

// MARK: - Generators

func generateCLAUDEmd(_ config: Config) -> String {
    """
    # \(config.projectName) — Development Guidelines

    This project follows the Design-First TDD workflow defined in `\(config.guidelinesPath)/`.

    ## Session Start

    Read documents in this order for full context recovery:
    1. `project/master_plan.md` — Vision and priorities
    2. `\(config.guidelinesPath)/rules/coding_rules.md` — Forbidden patterns, safety rules
    3. `\(config.guidelinesPath)/rules/test_driven_development.md` — Testing contract
    4. `project/checklists/CURRENT_*.md` — Active tasks (if any)
    5. Latest file in `project/summaries/` — Where we left off (if any)

    For quick recovery (same-day, simple bug fixes), read only items 4-5.

    ## Development Workflow

    ```
    0. DESIGN   \u{2192} Propose architecture (design_proposal.md)
    1. RED      \u{2192} Write failing tests first
    2. GREEN    \u{2192} Minimum code to pass
    3. REFACTOR \u{2192} Clean up, keep tests green
    4. DOCUMENT \u{2192} DocC comments and examples
    5. VERIFY   \u{2192} Run quality-gate (zero warnings/errors)
    ```

    ## Key Rules

    - No force unwraps (`!`), no `try!`, no force casts (`as!`)
    - Guard clauses for all validation; early returns over nested ifs
    - Division safety: always check for zero before dividing
    - Swift 6 strict concurrency compliance
    - All public APIs require DocC documentation

    ## Quality Gate

    Run `quality-gate` before every commit. All checks must pass.

    ## References

    - Full guidelines: `\(config.guidelinesPath)/README.md`
    - Coding rules: `\(config.guidelinesPath)/rules/coding_rules.md`
    - TDD contract: `\(config.guidelinesPath)/rules/test_driven_development.md`
    - Session workflow: `\(config.guidelinesPath)/rules/session_workflow.md`
    """
}

func generateSwiftRules(_ config: Config) -> String {
    """
    ---
    paths:
      - "Sources/**/*.swift"
      - "Tests/**/*.swift"
    ---
    # Swift Development Rules

    Follow the coding standards in `\(config.guidelinesPath)/rules/coding_rules.md`.

    ## Mandatory

    - No force unwraps, no `try!`, no force casts
    - Guard clauses for validation, early returns over nesting
    - Division safety: check for zero before dividing
    - Swift 6 strict concurrency compliance
    - All public APIs need DocC comments (see `\(config.guidelinesPath)/rules/docc_guidelines.md`)

    ## Testing (TDD)

    Follow `\(config.guidelinesPath)/rules/test_driven_development.md`:
    - Write failing tests BEFORE implementation
    - Test golden path, edge cases, invalid inputs
    - Use deterministic test data (no random values)
    - Floating point: use accuracy-based assertions, not exact equality
    """
}

func generateDesignSkill(_ config: Config) -> String {
    """
    ---
    name: design
    description: Start a new feature with a Design Proposal (Phase 0). Use when beginning work on a new feature or capability.
    argument-hint: <feature name>
    ---
    Create a Design Proposal for the following feature: $ARGUMENTS

    Follow the template in `\(config.guidelinesPath)/rules/design_proposal.md`.

    Save the proposal to `project/plans/proposals/`.

    Include:
    - Problem statement and motivation
    - Proposed API with Swift signatures
    - Error handling strategy
    - Testing strategy
    - Performance considerations
    """
}

func generateRecoverSkill(_ config: Config) -> String {
    """
    ---
    name: recover
    description: Recover session context after a break. Use at the start of a new session to reload project state, active tasks, and next steps.
    ---
    Perform context recovery following `\(config.guidelinesPath)/rules/session_workflow.md`.

    Read in order:
    1. `project/master_plan.md`
    2. `\(config.guidelinesPath)/rules/coding_rules.md`
    3. `\(config.guidelinesPath)/rules/test_driven_development.md`
    4. Any `project/checklists/CURRENT_*.md` files
    5. The most recent file in `project/summaries/`
    6. Recent git log (`git log --oneline -20`)

    Then report:
    - Current phase and feature being worked on
    - What was completed last session
    - Exact next step to resume work
    - Any blockers or open questions
    """
}

func generateSummarizeSkill(_ config: Config) -> String {
    """
    ---
    name: summarize
    description: Create an end-of-session summary. Use before ending a work session to capture progress and next steps.
    ---
    Create a session summary following the template at `development-guidelines/templates/session_summary.md`.

    Save it to `project/summaries/` with today's date as the filename prefix (YYYY-MM-DD_description.md).

    Include:
    - Work completed this session
    - Current phase and status
    - Quality gate results (run `quality-gate` if not already run)
    - Exact next step for the next session
    - Any blockers or decisions needed

    Also update any active `project/checklists/CURRENT_*.md` to reflect current progress.
    """
}

func generateChecklistSkill(_ config: Config) -> String {
    """
    ---
    name: checklist
    description: Create a new feature implementation checklist tracking all TDD phases. Use when starting implementation of an approved feature.
    argument-hint: <feature name>
    ---
    Create a new implementation checklist for: $ARGUMENTS

    Use the template at `development-guidelines/templates/checklist.md`.

    Save it to `project/checklists/CURRENT_$ARGUMENTS.md` (sanitize the filename).

    The checklist should track all phases:
    - [ ] Phase 0: Design Proposal
    - [ ] Phase 1: Tests (RED)
    - [ ] Phase 2: Implementation (GREEN)
    - [ ] Phase 3: Refactoring
    - [ ] Phase 4: Documentation
    - [ ] Phase 5: Quality Gates
    """
}

func generateSettings() -> String {
    """
    {
      "permissions": {
        "allow": [
          "Bash(swift build:*)",
          "Bash(swift test:*)",
          "Bash(swift package:*)",
          "Bash(quality-gate:*)",
          "Bash(quality-gate)",
          "Bash(git status:*)",
          "Bash(git diff:*)",
          "Bash(git log:*)"
        ],
        "deny": [
          "Bash(rm -rf:*)",
          "Read(.env)",
          "Read(.env.*)"
        ]
      },
      "hooks": {
        "PostToolUse": [
          {
            "matcher": "Edit|Write",
            "hooks": [
              {
                "type": "command",
                "if": "Edit(*.swift)",
                "command": "swift build 2>&1 | tail -5"
              },
              {
                "type": "command",
                "if": "Write(*.swift)",
                "command": "swift build 2>&1 | tail -5"
              }
            ]
          }
        ]
      }
    }
    """
}

func generateQualityGateConfig(_ config: Config) -> String {
    let corpusPath = "\(NSHomeDirectory())/Dropbox/Computer/Development/Swift/Tools/org-judgement-corpus"
    return """
    exclude:
      - disk-clean

    checkers:
      - all
      - logging

    consistency:
      corpusPath: \(corpusPath)
      projectID: \(config.projectName)
      consistencyThreshold: 0.7
      defaultRiskTier: 2

    ijs:
      projectID: "\(config.projectName)"
      corpusPath: "\(corpusPath)"
      decisionOwner: "jpurnell"
      defaultRiskTier: 2
      remoteURL: "git@github.com:jpurnell/org-judgement-corpus.git"
    """
}

// MARK: - Migration helpers

func migrateLegacyCommands(config: Config) {
    let legacyCommands = ["design.md", "recover.md", "summarize.md", "checklist.md"]
    let commandsDir = config.projectRoot.appendingPathComponent(".claude/commands")

    var removed = false
    for file in legacyCommands {
        let url = commandsDir.appendingPathComponent(file)
        if fileManager().fileExists(atPath: url.path) {
            try? fileManager().removeItem(at: url)
            print("  \u{2713} Removed legacy .claude/commands/\(file)")
            removed = true
        }
    }

    if let contents = try? fileManager().contentsOfDirectory(atPath: commandsDir.path),
       contents.isEmpty {
        try? fileManager().removeItem(at: commandsDir)
        print("  \u{2713} Removed empty .claude/commands/")
    }

    if !removed {
        print("  \u{23ED} No legacy commands to migrate")
    }
}

func migrateRootDirectories(config: Config) {
    if config.guidelinesPath == "." {
        print("  \u{23ED} Running inside guidelines repo (no migration needed)")
        return
    }

    let dirsToMigrate = [
        "project/plans",
        "project/checklists",
        "project/summaries",
    ]

    let fm = fileManager()
    var migrated = false

    for dir in dirsToMigrate {
        let rootDir = config.projectRoot.appendingPathComponent(dir)
        let targetDir = config.projectRoot
            .appendingPathComponent(config.guidelinesPath)
            .appendingPathComponent(dir)

        guard fm.fileExists(atPath: rootDir.path) else { continue }

        guard let enumerator = fm.enumerator(
            at: rootDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { continue }

        var movedFiles = 0
        while let sourceURL = enumerator.nextObject() as? URL {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }

            let relativePath = sourceURL.path.dropFirst(rootDir.path.count + 1)
            let destURL = targetDir.appendingPathComponent(String(relativePath))
            let destDir = destURL.deletingLastPathComponent()

            if !fm.fileExists(atPath: destDir.path) {
                try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            }

            if fm.fileExists(atPath: destURL.path) {
                print("  \u{23ED} \(dir)/\(relativePath) already exists in guidelines (skipping)")
            } else {
                do {
                    try fm.moveItem(at: sourceURL, to: destURL)
                    print("  \u{2713} Moved \(dir)/\(relativePath) \u{2192} \(config.guidelinesPath)/\(dir)/")
                    movedFiles += 1
                } catch {
                    print("  \u{2718} Failed to move \(dir)/\(relativePath): \(error.localizedDescription)")
                }
            }
        }

        removeDirectoryIfEmpty(rootDir)

        if movedFiles > 0 { migrated = true }
    }

    if !migrated {
        print("  \u{23ED} No root-level project directories to migrate")
    }
}

func removeDirectoryIfEmpty(_ url: URL) {
    let fm = fileManager()
    guard let contents = try? fm.contentsOfDirectory(
        at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
    ) else { return }

    for item in contents {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
            removeDirectoryIfEmpty(item)
        }
    }

    let gitkeep = url.appendingPathComponent(".gitkeep")
    if fm.fileExists(atPath: gitkeep.path) {
        try? fm.removeItem(at: gitkeep)
    }
    try? fm.removeItem(at: url)
    if !fm.fileExists(atPath: url.path) {
        print("  \u{2713} Removed empty \(url.lastPathComponent)/")
    }
}

// MARK: - Gitignore helpers

func ensureGitignoreEntries(config: Config) {
    let url = config.projectRoot.appendingPathComponent(".gitignore")

    var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

    let entries = [
        "# Claude Code local settings (personal preferences, not shared)",
        ".claude/settings.local.json",
        "CLAUDE.local.md",
    ]

    var added: [String] = []
    for entry in entries {
        if !content.contains(entry) {
            added.append(entry)
        }
    }

    if !added.isEmpty {
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }
        content += "\n" + added.joined(separator: "\n") + "\n"
        try! content.write(to: url, atomically: true, encoding: .utf8)
        print("  \u{2713} .gitignore (added local claude entries)")
    }
}

func ensureProjectDirectories(config: Config) {
    let dirs = [
        "project/plans/proposals",
        "project/plans/UPCOMING",
        "project/plans/COMPLETED",
        "project/checklists",
        "project/checklists/completed",
        "project/checklists/blocked",
        "project/summaries",
        "project/summaries/phases",
        "project/summaries/fixes",
        "project/summaries/archive",
    ]

    for dir in dirs {
        let relative = "\(config.guidelinesPath)/\(dir)"
        let url = config.projectRoot.appendingPathComponent(relative)
        if !fileManager().fileExists(atPath: url.path) {
            try! fileManager().createDirectory(at: url, withIntermediateDirectories: true)
            let gitkeep = url.appendingPathComponent(".gitkeep")
            fileManager().createFile(atPath: gitkeep.path, contents: nil)
        }
    }
    print("  \u{2713} Project directories under \(config.guidelinesPath)/")
}

func copyTemplates(config: Config) {
    _ = config
    print("  \u{23ED} Templates remain in place under \(config.guidelinesPath)/ (no copy needed)")
}

// MARK: - Guidelines repo isolation
//
// The guidelines folder is its own git repo whose `main` tracks the SHARED
// template. Project-specific content (summaries, checklists, master plan)
// must NEVER be committed to that shared `main` — doing so pushes one
// project's state into the template every other project consumes. Two
// safeguards, both automated here so they can't be skipped:
//   1. The outer project gitignores the guidelines folder (nested repo).
//   2. The inner repo is switched to a `project-state/<project>` branch so
//      any commit lands on the project's own branch, never the template main.

@discardableResult
func runGit(_ args: [String], in directory: URL) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + args
    process.currentDirectoryURL = directory
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (-1, "")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
}

/// Derive a kebab-case `project-state/<slug>` branch name from the project name.
func projectStateSlug(_ config: Config) -> String {
    var slug = ""
    var lastDash = false
    for ch in config.projectName.lowercased() {
        if ch.isLetter || ch.isNumber {
            slug.append(ch)
            lastDash = false
        } else if !lastDash {
            slug.append("-")
            lastDash = true
        }
    }
    return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

/// Ensure the OUTER project's .gitignore excludes the nested guidelines folder.
func ensureGuidelinesGitignored(config: Config) {
    guard config.guidelinesPath != "." else { return }  // guidelines IS the repo root
    let url = config.projectRoot.appendingPathComponent(".gitignore")
    var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    let entry = "\(config.guidelinesPath)/"
    let existing = content.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    if existing.contains(entry) || existing.contains(config.guidelinesPath) {
        print("  \u{23ED} .gitignore already excludes \(entry)")
        return
    }
    if !content.isEmpty && !content.hasSuffix("\n") { content += "\n" }
    content += "\n# Development guidelines \u{2014} nested repo, tracked on its own project-state branch\n\(entry)\n"
    try? content.write(to: url, atomically: true, encoding: .utf8)
    print("  \u{2713} .gitignore (excluded \(entry))")
}

/// Switch the inner guidelines repo to `project-state/<project>` (idempotent),
/// and ignore regenerable artifacts so they never get committed anywhere.
func ensureGuidelinesProjectStateBranch(config: Config) {
    let dir = config.projectRoot.appendingPathComponent(config.guidelinesPath)

    let inside = runGit(["rev-parse", "--is-inside-work-tree"], in: dir)
    guard inside.status == 0, inside.output == "true" else {
        print("  \u{23ED} \(config.guidelinesPath)/ is not a git repo (skipping branch isolation)")
        return
    }

    let branch = "project-state/\(projectStateSlug(config))"
    let current = runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: dir).output

    if current == branch {
        print("  \u{23ED} guidelines already on \(branch)")
    } else if current == "main" || current == "master" {
        let exists = runGit(["show-ref", "--verify", "--quiet", "refs/heads/\(branch)"], in: dir).status == 0
        let sw = exists
            ? runGit(["checkout", branch], in: dir)
            : runGit(["checkout", "-b", branch], in: dir)
        if sw.status == 0 {
            print("  \u{2713} guidelines switched to \(branch) (was \(current)) \u{2014} project state stays off the shared template")
        } else {
            print("  \u{26A0} could not switch guidelines to \(branch): \(sw.output)")
        }
    } else {
        print("  \u{23ED} guidelines on \(current) (not main) \u{2014} leaving as-is")
    }

    // Ignore regenerable artifacts inside the guidelines repo.
    let giURL = dir.appendingPathComponent(".gitignore")
    var gi = (try? String(contentsOf: giURL, encoding: .utf8)) ?? ""
    let present = gi.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    var addedAny = false
    for pattern in ["project/library/latestReport.json", "**/latestReport.json", ".DS_Store"] where !present.contains(pattern) {
        if !gi.isEmpty && !gi.hasSuffix("\n") { gi += "\n" }
        gi += pattern + "\n"
        addedAny = true
    }
    if addedAny {
        try? gi.write(to: giURL, atomically: true, encoding: .utf8)
        print("  \u{2713} \(config.guidelinesPath)/.gitignore (ignore regenerable reports)")
    }
}

// MARK: - Git hooks
//
// A tracked `.githooks/pre-push` guards the release tag-parity invariant: it refuses a
// push when CHANGELOG.md documents a version whose `vX.Y.Z` git tag does not exist yet
// (the `release-untagged-version` failure). It reuses the quality-gate release-readiness
// checker so the logic (Unreleased-skipping, tag parity) lives in one place, and it is a
// no-op on branches whose CHANGELOG only has an `## [Unreleased]` section.

func generatePrePushHook() -> String {
    """
    #!/bin/sh
    # pre-push — release tag-parity guard (installed by development-guidelines/setup.swift)
    #
    # Refuses a push when CHANGELOG.md documents a version whose git tag does not exist —
    # the `release-untagged-version` failure. Reuses the quality-gate release-readiness
    # checker, so it inherits Unreleased-skipping and tag parity; it is a no-op unless a
    # dated `## [X.Y.Z]` heading lacks its matching `vX.Y.Z` tag.
    #
    # Bypass (not recommended): git push --no-verify

    if ! command -v quality-gate >/dev/null 2>&1; then
      echo "pre-push: quality-gate not on PATH — skipping release-readiness check." >&2
      exit 0
    fi

    result="$(quality-gate --check release-readiness 2>&1)"
    if [ $? -ne 0 ]; then
      echo "$result" >&2
      echo "" >&2
      echo "pre-push: release-readiness FAILED — a CHANGELOG version has no matching git tag." >&2
      echo "  Fix: tag the release commit before pushing, then push atomically:" >&2
      echo "       git tag -a vX.Y.Z -m \\"Version X.Y.Z\\"" >&2
      echo "       git push origin main --follow-tags" >&2
      echo "  Bypass (not recommended): git push --no-verify" >&2
      exit 1
    fi

    exit 0

    """
}

func installGitHooks(config: Config) {
    let fm = fileManager()

    // Only meaningful inside a git repository.
    guard fm.fileExists(atPath: config.projectRoot.appendingPathComponent(".git").path) else {
        print("  \u{23ED} Not a git repository \u{2014} skipping pre-push hook install")
        return
    }

    let hooksDirRel = ".githooks"
    let hooksDir = config.projectRoot.appendingPathComponent(hooksDirRel)
    let hookURL = hooksDir.appendingPathComponent("pre-push")

    do {
        try fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)
        try generatePrePushHook().write(to: hookURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookURL.path)
        print("  \u{2713} .githooks/pre-push (release tag-parity guard)")
    } catch {
        print("  \u{2717} Failed to write .githooks/pre-push: \(error.localizedDescription)")
        return
    }

    // Point git at the tracked hooks dir — but never clobber a different existing hooksPath.
    let current = runGit(["config", "--local", "--get", "core.hooksPath"], in: config.projectRoot)
    let currentPath = current.status == 0 ? current.output : ""
    if !currentPath.isEmpty, currentPath != hooksDirRel {
        print("  \u{23ED} core.hooksPath already set to '\(currentPath)' \u{2014} leaving it (add pre-push there manually)")
    } else {
        runGit(["config", "--local", "core.hooksPath", hooksDirRel], in: config.projectRoot)
        print("  \u{2713} git config core.hooksPath \(hooksDirRel)")
    }
}

// MARK: - Main

func main() {
    let config = parseArgs()

    print("")
    print("\u{2554}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2557}")
    print("\u{2551}     Development Guidelines \u{2014} Project Setup        \u{2551}")
    print("\u{2560}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2563}")
    print("\u{2551}  Project:    \(config.projectName.padding(toLength: 38, withPad: " ", startingAt: 0)) \u{2551}")
    print("\u{2551}  Guidelines: \(config.guidelinesPath.padding(toLength: 38, withPad: " ", startingAt: 0)) \u{2551}")
    print("\u{255A}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{255D}")
    print("")

    // 1. CLAUDE.md
    print("Creating CLAUDE.md...")
    if fileExists(at: "CLAUDE.md", relativeTo: config.projectRoot) {
        let existing = readExisting(at: "CLAUDE.md", relativeTo: config.projectRoot) ?? ""
        if existing.contains("Development Guidelines") {
            print("  \u{23ED} CLAUDE.md already configured (skipping)")
        } else {
            let combined = generateCLAUDEmd(config) + "\n\n---\n\n" + existing
            writeFile(at: "CLAUDE.md", content: combined, relativeTo: config.projectRoot)
            print("  \u{2191} Prepended guidelines to existing CLAUDE.md")
        }
    } else {
        writeFile(at: "CLAUDE.md", content: generateCLAUDEmd(config), relativeTo: config.projectRoot)
    }

    // 2. .claude/rules/
    print("\nCreating .claude/rules/...")
    writeFile(at: ".claude/rules/swift_development.md",
              content: generateSwiftRules(config),
              relativeTo: config.projectRoot)

    // 3. Migrate legacy .claude/commands/
    print("\nMigrating legacy commands...")
    migrateLegacyCommands(config: config)

    // 4. Migrate root-level project directories
    print("\nMigrating root-level project directories...")
    migrateRootDirectories(config: config)

    // 5. .claude/skills/
    print("\nCreating .claude/skills/...")
    writeFile(at: ".claude/skills/design/SKILL.md",
              content: generateDesignSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/recover/SKILL.md",
              content: generateRecoverSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/summarize/SKILL.md",
              content: generateSummarizeSkill(config),
              relativeTo: config.projectRoot)
    writeFile(at: ".claude/skills/checklist/SKILL.md",
              content: generateChecklistSkill(config),
              relativeTo: config.projectRoot)

    // 6. .claude/settings.json
    print("\nCreating .claude/settings.json...")
    if fileExists(at: ".claude/settings.json", relativeTo: config.projectRoot) {
        print("  \u{23ED} .claude/settings.json already exists (skipping)")
    } else {
        writeFile(at: ".claude/settings.json",
                  content: generateSettings(),
                  relativeTo: config.projectRoot)
    }

    // 7. .quality-gate.yml
    print("\nCreating .quality-gate.yml...")
    if fileExists(at: ".quality-gate.yml", relativeTo: config.projectRoot) {
        print("  \u{23ED} .quality-gate.yml already exists (skipping)")
    } else {
        writeFile(at: ".quality-gate.yml",
                  content: generateQualityGateConfig(config),
                  relativeTo: config.projectRoot)
    }

    // 8. Project scaffolding directories
    print("\nCreating project directories...")
    ensureProjectDirectories(config: config)

    // 9. Copy templates
    print("\nCopying templates...")
    copyTemplates(config: config)

    // 10. Gitignore
    print("\nUpdating .gitignore...")
    ensureGitignoreEntries(config: config)

    // 11. Exclude the nested guidelines folder from the outer project repo
    print("\nExcluding guidelines folder from outer repo...")
    ensureGuidelinesGitignored(config: config)

    // 12. Isolate the guidelines repo onto a project-state branch
    print("\nIsolating guidelines repo onto a project-state branch...")
    ensureGuidelinesProjectStateBranch(config: config)

    // 13. Git hooks (release tag-parity guard)
    print("\nInstalling git hooks...")
    installGitHooks(config: config)

    // Summary
    print("")
    print("\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}")
    print("  Setup complete!")
    print("")
    print("  Generated:")
    print("    CLAUDE.md                            \u{2014} AI session entry point")
    print("    .claude/rules/swift_development.md   \u{2014} Path-scoped Swift rules")
    print("    .claude/skills/{design,recover,...}   \u{2014} Workflow skills")
    print("    .claude/settings.json                \u{2014} Default permissions")
    print("    .githooks/pre-push                   \u{2014} Release tag-parity guard")
    print("    .quality-gate.yml                    \u{2014} IJS telemetry + quality gate config")
    print("")
    print("  Guidelines repo isolated on branch:  project-state/\(projectStateSlug(config))")
    print("  (outer repo gitignores \(config.guidelinesPath)/; project state never")
    print("   reaches the shared template's main branch)")
    print("")
    print("  Next steps:")
    print("    1. Customize CLAUDE.md with project-specific details")
    print("    2. Run: quality-gate --bootstrap      (seed initial telemetry)")
    print("    3. Commit .claude/, .githooks/, CLAUDE.md, and .quality-gate.yml")
    print("")
    print("  Personal overrides go in .claude/settings.local.json")
    print("  and CLAUDE.local.md (both gitignored).")
    print("\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}\u{2550}")
    print("")
}

main()
