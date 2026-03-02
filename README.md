# BusinessMath MCP Server

MCP (Model Context Protocol) server providing access to BusinessMath financial calculations and analytics.

## Overview

This package provides a Model Context Protocol server that exposes BusinessMath's comprehensive financial and statistical analysis capabilities to AI assistants and other MCP-compatible clients.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/businessMathMCP.git", from: "1.0.0")
]
```

## Features

- **40+ Financial Tools**: Time value of money, equity/bond valuation, portfolio analysis, and more
- **Statistical Analysis**: Hypothesis testing, Bayesian tools, advanced statistics
- **Optimization**: Adaptive optimization, parallel processing, integer programming
- **Risk Analytics**: Portfolio risk, scenario analysis, Monte Carlo simulation
- **Forecasting**: Time series analysis, trend forecasting, seasonality tools
- **Derivatives**: Options pricing, real options, credit derivatives

## Requirements

- **Platform**: macOS 14+ (MCP SDK requirement)
- **Swift**: 6.0+
- **Dependencies**: BusinessMath 2.0+

## Quick Start

See [Examples/QuickStart.swift](Examples/QuickStart.swift) for usage examples.

## Documentation

- [MCP Integration Guide](Documentation/MCP-INTEGRATION.md)
- [BusinessMath Core Library](https://github.com/justinpurnell/swift-business-math)
- [Migration Guide](Documentation/MIGRATION.md)

## Architecture

BusinessMathMCP serves as a protocol adapter between the Model Context Protocol and the BusinessMath core library. It provides:

- **Type Marshalling**: Converts between MCP JSON types and BusinessMath native types
- **Tool Registry**: Automatic registration and discovery of available tools
- **Transport Layer**: HTTP and Server-Sent Events (SSE) support
- **Authentication**: API key-based authentication for secure access

## Why Separate from BusinessMath?

The MCP server functionality has been separated into its own repository to:
- Enable cross-platform use of BusinessMath core library (without macOS-only MCP SDK)
- Allow independent versioning of MCP server functionality
- Reduce dependency bloat for users who don't need MCP integration
- Provide cleaner architectural boundaries

## License

MIT License - See LICENSE file

## Support

- [Open an Issue](https://github.com/jpurnell/businessMathMCP/issues)
- [BusinessMath Repository](https://github.com/justinpurnell/swift-business-math)
