# BusinessMathMCP

[![CI](https://github.com/jpurnell/businessMathMCP/actions/workflows/ci.yml/badge.svg)](https://github.com/jpurnell/businessMathMCP/actions/workflows/ci.yml)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Swift 6 Compliant](https://img.shields.io/badge/Swift%206-Compliant-brightgreen.svg)](https://www.swift.org/blog/announcing-swift-6/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Model Context Protocol (MCP) server for BusinessMath financial calculations.

## Overview

This package provides an MCP server that exposes BusinessMath's comprehensive financial analysis capabilities through the Model Context Protocol. It enables AI assistants and other MCP clients to perform sophisticated financial calculations including:

- Time value of money calculations
- Portfolio optimization
- Options pricing and analysis
- Bond valuation
- Statistical analysis
- Monte Carlo simulations
- And many more financial tools

## Installation

Add this package as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/businessMathMCP.git", from: "1.0.0")
]
```

## Usage

### Running the Server

```bash
swift run businessmath-mcp-server
```

### As a Library

```swift
import BusinessMathMCP

// Use BusinessMathMCP tools in your own MCP server
```

## Requirements

- macOS 13.0+
- Swift 5.9+ (Swift 6.0 compliant)

## Dependencies

- [BusinessMath](https://github.com/jpurnell/BusinessMath) - Core financial calculation library
- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) - MCP Swift SDK
- [swift-numerics](https://github.com/apple/swift-numerics) - Advanced numerical types

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for development guidelines and CI/CD information.

## License

See LICENSE file for details.
