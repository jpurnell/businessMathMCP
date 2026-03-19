// swift-tools-version: 6.0
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
            branch: "main"
        ),
        // MCP Server framework (transport, auth, OAuth, session management)
        .package(
            url: "https://github.com/jpurnell/SwiftMCPServer.git",
            branch: "main"
        ),
        // MCP SDK
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.10.0"
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
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Numerics", package: "swift-numerics"),
            ]
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
