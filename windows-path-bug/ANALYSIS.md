# Issue #589 Analysis - Windows Path Bug

## Issue Link
https://github.com/air-verse/air/issues/589

## Classification
**BUG** - Platform-specific path handling inconsistency

## Summary

On Windows, Air fails to execute binaries when the path is provided via CLI flags with forward slashes (e.g., `--build.bin "bin/app.exe"`). However, the exact same path works perfectly when specified in `.air.toml` configuration file.

## Impact

- **Severity:** Medium
- **Platform:** Windows only
- **Workaround:** Use backslashes (`\`) in CLI flags on Windows
- **Breaking:** No - fix would only improve compatibility
- **Affected Use Case:** Users who need dynamic binary names or cross-platform CI/CD scripts

## Root Cause

### Location
`air/runner/util_windows.go:43-52` in the `startCmd()` function

### The Problem

```go
func (e *Engine) startCmd(cmd string) (*exec.Cmd, io.ReadCloser, io.ReadCloser, error) {
    // ...
    c := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", cmd)
    // ...
}
```

When Air runs a binary on Windows, it passes the entire command string to PowerShell's `-Command` parameter. PowerShell interprets paths with forward slashes differently:

**Input:** `bin/windows-path-bug.exe`

**PowerShell interprets as:**
- Token 1: `bin` (command to execute)
- Token 2: `/windows-path-bug.exe` (argument to `bin` command)

**Instead of:** A single path `bin/windows-path-bug.exe`

### Why Config File Works

In `air/runner/config.go:444`, paths from config files go through `filepath.Abs()`:

```go
c.Build.Bin, err = filepath.Abs(c.Build.Bin)
```

This converts `bin/windows-path-bug.exe` to an absolute path like `C:\project\bin\windows-path-bug.exe` with proper Windows backslashes.

### Why CLI Fails

CLI flag values also go through `preprocess()` and should hit the same `filepath.Abs()` call. However, by the time the path reaches `startCmd()` in `engine.go:733`, it's formatted by `formatPath()` and `runnerBin()`.

The issue is that while `filepath.Abs()` is called, the path construction in `runBin()` uses `formatPath(e.config.runnerBin())` which may return the path with forward slashes if they were preserved somewhere in the chain.

## Proposed Fix

### Option 1: Normalize in `startCmd()` (Safest)

In `air/runner/util_windows.go`, normalize the path before passing to PowerShell:

```go
func (e *Engine) startCmd(cmd string) (*exec.Cmd, io.ReadCloser, io.ReadCloser, error) {
    var err error

    if !strings.Contains(cmd, ".exe") {
        e.runnerLog("CMD will not recognize non .exe file for execution, path: %s", cmd)
    }

    // Normalize paths on Windows - convert forward slashes to backslashes
    // This handles cases where CLI flags preserve forward slashes
    cmd = filepath.FromSlash(cmd)

    c := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", cmd)
    // ...
}
```

**Pros:**
- Minimal change
- Catches all path issues at execution point
- Works for both `build.bin` and `full_bin`

**Cons:**
- Treats the symptom rather than root cause
- May convert slashes in non-path parts of the command

### Option 2: Normalize in `runBin()` (More targeted)

In `air/runner/engine.go:733`, ensure the binary path is properly normalized:

```go
formattedBin := formatPath(filepath.FromSlash(e.config.runnerBin()))
command := strings.Join(append([]string{formattedBin}, e.runArgs...), " ")
```

**Pros:**
- More targeted fix
- Only affects the binary path, not the entire command

**Cons:**
- May need similar fixes in other places that construct commands

### Option 3: Ensure `filepath.Abs()` is always called (Root cause)

Investigate why `filepath.Abs()` in `config.go:444` isn't catching CLI flag paths and ensure it's always called for `build.bin` regardless of source.

**Pros:**
- Fixes the root cause
- Consistent behavior between CLI and config file

**Cons:**
- Requires deeper investigation of the config initialization flow
- May have unintended side effects

## Recommendation

**Implement Option 1 first** as a quick fix, then investigate Option 3 for a more robust solution.

## Test Cases

All test cases are included in this reproduction directory:

1. ✅ Config file with forward slash - Should work
2. ❌ CLI flag with forward slash - Currently fails, should work after fix
3. ❌ CLI flag with `./` prefix - Currently fails, should work after fix
4. ✅ CLI flag with backslash - Should continue to work

## Related Code Locations

- `air/runner/util_windows.go:43` - `startCmd()` - Executes command via PowerShell
- `air/runner/engine.go:733` - `runBin()` - Constructs binary execution command
- `air/runner/config.go:444` - `preprocess()` - Normalizes paths with `filepath.Abs()`
- `air/runner/util.go:485` - `formatPath()` - Formats paths for execution
- `air/runner/config.go:487` - `runnerBin()` - Returns binary path for execution

## Testing

See `TESTING.md` for detailed testing instructions on Windows VM.

## User Impact

Users currently need to:
- Use backslashes in CLI flags on Windows
- Or use config files instead of CLI flags

After fix, users can:
- Use forward slashes consistently across platforms
- Use the same CI/CD scripts for Linux and Windows
- Dynamically generate binary names without platform-specific logic
