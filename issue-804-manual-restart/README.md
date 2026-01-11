# Issue #804: Manual Restart Mode

Demonstration of the manual restart feature for Air.

## Issue

[Air Issue #804](https://github.com/air-verse/air/issues/804) - Support custom keyboard shortcuts for restarting instead of automatic restart on file changes.

## Problem

When developing applications with slow startup times (e.g., connecting to multiple databases, loading large configurations), Air's automatic restart on every file change becomes problematic:

1. Frequent code edits trigger multiple restarts
2. Each restart takes 5+ seconds to reconnect to data sources
3. Developer wastes time waiting for unnecessary restarts

## Solution

This example demonstrates the new `watch_mode = "manual"` configuration:

- **Auto mode** (default): Traditional behavior - restart on file changes
- **Manual mode**: Disable automatic restart, press `r` key to restart manually

## Usage

### Run with Manual Mode

```bash
air
# You'll see: "watching mode: manual (press 'r' to restart)"
# Edit main.go - no automatic restart
# Press 'r' to trigger restart manually
```

### Expected Behavior

**Manual mode (`watch_mode = "manual"`):**

1. Start air - server starts (5 second initialization)
2. Edit `main.go` - no restart happens
3. Press `r` key - triggers rebuild and restart
4. See log: "manual restart triggered" → rebuild → restart

**Auto mode (`watch_mode = "auto"`):**

1. Start air - server starts
2. Edit `main.go` - automatic restart
3. Press `r` key - no effect

## Configuration

See `.air.toml`:

```toml
[build]
  watch_mode = "manual"  # "auto" (default) | "manual"
```

## Files

- `main.go` - Simulates slow startup with 5-second database connection
- `.air.toml` - Air configuration with `watch_mode = "manual"`
- `go.mod` - Go module definition

## Testing

1. **Verify manual mode prevents auto-restart:**
   ```bash
   air
   # Edit main.go (add/remove spaces)
   # Confirm no restart happens
   ```

2. **Verify 'r' key triggers restart:**
   ```bash
   # Press 'r' key
   # Should see "manual restart triggered"
   # Should rebuild and restart
   ```

3. **Verify auto mode works (default behavior):**
   ```toml
   # Change .air.toml to:
   watch_mode = "auto"
   ```
   ```bash
   air
   # Edit main.go
   # Should auto-restart
   ```
