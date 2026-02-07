# Contributing to BusinessMathMCP

Thank you for your interest in contributing to BusinessMathMCP!

## Development Requirements

- **macOS 13.0+** (MCP SDK requirement)
- **Swift 5.9+** (minimum)
- **Xcode 15.0+**

## Swift Version Compatibility

This project follows a **Swift 5.9 minimum, Swift 6.0 compliant** strategy:

- Minimum supported version: Swift 5.9
- Fully compliant with Swift 6.0 strict concurrency
- Uses `swift-tools-version: 5.9` in Package.swift

## Before You Commit

**REQUIRED checks before every commit:**

```bash
# 1. Swift 6 Compliance Check (MANDATORY)
swift build -Xswiftc -strict-concurrency=complete

# 2. Run all tests
swift test --enable-swift-testing --parallel

# 3. Build release binary
swift build -c release --product businessmath-mcp-server
```

**All builds must pass with ZERO concurrency errors.**

## CI/CD Pipeline

### Continuous Integration (CI)

Runs on every push and pull request:

1. **Swift 6 Compliance**: Verifies strict concurrency compliance
2. **Debug Build**: Tests debug configuration
3. **Release Build**: Tests release configuration
4. **Tests**: Runs full test suite with Swift Testing
5. **Integration**: Verifies compatibility with BusinessMath
6. **Server Verification**: Ensures server executable starts

### Release Workflow

Triggered on version tags (e.g., `v1.0.1`):

1. **Build Release Binary**: Compiles optimized macOS binary
2. **Create Archive**: Packages binary as `.tar.gz`
3. **Generate Checksums**: SHA-256 checksums for verification
4. **Create GitHub Release**: Automatic release with binary
5. **Verify Release**: Downloads and tests the release binary

## Creating a Release

1. **Ensure all tests pass**:
   ```bash
   swift test --enable-swift-testing
   ```

2. **Update version** in relevant documentation

3. **Create and push tag**:
   ```bash
   git tag -a v1.0.1 -m "Release v1.0.1 - Brief description"
   git push origin v1.0.1
   ```

4. **Release workflow runs automatically** and creates GitHub release

## Code Standards

### Swift 6 Compliance

All code MUST be Swift 6 compliant:

- Enable `StrictConcurrency` in Package.swift
- Mark types as `Sendable` where appropriate
- Use actors for mutable state across concurrency boundaries
- No data race conditions allowed

### Example: Sendable Types

```swift
// Good - Value type with Sendable components
public struct FinancialResult: Sendable {
    let value: Double
    let metadata: [String: String]
}

// Good - Actor for mutable state
public actor ResultCache {
    private var cache: [String: FinancialResult] = [:]

    func store(_ result: FinancialResult, for key: String) {
        cache[key] = result
    }
}
```

## Testing

- Use Swift Testing framework (`@Test`)
- Group tests with `@Suite`
- Test all error paths
- Include integration tests with BusinessMath

## Dependencies

- **BusinessMath**: Core financial calculation library (2.0+)
- **MCP Swift SDK**: Model Context Protocol implementation (0.10+)
- **swift-numerics**: Advanced numerical types (1.1+)

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. **Run all pre-commit checks** (see above)
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### PR Requirements

- ✅ All CI checks pass
- ✅ Swift 6 strict concurrency compliance
- ✅ Tests included for new functionality
- ✅ Documentation updated (if applicable)
- ✅ No breaking changes (unless major version)

## Questions or Issues?

- Open an issue: https://github.com/jpurnell/businessMathMCP/issues
- Check BusinessMath docs: https://github.com/jpurnell/BusinessMath

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
