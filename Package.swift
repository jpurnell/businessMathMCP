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
        .package(
            url: "https://github.com/jpurnell/businessMath",
            .upToNextMinor(from: "2.7.0")
        ),
        // MCP Server framework (transport, auth, OAuth, session management)
        .package(
            url: "https://github.com/jpurnell/SwiftMCPServer.git",
            from: "4.3.0"
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
