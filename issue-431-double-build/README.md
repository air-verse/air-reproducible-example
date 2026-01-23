# Issue #431: Crashes on Windows 10 after second reload

## Bug Description

**English:**  
When using Air on Windows 10, the application crashes with `fatal: morestack on g0` after the second reload. The process appears to run twice, resulting in duplicate "running..." and "Starting the server on :3000..." messages.

**中文：**  
在 Windows 10 上使用 Air 时，第二次热重载后应用程序崩溃，报错 `fatal: morestack on g0`。进程似乎运行了两次，导致 "running..." 和 "Starting the server on :3000..." 消息重复出现。

---

## Root Cause Analysis

### Problem

1. **fsnotify on Windows** may fire multiple events for a single file save
2. **With `delay = 0`**, each event triggers a separate build
3. **Multiple builds** start simultaneously
4. **Multiple server instances** try to bind the same port (`:3000`)
5. **Result:** Port conflict or `fatal: morestack on g0` crash

### Code Reference

The issue is related to the debounce logic in `air/runner/engine.go`:

```go
// Line 401-403
// cannot set buildDelay to 0, because when the write multiple events 
// received in short time it will start Multiple buildRuns
time.Sleep(e.config.buildDelay())
```

When `delay = 0`, this sleep is effectively skipped, allowing multiple builds.

---

## Reproduction Steps

### Prerequisites

1. **Windows 10/11** machine (or VM)
2. **Go 1.21+** installed
3. **Air** installed: `go install github.com/air-verse/air@latest`

### Method 1: Automated Script (Recommended)

```powershell
cd issue-431-double-build
.\trigger-bug.ps1
```

The script will:
- Start Air in the background
- Wait for initial build
- Trigger rapid file saves
- Analyze logs for bug indicators
- Report results

### Method 2: Manual Reproduction

#### Terminal 1 - Start Air

```powershell
cd issue-431-double-build
air
```

Wait for initial build to complete.

#### Terminal 2 - Trigger Bug

```powershell
cd issue-431-double-build

# Save the file rapidly multiple times
"// trigger 1" | Add-Content main.go
Start-Sleep -Milliseconds 50
"// trigger 2" | Add-Content main.go
Start-Sleep -Milliseconds 50
"// trigger 3" | Add-Content main.go
```

#### Observe

Watch Terminal 1 for:
- Multiple "running..." messages
- Multiple "Starting the server on :3000..." messages
- Error: `bind: Only one usage of each socket address`
- Error: `fatal: morestack on g0`

---

## Expected vs Actual Behavior

### Expected Behavior

```
running... (PID: 1234, started at 10:30:45.123)
Starting the server on :3000...
[file changed, rebuilding]
running... (PID: 1235, started at 10:30:50.456)
Starting the server on :3000...
```

Only one server instance running at a time.

### Actual Behavior (Bug)

```
running... (PID: 1234, started at 10:30:45.123)
Starting the server on :3000...
running... (PID: 1235, started at 10:30:45.200)
Starting the server on :3000...
Server error: listen tcp :3000: bind: Only one usage of each socket address...
```

Multiple server instances attempting to start simultaneously.

---

## Workaround

Add a delay to `.air.toml`:

```toml
[build]
  delay = 10   # milliseconds - prevents rapid rebuild triggering
```

This introduces a small delay between file change detection and build start, allowing fsnotify to debounce multiple events.

---

## Configuration Details

### `.air.toml` (triggers bug)

```toml
[build]
  delay = 0              # Bug trigger: no debounce
  stop_on_error = false  # Continue to see full behavior
```

### `.air.toml` (workaround)

```toml
[build]
  delay = 10             # Workaround: 10ms debounce
```

---

## Verification Checklist

Use this checklist to confirm bug reproduction:

- [ ] Air starts and completes initial build
- [ ] File is saved rapidly (multiple times within 100-200ms)
- [ ] Multiple "running..." messages appear
- [ ] Multiple "Starting the server" messages appear
- [ ] Port bind error OR morestack error occurs
- [ ] Setting `delay = 10` resolves the issue

---

## Files in This Directory

| File | Description |
|------|-------------|
| `.air.toml` | Air configuration (delay=0 to trigger bug) |
| `go.mod` | Go module definition |
| `main.go` | Simple HTTP server for testing |
| `trigger-bug.ps1` | Windows PowerShell automation script |
| `trigger-bug.sh` | Linux/macOS comparison script |
| `README.md` | This documentation |

---

## Related Issues

- **Issue #431**: [Crashes on Windows 10 after second reload](https://github.com/air-verse/air/issues/431)
- **Issue #473**: Multiple buildRuns when delay is too low
- **Issue #777**: Windows doesn't kill processes properly

---

## Platform Notes

| Platform | Bug Behavior |
|----------|--------------|
| Windows 10/11 | **Reproducible** - fsnotify fires multiple events |
| Linux | Unlikely - fsnotify debounces better |
| macOS | Unlikely - fsnotify debounces better |

The bug is primarily Windows-specific due to differences in how the underlying filesystem notification APIs handle rapid file changes.

---

## Cleanup

```powershell
# Stop any running processes
Stop-Process -Name "air" -ErrorAction SilentlyContinue
Stop-Process -Name "main" -ErrorAction SilentlyContinue

# Remove temp files
Remove-Item -Recurse -Force tmp/
Remove-Item -Force air.log, air.err

# Restore main.go (if modified)
git checkout main.go
```

---

**Happy Bug Hunting!**
