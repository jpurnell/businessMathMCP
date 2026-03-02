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
        // SwiftNIO for cross-platform HTTP server
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.65.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio-ssl.git",
            from: "2.26.0"
        )
    ],
    targets: [
        .target(
            name: "BusinessMathMCP",
            dependencies: [
                .product(name: "BusinessMath", package: "BusinessMath"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Numerics", package: "swift-numerics"),
                // SwiftNIO dependencies for HTTP server
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ],
            swiftSettings: [
                // Temporarily disabled for SwiftNIO type inference issues
                // .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "BusinessMathMCPServer",
            dependencies: ["BusinessMathMCP"]
        ),
        .testTarget(
            name: "BusinessMathMCPTests",
            dependencies: ["BusinessMathMCP"]
        )
    ]
)
