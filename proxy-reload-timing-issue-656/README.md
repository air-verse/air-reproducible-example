# Proxy Reload Timing Issue Reproduction

This example reproduces [Air issue #656](https://github.com/air-verse/air/issues/656) - "Proxy handler: unable to reach app" on hot-reload.

## The Problem

When Air's proxy is enabled and a file change triggers a rebuild:

1. **Air rebuilds and starts the new process** (~instant)
2. **Air immediately sends browser reload event** (via SSE)
3. **Browser immediately reloads** (triggered by injected JavaScript)
4. **Browser requests page through proxy** (~50-100ms after reload event)
5. **Proxy tries to reach app** (retries 10 times × 100ms = 1000ms max)
6. **Application is still starting up** (takes 2+ seconds in this example)
7. **Proxy gives up** → Browser shows **"Proxy handler: unable to reach app"** error

The core issue: **Air triggers browser reload at line `runner/engine.go:669` immediately when the process starts, but the application may not be ready to accept connections yet.**

## Why This Happens

### The Timing Problem

| Event | Time from Process Start | Air's Assumption | Reality |
|-------|------------------------|------------------|---------|
| Process starts | 0ms | - | - |
| Air sends reload event | **~0ms** | App is ready | ❌ App is initializing |
| Browser receives event | ~10-50ms | - | - |
| Browser requests page | ~50-100ms | App will respond | ❌ App still initializing |
| Proxy retries begin | ~50-100ms | App will respond soon | ❌ App still initializing |
| Proxy timeout | **1000ms** | App must be ready by now | ❌ App still initializing |
| **Proxy gives up** | **1000ms** | - | **Error shown to user** |
| App actually ready | **2000ms+** | - | ✓ App is ready now |

### Code Analysis

**Problem location in Air source:**
```go
// runner/engine.go:669
if e.config.Proxy.Enabled {
    e.proxy.Reload()  // ← Sends reload IMMEDIATELY when process starts
}
```

**Proxy retry logic:**
```go
// runner/proxy.go:119-125
for i := 0; i < 10; i++ {
    if err == nil {
        break
    }
    time.Sleep(100 * time.Millisecond)  // Only 10 × 100ms = 1 second total
    resp, err = p.client.Do(req)
}
```

**Browser reload trigger:**
```javascript
// runner/proxy.js:4-6
eventSource.addEventListener('reload', () => {
    location.reload();  // ← Reloads IMMEDIATELY when event received
});
```

## Quick Start

### Prerequisites

- Go 1.21+
- [Air](https://github.com/air-verse/air) installed: `go install github.com/air-verse/air@latest`

### Steps to Reproduce

1. **Start Air from this directory:**
   ```bash
   cd proxy-reload-timing-issue-656
   air
   ```

2. **Open browser to proxy URL:**
   ```
   http://localhost:8081
   ```
   
3. **Trigger a hot reload:**
   - Edit `main.go` (add a comment, change a string, anything)
   - Save the file
   
4. **Observe the issue:**
   - Watch the terminal logs showing timing
   - Browser will display: **"Proxy handler: unable to reach app"**
   - The page shows the error because browser reloaded ~2000ms before server was ready
   - Manual refresh is required after server finishes starting

## Expected vs Actual Behavior

### Expected Behavior

- Browser should reload **after** the application is ready to accept connections
- OR proxy should wait longer than 1 second for app to be ready
- OR Air should detect when app is ready before triggering reload

### Actual Behavior

- Browser reloads immediately when Air starts the process
- Proxy only waits 1 second (10 × 100ms retries)
- Application takes 2+ seconds to start (simulating DB connections, config loading, etc.)
- Result: Browser shows error and stops trying
- User must manually refresh after app is ready

## Detailed Timing Analysis

The instrumented server logs show exactly what's happening:

```
[12:30:43.100] ========================================
[12:30:43.100] Process started (PID: 12345)
[12:30:43.100] ========================================
[12:30:43.101] Starting initialization (delay: 2s)...
[12:30:43.101] (This simulates slow app startup - database connections, config loading, etc.)
[12:30:45.102] Initialization complete!
[12:30:45.102] Starting HTTP server on :8080...
[12:30:45.115] ========================================
[12:30:45.115] ✓ Server ready to accept connections!
[12:30:45.115] ✓ Listening on http://localhost:8080
[12:30:45.115] ✓ Time from process start to ready: 2.015s
[12:30:45.115] ========================================
[12:30:45.115] 
[12:30:45.115] IMPORTANT: Air's proxy triggers browser reload IMMEDIATELY when process starts
[12:30:45.115] This means the browser tried to reload 2015ms BEFORE the server was ready!
[12:30:45.115] Air's proxy only retries for 1000ms (10 x 100ms)
[12:30:45.115] ⚠️  RESULT: Browser will show 'proxy handler: unable to reach app' error
[12:30:45.115] 
[12:30:45.115] Access the app through Air's proxy at: http://localhost:8081
```

**The key numbers:**
- **Process start to server ready:** 2015ms
- **Air proxy reload triggered at:** ~0ms (immediately)
- **Browser reload occurs at:** ~50ms (network delay)
- **Proxy timeout after:** 1000ms (10 retries)
- **Server actually ready at:** 2015ms

**Gap:** Server became ready **1015ms AFTER** proxy gave up.

## Adjusting Timing

You can adjust the startup delay to test different scenarios:

### Fast startup (no issue)
```bash
STARTUP_DELAY=0s air
```
Result: ✓ Works fine, app starts before proxy timeout

### Borderline case (race condition)
```bash
STARTUP_DELAY=0.9s air
```
Result: ⚠️ Sometimes works, sometimes fails

### Default case (reproduces issue)
```bash
STARTUP_DELAY=2s air
# or just: air
```
Result: ❌ Consistently shows error

### Extreme case (clearly demonstrates issue)
```bash
STARTUP_DELAY=5s air
```
Result: ❌ Very obvious - app takes 5 seconds, proxy gives up after 1 second

## Interactive Features

The web page includes:

- **Reload counter:** Shows how many times the page has loaded
- **Server health check:** Auto-pings `/health` endpoint
- **Event timeline:** Visual log of what's happening
- **Timing analysis:** Shows exact startup time vs proxy timeout
- **Manual reload button:** For testing after server is ready

## Ports

- **Application port:** 8080 (direct access, bypasses proxy)
- **Proxy port:** 8081 (access through Air's proxy - use this for testing)

You can access the app directly at `http://localhost:8080` to verify it works fine outside of Air's proxy.

## System Requirements

- **Go version:** 1.21+
- **Air version:** v1.40.0+ (issue exists in all current versions)
- **OS:** Any (Linux, macOS, Windows)

## Files in This Reproduction

- **`main.go`** - Instrumented web server with configurable startup delay
- **`static/index.html`** - Interactive test page with timing analysis
- **`.air.toml`** - Air configuration with proxy enabled
- **`go.mod`** - Go module (no external dependencies)
- **`README.md`** - This file

## Related Code in Air

This issue involves interaction between several Air components:

1. **Engine** (`runner/engine.go:669`) - Triggers reload immediately
2. **Proxy** (`runner/proxy.go:119-125`) - Only waits 1 second
3. **Proxy Stream** (`runner/proxy_stream.go:70-77`) - Sends reload event
4. **Injected JavaScript** (`runner/proxy.js:4-6`) - Browser reload trigger

## Potential Solutions

Possible fixes for this issue:

1. **Wait for app health check** - Ping app endpoint before sending reload
2. **Increase proxy timeout** - Make retry timeout configurable
3. **Exponential backoff** - Longer delays between retries
4. **Reload after successful request** - Only reload after proxy successfully reaches app
5. **User-configurable delay** - Add `reload_delay` option in `.air.toml`

## Related Issues

- [air-verse/air#656](https://github.com/air-verse/air/issues/656) - Original issue report
- [air-verse/air#732](https://github.com/air-verse/air/issues/732) - Similar proxy timeout issue

## Contributing

If you have insights or fixes for this issue, please contribute to the upstream Air repository!
