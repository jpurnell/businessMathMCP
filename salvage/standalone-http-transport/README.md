# Salvage — standalone HTTP/SSE transport

Preserved 2026-08-04 from an **unversioned** copy of businessMathMCP that lived at
`~/Dropbox/Computer/Development/Swift/businessMathMCP` (no git repo, last modified
2026-06-30). That directory was removed after this commit.

It contained 51 Swift files in a flat layout, 8 of which exist nowhere else in this
repository:

- `HTTPServerTransport.swift`, `HTTPResponseManager.swift`
- `SSESession.swift`, `SSESessionManager.swift`
- `APIKeyAuthenticator.swift`
- `MCPCompat.swift`, `ToolDefinition.swift`, `ValueExtensions.swift`

Together these implement an HTTP + Server-Sent-Events transport with API-key
authentication — a delivery mechanism the current package does not have.

The remaining 43 files share basenames with files in `Sources/` but **differ in content**;
they are an older divergent line, kept here only for reference. Nothing on this branch is
built or tested.

**This branch exists so the work is recoverable, not because it is ready to merge.**
