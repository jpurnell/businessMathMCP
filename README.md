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

## Quick Start: Claude Code Integration

```bash
# 1. Generate an API key
businessmath-mcp-server --generate-key --name "Claude Code"

# 2. Start the server
businessmath-mcp-server --http 8080

# 3. Add to Claude Code (on client machine)
claude mcp add --transport http businessmath http://<server-ip>:8080 \
  --header "Authorization: Bearer <your-api-key>"
```

See [ClaudeCodeSetupGuide.md](ClaudeCodeSetupGuide.md) for detailed instructions.

## Usage

### Running the Server

```bash
# Stdio transport (default)
swift run businessmath-mcp-server

# HTTP transport with API key authentication
businessmath-mcp-server --http 8080
```

### Key Management

```bash
businessmath-mcp-server --generate-key --name "My Key"
businessmath-mcp-server --list-keys
businessmath-mcp-server --revoke-key <prefix>
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
