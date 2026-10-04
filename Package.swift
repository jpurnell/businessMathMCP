// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-business-math-mcp",
    platforms: [
        .macOS(.v14)  // MCP SDK requirement; Linux supported implicitly
    ],
    products: [
        .library(
            name: "BusinessMathMCP",
            targets: ["BusinessMathMCP"]
        ),
        .executable(
            name: "businessmath-mcp-server",
            targets: ["BusinessMathMCPServer"]
        )
    ],
    dependencies: [
        // Core BusinessMath library
        // Exact, because this is a prerelease. `.upToNextMinor(from: "2.7.0")` was
        // here until 2026-09-19 and could no longer resolve at all: the 2.7.0 tag
        // had been removed upstream, so the pinned revision existed nowhere but
        // this machine's `.build/checkouts`. A clean checkout could not build.
        //
        // A range would also be wrong for an alpha — SwiftPM does not select
        // prereleases for a range anyway, and drifting between alphas silently is
        // not what anybody wants from a dependency that is still moving.
        .package(
            url: "https://github.com/jpurnell/businessMath",
            exact: "3.0.0-alpha.7"
        ),
        // MCP Server framework (transport, auth, OAuth, session management)
        .package(
            url: "https://github.com/jpurnell/SwiftMCPServer.git",
            from: "5.0.0"
        ),
        // MCP SDK (fork 0.11.x — 2025-11-25 spec + Swift 6.4 concurrency fixes)
        .package(
            // The fork, at the URL SwiftMCPServer resolves. SwiftPM derives package identity
            // from the URL's last path component, so "swift-sdk" and "swift-mcp-sdk"
            // are two identities for one repository and both would vend MCP.
            url: "https://github.com/jpurnell/swift-mcp-sdk.git",
            exact: "2026.7.28"
        ),
        // Numerics (shared dependency)
        .package(
            url: "https://github.com/apple/swift-numerics",
            from: "1.0.0"
        ),
        // DocC plugin for documentation generation
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            from: "1.3.0"
        )
    ],
    targets: [
        .target(
            name: "BusinessMathMCP",
            dependencies: [
                .product(name: "BusinessMath", package: "BusinessMath"),
                .product(name: "SwiftMCPServer", package: "SwiftMCPServer"),
                .product(name: "MCP", package: "swift-mcp-sdk"),
                .product(name: "Numerics", package: "swift-numerics"),
            ],
            // Declared, not excluded. `exclude:` silences the unhandled-file warning by
            // removing the catalogue from `sourceFiles`, which is where swift-docc-plugin
            // looks for it — DocC then receives nothing and doc-lint passes vacuously.
            resources: [.copy("BusinessMathMCP.docc")]
        ),
        .executableTarget(
            name: "BusinessMathMCPServer",
            dependencies: [
                "BusinessMathMCP",
                .product(name: "SwiftMCPServer", package: "SwiftMCPServer"),
            ]
        ),
        .testTarget(
            name: "BusinessMathMCPTests",
            dependencies: [
                "BusinessMathMCP",
                .product(name: "SwiftMCPServer", package: "SwiftMCPServer"),
            ]
        )
    ]
)
