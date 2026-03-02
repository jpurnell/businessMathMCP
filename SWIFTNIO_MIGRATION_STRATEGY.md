# SwiftNIO Migration Strategy

## Overview

This document outlines the strategy for migrating the BusinessMath MCP Server from Apple's Network framework to SwiftNIO for cross-platform (macOS + Linux) support.

## Current State Analysis

### Files Using Network Framework

1. **HTTPResponseManager.swift** (264 lines)
   - Uses `NWConnection` for storing pending HTTP connections
   - Tracks JSON-RPC requests and routes responses
   - Sends HTTP responses directly to connections

2. **HTTPServerTransport.swift** (548 lines)
   - Uses `NWListener` for TCP server
   - Uses `NWConnection` for individual client connections
   - Handles GET /mcp/sse, POST /mcp, GET /health endpoints

3. **SSESession.swift** (154 lines)
   - Uses `NWConnection` for streaming SSE events
   - Sends heartbeats and JSON-RPC responses

4. **SSESessionManager.swift** (240 lines)
   - Manages multiple SSESession instances
   - Indirect dependency on Network via SSESession

### Test Files Using Network Framework

1. **HTTPTransportTests.swift** (223 lines)
   - Currently imports Network for testing
   - Tests use URLSession which is platform-agnostic

2. **SSETransportTests.swift** (206 lines)
   - Uses custom URLSessionDelegate
   - Tests are mostly placeholder TODOs

## Migration Strategy

### Phase 1: Foundation (CURRENT)

✅ **Task 1.1**: Update Package.swift
- Add SwiftNIO dependencies
- Add Linux platform support
- Status: **COMPLETED**

✅ **Task 1.2**: Verify dependencies download
- Status: **COMPLETED**

### Phase 2: Create NIO Abstraction Layer

**Task 2.1**: Create HTTPConnection Protocol
- Define protocol that abstracts connection behavior
- Methods: `send(data:)`, `close()`, `remoteAddress`
- This allows us to keep the same interface while swapping implementations

**Task 2.2**: Create NIOHTTPConnection Implementation
- Wrapper around NIO's `Channel`
- Implements HTTPConnection protocol
- Handles ByteBuffer ↔ Data conversion

**Task 2.3**: Create HTTPRequest and HTTPResponse Value Types
- Platform-agnostic request/response models
- Used by both old and new implementations during transition

### Phase 3: Migrate HTTPResponseManager

**Current Dependencies**:
```swift
import Network  // ← Remove
```

**New Dependencies**:
```swift
import NIOCore
import NIOFoundationCompat
```

**Migration Steps**:

**Step 3.1**: Replace NWConnection with HTTPConnection Protocol
```swift
// Before:
private struct PendingRequest {
    let connection: NWConnection
    let receivedAt: Date
    let requestId: JSONRPCId
}

// After:
private struct PendingRequest {
    let connection: HTTPConnection
    let receivedAt: Date
    let requestId: JSONRPCId
}
```

**Step 3.2**: Update registerRequest Method
```swift
// Before:
public func registerRequest(requestId: JSONRPCId, connection: NWConnection)

// After:
public func registerRequest(requestId: JSONRPCId, connection: HTTPConnection)
```

**Step 3.3**: Update sendHTTPResponse Method
- Replace NWConnection.send() with HTTPConnection.send()
- Handle async/await properly with NIO

**Testing**: Run HTTPTransportTests after each step

### Phase 4: Migrate HTTPServerTransport

**Current Architecture**:
```
NWListener → accepts NWConnection → reads HTTP → routes to handlers
```

**New Architecture**:
```
ServerBootstrap → accepts Channel → HTTP pipeline → routes to handlers
```

**Migration Steps**:

**Step 4.1**: Create NIO Channel Pipeline
```swift
// HTTP request decoder → HTTP response encoder → Custom handler
ChannelPipeline:
  - HTTPRequestDecoder()
  - HTTPResponseEncoder()
  - HTTPServerHandler (custom)
```

**Step 4.2**: Implement HTTPServerHandler
- Handles incoming HTTP requests
- Routes based on path and method
- Integrates with SSESessionManager and ResponseManager

**Step 4.3**: Replace NWListener with ServerBootstrap
```swift
// Before:
private var listener: NWListener?

// After:
private var bootstrap: ServerBootstrap?
private var serverChannel: Channel?
```

**Step 4.4**: Migrate Connection Management
- Replace `[NWConnection]` with `[Channel]`
- Update connect() and disconnect() methods

**Step 4.5**: Update Request Handling
- Parse HTTP using NIOHTTP1.HTTPRequestHead
- Extract headers, method, path
- Maintain same routing logic

**Testing**: Run HTTPTransportTests for each endpoint

### Phase 5: Migrate SSESession

**Current**: Wraps NWConnection for SSE streaming

**New**: Wraps NIO Channel for SSE streaming

**Migration Steps**:

**Step 5.1**: Replace NWConnection with Channel
```swift
// Before:
private let connection: NWConnection

// After:
private let channel: Channel
```

**Step 5.2**: Update sendEvent Method
- Use Channel.writeAndFlush instead of connection.send
- Handle ByteBuffer allocation
- Maintain SSE format ("event:", "data:", blank line)

**Step 5.3**: Update Heartbeat Mechanism
- Use EventLoop.scheduleRepeatedTask instead of timer
- More efficient with NIO's event loop

**Testing**: Run SSETransportTests

### Phase 6: Migrate SSESessionManager

**Impact**: Minimal - mostly uses SSESession which we've already migrated

**Migration Steps**:

**Step 6.1**: Update Session Storage
- Sessions now contain NIO Channels
- Update cleanup logic

**Step 6.2**: Update Heartbeat Distribution
- Use NIO's event loop for scheduling
- Broadcast to all channels efficiently

**Testing**: Integration tests with multiple SSE clients

### Phase 7: Update Tests

**Step 7.1**: Remove Network Framework Imports
```swift
// Remove:
import Network

// Add (if needed for mocking):
import NIOCore
import NIOPosix
import NIOHTTP1
```

**Step 7.2**: Update Test Utilities
- URLSession-based tests should work as-is
- Update any Network-specific test helpers

**Step 7.3**: Run Full Test Suite
```bash
swift test --filter HTTPTransportTests
swift test --filter SSETransportTests
swift test --filter APIAuthTests
```

### Phase 8: Platform Testing

**Step 8.1**: Test on macOS
```bash
swift build -c release
swift test
.build/release/BusinessMathMCPServer --http 8080
```

**Step 8.2**: Test on Ubuntu 25.10
```bash
swift build -c release
swift test
.build/release/BusinessMathMCPServer --http 8080
```

**Step 8.3**: Verify All Features
- [ ] Health endpoint (/health)
- [ ] Server info endpoint (/mcp)
- [ ] SSE connection (GET /mcp/sse)
- [ ] JSON-RPC requests (POST /mcp)
- [ ] API key authentication
- [ ] CORS headers
- [ ] Request timeout handling
- [ ] SSE heartbeats
- [ ] Session cleanup

### Phase 9: Documentation Updates

**Step 9.1**: Update HTTP_MODE_README.md
- Add "Cross-Platform Support" section
- Update architecture diagram (Network → SwiftNIO)
- Add Linux-specific notes

**Step 9.2**: Update PRODUCTION_DEPLOYMENT.md
- Add SwiftNIO performance characteristics
- Update scaling recommendations

**Step 9.3**: Update UNIX_DEPLOYMENT_GUIDE.md
- Remove "HTTP mode macOS-only" limitation
- Add SwiftNIO dependencies to installation
- Update troubleshooting section

**Step 9.4**: Add DocC Documentation
- Document new HTTPConnection protocol
- Add SwiftNIO migration guide
- Update code examples

### Phase 10: Cleanup

**Step 10.1**: Remove Network Framework
- Delete all `import Network` statements
- Verify no Network framework references remain

**Step 10.2**: Final Verification
```bash
# Should build on both platforms without Network framework
swift build -c release
swift test
```

## Key Design Decisions

### 1. Use Protocol Abstraction for Connections

**Rationale**: Allows incremental migration and easier testing

**Implementation**:
```swift
protocol HTTPConnection: Sendable {
    func send(_ data: Data) async throws
    func close() async
    var remoteAddress: String { get }
}
```

### 2. Keep Actor-Based Concurrency

**Rationale**: Swift actors work great with NIO's EventLoop model

**Implementation**: Maintain existing actor isolation, use NIO event loops internally

### 3. Preserve Existing API Surface

**Rationale**: Minimize changes to main.swift and tests

**Implementation**: Keep HTTPServerTransport interface identical

### 4. Use NIOHTTP1 for HTTP Parsing

**Rationale**: Mature, well-tested HTTP/1.1 implementation

**Implementation**:
```swift
import NIOHTTP1

let decoder = HTTPRequestDecoder()
let encoder = HTTPResponseEncoder()
```

### 5. Maintain SSE Format Compatibility

**Rationale**: Clients shouldn't notice any difference

**Implementation**: Same SSE event format, just different underlying transport

## Benefits of SwiftNIO Migration

1. **Cross-Platform**: Works on macOS, Linux, and Windows
2. **Single Codebase**: No conditional compilation for networking
3. **Production-Ready**: SwiftNIO powers Vapor, smoke-framework
4. **Better Performance**: Optimized for server workloads
5. **Active Development**: Well-maintained by Apple
6. **Excellent Ecosystem**: Middleware, WebSocket support, HTTP/2 future-proofing

## Risks and Mitigations

### Risk 1: Breaking Changes During Migration

**Mitigation**:
- Incremental migration (function by function)
- Keep tests passing at each step
- Use protocol abstraction for gradual transition

### Risk 2: Performance Regression

**Mitigation**:
- Benchmark before and after
- Use NIO best practices (event loops, ByteBuffer pooling)
- Profile with Instruments

### Risk 3: Test Failures

**Mitigation**:
- Update tests incrementally
- Add integration tests
- Test on both platforms

## Success Criteria

- [ ] All HTTPTransportTests pass on macOS
- [ ] All SSETransportTests pass on macOS
- [ ] All tests pass on Ubuntu 25.10
- [ ] HTTP server starts on both platforms
- [ ] SSE connections work on both platforms
- [ ] API authentication works
- [ ] Zero Network framework references
- [ ] Documentation updated
- [ ] Performance benchmarks comparable or better

## Timeline Estimate

- **Phase 1-2**: 2 hours (Setup + Abstraction)
- **Phase 3**: 3 hours (HTTPResponseManager migration)
- **Phase 4**: 6 hours (HTTPServerTransport migration - most complex)
- **Phase 5**: 2 hours (SSESession migration)
- **Phase 6**: 1 hour (SSESessionManager migration)
- **Phase 7**: 2 hours (Test updates)
- **Phase 8**: 2 hours (Platform testing)
- **Phase 9**: 2 hours (Documentation)
- **Phase 10**: 1 hour (Cleanup)

**Total Estimate**: ~20-25 hours of focused development

## Next Steps

1. Review this migration strategy
2. Proceed with Phase 2 (Abstraction Layer)
3. Migrate components incrementally
4. Test continuously
5. Update documentation
6. Deploy to Linux server

---

**Status**: Phase 1 Complete ✅
**Next**: Phase 2 - Create NIO Abstraction Layer
**Last Updated**: 2026-03-02
