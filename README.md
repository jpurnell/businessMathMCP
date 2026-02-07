# BusinessMathMCP

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
- Swift 5.9+

## Dependencies

- [BusinessMath](https://github.com/jpurnell/BusinessMath) - Core financial calculation library
- [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) - MCP Swift SDK
- [swift-numerics](https://github.com/apple/swift-numerics) - Advanced numerical types

## License

See LICENSE file for details.
