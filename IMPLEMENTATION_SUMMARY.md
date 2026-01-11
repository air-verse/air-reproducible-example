# Implementation Summary: Air Issue #804 - Manual Restart Mode

## Overview

Successfully implemented manual restart mode for Air, allowing users to disable automatic restarts on file changes and trigger rebuilds manually via keyboard shortcut.

## Issue Reference

- **GitHub Issue:** [air-verse/air#804](https://github.com/air-verse/air/issues/804)
- **Issue Type:** Enhancement
- **Request:** Support custom keyboard shortcuts for restarting instead of automatic restart on file changes

## Implementation Details

### 1. Configuration System (air/runner/config.go)

**Added WatchMode field:**
```go
type cfgBuild struct {
    // ... existing fields ...
    WatchMode string `toml:"watch_mode" usage:"Watch mode: auto (default) or manual"`
}
```

**Default value:**
- `watch_mode = "auto"` (preserves backward compatibility)

### 2. Engine Modifications (air/runner/engine.go)

**Added manual restart channel:**
```go
type Engine struct {
    // ... existing fields ...
    manualRestartCh chan struct{}  // Manual restart signal channel
}
```

**New method:**
```go
func (e *Engine) TriggerManualRestart() {
    select {
    case e.manualRestartCh <- struct{}{}:
        // Successfully sent restart signal
    default:
        // Channel buffer full, restart already pending
    }
}
```

**Modified start() loop:**
- Added new case for `manualRestartCh`
- In manual mode, file change events are ignored (logged as debug)
- In auto mode, preserves existing behavior

### 3. Main Entry Point (air/main.go)

**Added keyboard listener:**
```go
func startKeyboardListener(r *runner.Engine, cfg *runner.Config) {
    if cfg.Build.WatchMode != "manual" {
        return
    }
    
    go func() {
        reader := bufio.NewReader(os.Stdin)
        for {
            char, _, err := reader.ReadRune()
            if err != nil {
                return
            }
            if char == 'r' || char == 'R' {
                r.TriggerManualRestart()
            }
        }
    }()
}
```

**Startup message:**
- Displays `watching mode: manual (press 'r' to restart)` when in manual mode

### 4. Configuration Example (air/air_example.toml)

```toml
[build]
  # Watch mode: "auto" (default) restarts on file changes, 
  # "manual" only restarts on 'r' key press.
  # Use "manual" mode when your app has slow startup (e.g., database connections).
  watch_mode = "auto"
```

### 5. Tests (air/runner/config_test.go)

Added comprehensive test coverage:
- Default config is "auto"
- Explicit "auto" mode works
- "manual" mode works

## Files Modified

| File | Changes |
|------|---------|
| `air/runner/config.go` | Added `WatchMode` field and default value |
| `air/runner/engine.go` | Added `manualRestartCh`, `TriggerManualRestart()`, modified `start()` |
| `air/main.go` | Added keyboard listener and startup hint |
| `air/air_example.toml` | Added `watch_mode` configuration example |
| `air/runner/config_test.go` | Added `TestWatchModeConfig` |

## New Example Directory

Created `issue-804-manual-restart/` with:
- `main.go` - Simulates slow startup (5 seconds)
- `.air.toml` - Configured with `watch_mode = "manual"`
- `README.md` - Usage instructions and expected behavior
- `go.mod` - Go module definition
- `test_manual_mode.sh` - Test script

## Verification

### Code Quality

✅ `make check` - All linting and formatting checks passed  
✅ `go test ./...` - All tests passed (including new TestWatchModeConfig)

### Build

✅ `make build` - Binary built successfully (`air/air`)

### Functional Behavior

**Auto Mode (default):**
- ✅ File changes trigger automatic restart
- ✅ 'r' key has no effect (not monitored)

**Manual Mode (`watch_mode = "manual"`):**
- ✅ Startup displays: `watching mode: manual (press 'r' to restart)`
- ✅ File changes do NOT trigger restart
- ✅ Pressing 'r' key triggers rebuild with log: `manual restart triggered`

## Usage

### Enable Manual Mode

Add to `.air.toml`:
```toml
[build]
  watch_mode = "manual"
```

### Testing

```bash
cd issue-804-manual-restart
./test_manual_mode.sh

# Or manually:
../air/air

# Then:
# 1. Edit main.go - no restart
# 2. Press 'r' - triggers restart
# 3. Press Ctrl+C - exits
```

## Design Decisions

1. **Mode naming:** Used `watch_mode = "auto" | "manual"` instead of boolean for extensibility
2. **Keyboard shortcut:** Simple 'r' key (no Ctrl modifier) for ease of use in terminal
3. **No auto-mode hotkey:** Kept auto and manual modes separate (no 'r' key in auto mode)
4. **Backward compatibility:** Default `"auto"` preserves existing behavior
5. **User feedback:** Clear startup message in manual mode

## Benefits

- Solves slow startup problem for apps with database connections
- Prevents wasted restarts during rapid code editing
- Gives developers full control over restart timing
- Maintains 100% backward compatibility

## Next Steps (Optional)

Potential future enhancements:
- Add 'q' key for graceful shutdown (currently Ctrl+C only)
- Add 'p' key to toggle pause/resume watching
- Support configurable keyboard shortcuts
- Add CLI flag: `--watch-mode manual`

---

**Implementation Date:** 2026-01-11  
**Air Version:** v1.63.7+  
**Status:** ✅ Complete and tested
