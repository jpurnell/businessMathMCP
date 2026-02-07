// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "BusinessMathMCP",
	platforms: [
		.macOS(.v13)
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
		.package(
			url: "https://github.com/jpurnell/BusinessMath.git",
			branch: "main"
		),
		.package(
			url: "https://github.com/apple/swift-numerics",
			from: "1.1.1"
		),
		.package(
			url: "https://github.com/modelcontextprotocol/swift-sdk.git",
			from: "0.10.0"
		)
	],
	targets: [
		.target(
			name: "BusinessMathMCP",
			dependencies: [
				.product(name: "BusinessMath", package: "BusinessMath"),
				.product(name: "Numerics", package: "swift-numerics"),
				.product(name: "MCP", package: "swift-sdk")
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		),
		.executableTarget(
			name: "BusinessMathMCPServer",
			dependencies: ["BusinessMathMCP"],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		),
		.testTarget(
			name: "BusinessMathMCPTests",
			dependencies: ["BusinessMathMCP"],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		)
	]
)
