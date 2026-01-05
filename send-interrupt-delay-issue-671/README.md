# Send Interrupt Kill Delay Optimization - Issue #671

## The Issue

When `send_interrupt = true` is configured, Air's `killCmd` function always waits the full `kill_delay` duration after sending SIGINT, even if the process exits gracefully within milliseconds.

**Current Behavior:**
1. Air sends SIGINT to process
2. Air **always sleeps** for the full `kill_delay` period (e.g., 2 seconds)
3. Air then sends SIGKILL (even if process already exited)

**Problem:**
- If the app responds to SIGINT and exits in 100ms, Air still waits 2 seconds
- This wastes ~1.9 seconds on every reload cycle
- Over many reloads during development, this adds up significantly

## This Example Demonstrates

- Simple HTTP server that handles SIGINT gracefully
- App shuts down cleanly in ~100ms after receiving SIGINT
- Air configuration: `send_interrupt = true`, `kill_delay = "2s"`
- **Observable waste: ~1.9 seconds per reload**

## How to Run

```bash
cd send-interrupt-delay-issue-671
air
```

The server starts on `http://localhost:9090`.

## Testing the Issue

### Step 1: Initial Start

Watch the Air output. The server should start normally.

### Step 2: Test the Server

In another terminal:
```bash
curl http://localhost:9090/ping
```

You should get: `{"status":"ok","message":"pong"}`

### Step 3: Trigger a Reload

Modify the source file to trigger a rebuild:
```bash
echo "// trigger reload" >> main.go
```

### Step 4: Observe the Delay

**Watch Air's logs carefully:**

1. Air detects file change
2. Air sends SIGINT to the running process
3. **App logs: "Received SIGINT, shutting down gracefully..."**
4. **App logs: "Server stopped cleanly"** ← App exits in ~100ms
5. **Air waits... and waits... for nearly 2 more seconds** ⏱️
6. Only then does Air continue and start the rebuild

**The Problem:** 
Between step 4 and step 6, Air is sleeping for the full `kill_delay` even though the process already exited at step 4.

## Expected Optimization

Air should:
1. Send SIGINT to the process
2. Poll every 50ms to check if the process has exited
3. **If process exits → continue immediately** (saves ~1.9s)
4. If process doesn't exit within `kill_delay` → send SIGKILL as fallback

## Time Impact

For a typical development session with 50 reloads:

- **Current behavior:** 50 × 1.9s waste = **95 seconds wasted**
- **Optimized behavior:** 50 × ~0.1s = **5 seconds total**
- **Time saved: 90 seconds** (1.5 minutes)

For developers who reload frequently (100+ times per day), this optimization can save several minutes daily.

## Technical Details

### Current Implementation

In `air/runner/util_linux.go` and `air/runner/util_unix.go`:

```go
if e.config.Build.SendInterrupt {
    // Send SIGINT
    if err = syscall.Kill(-pid, syscall.SIGINT); err != nil {
        return
    }
    time.Sleep(e.config.killDelay())  // ⚠️ Always sleeps full duration
}
// Then sends SIGKILL regardless
err = syscall.Kill(-pid, syscall.SIGKILL)
```

### Proposed Optimization

```go
if e.config.Build.SendInterrupt {
    if err = syscall.Kill(-pid, syscall.SIGINT); err != nil {
        return
    }
    
    // Poll process state instead of blind sleep
    killDelay := e.config.killDelay()
    checkInterval := 50 * time.Millisecond
    elapsed := time.Duration(0)
    
    for elapsed < killDelay {
        time.Sleep(checkInterval)
        elapsed += checkInterval
        
        // Check if process still exists (signal 0 = check only)
        if err := syscall.Kill(-pid, 0); err != nil {
            if errors.Is(err, syscall.ESRCH) {
                // Process exited - return early!
                _, _ = cmd.Process.Wait()
                return pid, nil
            }
        }
    }
}
// Only send SIGKILL if process didn't exit
err = syscall.Kill(-pid, syscall.SIGKILL)
```

## Configuration

Key settings in `.air.toml`:

```toml
[build]
  send_interrupt = true  # Enable graceful shutdown
  kill_delay = "2s"      # Maximum wait time (set high to observe issue)

[log]
  time = true  # Show timestamps for measuring delays
```

## Files

- `main.go` - HTTP server with graceful SIGINT handling (~100ms shutdown)
- `.air.toml` - Air config with `send_interrupt = true` and `kill_delay = "2s"`
- `go.mod` - Go module definition
- `README.md` - This file

## Related Issue

- GitHub Issue: https://github.com/air-verse/air/issues/671
- Issue Title: "Do not sleep the full kill_delay when using send_interrupt and the current application shuts down by itself"

## Cleanup

```bash
# Stop Air with Ctrl+C
# Restore the file if you added test comments
git checkout main.go
# Or manually remove the added lines
```
