# Issue #505: tmp_dir with nested paths fails

**Issue URL**: https://github.com/air-verse/air/issues/505  
**Status**: BUG (labeled as enhancement, but is actually a bug)  
**Air Version Tested**: v1.63.6

## Issue Summary

When `tmp_dir` is set to a nested absolute path (e.g., `/tmp/air/nested/build`) that doesn't fully exist, Air fails to create the directory and exits with an error.

## Classification

This is a **BUG**, not an enhancement. The issue has two parts:

### Part A - FIXED by PR #318 (merged Dec 16, 2024)
- **Problem**: Air didn't respect absolute paths in `tmp_dir` configuration
- **Fix**: Added `joinPath()` helper that checks for absolute paths
- **Status**: ✅ RESOLVED

### Part B - STILL BROKEN (this reproduction)
- **Problem**: Air uses `os.Mkdir()` instead of `os.MkdirAll()` to create tmp directory
- **Impact**: Cannot create nested directory paths in one operation
- **Location**: `air/runner/engine.go:126`
- **Status**: ❌ NOT FIXED

## Root Cause

In `air/runner/engine.go` line 122-132, the `checkRunEnv()` function uses:

```go
func (e *Engine) checkRunEnv() error {
	p := e.config.tmpPath()
	if _, err := os.Stat(p); os.IsNotExist(err) {
		e.runnerLog("mkdir %s", p)
		if err := os.Mkdir(p, 0o755); err != nil {  // <-- BUG HERE
			e.runnerLog("failed to mkdir, error: %s", err.Error())
			return err
		}
	}
	return nil
}
```

**Problem**: `os.Mkdir()` can only create a single directory level. If the path requires creating multiple parent directories (e.g., `/tmp/air/nested/build` when `/tmp/air` doesn't exist), it fails.

**Fix**: Replace `os.Mkdir()` with `os.MkdirAll()`.

## Expected Behavior

When `.air.toml` contains:
```toml
tmp_dir = "/tmp/air-test-issue-505/nested/build"
```

Air should:
1. Create the full directory path `/tmp/air-test-issue-505/nested/build/` recursively
2. Build the binary to that location
3. Run the application successfully

## Actual Behavior

Air fails with:
```
mkdir /tmp/air-test-issue-505/nested/build
failed to mkdir, error: mkdir /tmp/air-test-issue-505/nested/build: no such file or directory
```

## Reproduction Steps

### Prerequisites
1. Build the latest Air from source (already done in `../air/`)
2. Navigate to this directory

### Scenario 1: Nested path doesn't exist (FAILS ❌)

```bash
# Clean up any existing test directory
rm -rf /tmp/air-test-issue-505

# Run Air
../air/air
```

**Expected**: Air creates the nested directory and runs  
**Actual**: Air fails with "no such file or directory" error

**Output**:
```
mkdir /tmp/air-test-issue-505/nested/build
failed to mkdir, error: mkdir /tmp/air-test-issue-505/nested/build: no such file or directory
```

### Scenario 2: Parent directory exists (WORKS ✅)

```bash
# Create parent directories manually
mkdir -p /tmp/air-test-issue-505/nested

# Run Air
../air/air
```

**Result**: Air successfully creates the final `build/` directory and runs

**Output**:
```
mkdir /tmp/air-test-issue-505/nested/build
watching .
building...
running...
Server starting on :3000...
```

This proves that Air can only create one directory level at a time.

## Files in This Reproduction

- `main.go` - Simple HTTP server on port 3000
- `.air.toml` - Configuration with nested `tmp_dir` path
- `go.mod` - Go module definition
- `README.md` - This file

## Proposed Fix

Change line 126 in `air/runner/engine.go` from:
```go
if err := os.Mkdir(p, 0o755); err != nil {
```

to:
```go
if err := os.MkdirAll(p, 0o755); err != nil {
```

This one-line change would allow Air to create the full directory tree recursively, matching user expectations and fixing the bug reported in issue #505.

## Related Issues

- PR #318: Fixed absolute path handling (merged)
- Issue #505: Original bug report
