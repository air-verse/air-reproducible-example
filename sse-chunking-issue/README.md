# SSE Chunking Issue Reproduction Example

This example reproduces [Air issue #791](https://github.com/air-verse/air/issues/791) - Air's proxy buffers and repackages HTTP chunks instead of forwarding them immediately for Server-Sent Events (SSE) streams.

## The Issue

When using Air's built-in proxy with long-lived HTTP 1.1 SSE streams:

- **Expected Behavior (Direct Connection):** Events are delivered immediately in small chunks (80 bytes) as they're sent by the server every 3 seconds
- **Actual Behavior (Through Proxy):** Air's proxy accumulates and repackages events into larger chunks:
  - First chunk: 0x200 (512 bytes) - approximately 6-7 events
  - Subsequent chunks: 0x800 (2048 bytes) - approximately 25-26 events
  - This causes significant delays in event delivery to clients

## Prerequisites

- Go 1.21 or higher
- [Air](https://github.com/air-verse/air) installed
- curl (for command-line testing)

## Setup

```bash
cd sse-chunking-issue
go mod download
air
```

The server will start with:
- Application running on port **3002**
- Air proxy running on port **3082**

## Testing Methods

### Method 1: Web Browser (Visual Comparison)

This is the easiest way to see the issue:

1. Open your browser to: http://localhost:3082/
2. Click **"Start"** on both panels (Direct Connection and Through Proxy)
3. Observe the difference:
   - **Left panel (Direct):** Events arrive every ~3 seconds with consistent timing
   - **Right panel (Proxy):** Events arrive in bursts with large delays between bursts

The browser shows:
- Real-time event count
- Timestamps when events are received
- Time delta between events
- Average time between events

You'll clearly see that:
- Direct connection: ~3s average delta
- Proxy connection: Much longer initial delays, then bursts of events arriving together

### Method 2: curl (Command Line)

**Test Direct Connection (Correct Behavior):**

```bash
curl --raw -i http://localhost:3002/sse
```

You should see:
```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
Transfer-Encoding: chunked

50
event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"0"}}


50
event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"1"}}


50
event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"2"}}

... (continues every 3 seconds with 0x50/80-byte chunks)
```

**Test Through Proxy (Demonstrates the Bug):**

```bash
curl --raw -i http://localhost:3082/sse
```

You should see:
```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
Transfer-Encoding: chunked

200
event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"0"}}

event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"1"}}

... (approximately 6-7 events buffered together)

800
event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"7"}}

event: datastar-patch-signals
data: signals {"ssetstsignal":{"iteration":"8"}}

... (approximately 25-26 events buffered together)

... (continues with larger chunks and delays)
```

Notice:
- Chunk sizes are 0x200 (512 bytes) then 0x800 (2048 bytes)
- Events are buffered and delivered in batches instead of individually
- Significant delays between chunk deliveries

### Method 3: Health Check Endpoints

Test that the server is running:

```bash
# Direct connection
curl http://localhost:3002/health
curl http://localhost:3002/ping

# Through proxy
curl http://localhost:3082/health
curl http://localhost:3082/ping
```

## Expected vs Actual Output

### Direct Connection (Port 3002) - Expected Behavior

- **Chunk Size:** 80 bytes (0x50) per event
- **Timing:** Events arrive every 3 seconds
- **Behavior:** Immediate delivery as server flushes each event
- **HTTP Transfer-Encoding:** chunked
- **Content-Type:** text/event-stream

### Through Proxy (Port 3082) - Bug Demonstration

- **Chunk Size:** First 512 bytes (0x200), then 2048 bytes (0x800)
- **Timing:** 
  - First chunk arrives after ~18-21 seconds (6-7 events buffered)
  - Subsequent chunks arrive after ~75-78 seconds (25-26 events buffered)
- **Behavior:** Proxy accumulates events before forwarding them
- **Impact:** Real-time SSE functionality is broken due to buffering delays

## Technical Details

The example server:
- Uses Gin framework for HTTP handling
- Emits Server-Sent Events in the exact format from the GitHub issue
- Each event is padded to exactly 80 bytes (0x50)
- Uses `http.Flusher` to flush after each event write
- Sets proper SSE headers:
  - `Content-Type: text/event-stream`
  - `Cache-Control: no-cache`
  - `Connection: keep-alive`
- Uses `Transfer-Encoding: chunked`

## Files

- `server.go` - Go HTTP server with SSE endpoint
- `.air.toml` - Air configuration with proxy enabled
- `static/index.html` - Interactive browser client for visual comparison
- `go.mod` - Go module dependencies

## What This Demonstrates

This example clearly shows that Air's proxy:
1. Does not forward chunks verbatim as received from the server
2. Buffers and repackages chunks into larger sizes (0x200, then 0x800)
3. Causes unacceptable delays for real-time SSE applications
4. Breaks the real-time nature of Server-Sent Events

The proxy should forward chunks immediately as received from the server and flush the outgoing buffer after each chunk, especially for `Content-Type: text/event-stream`.

## Related Issue

GitHub Issue: [air-verse/air#791 - Proxy should not repackage chunks from the app for HTTP 1.1 Transfer-Encoding: chunked](https://github.com/air-verse/air/issues/791)
