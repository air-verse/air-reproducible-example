# Issue #761: Air watches all files in dangerous directories

## Issue Link
https://github.com/air-verse/air/issues/761

## Problem Description

When running `air` in the home directory (`~`), root directory (`/`), or `/root`, 
it watches all files and subdirectories instead of refusing to run. This results in:

- Excessive file watching
- High CPU usage
- Potential performance issues or system crashes

## Expected Behavior

Air should refuse to run in dangerous directories like:
- `~` (user home directory)
- `/` (root directory)
- `/root` (root user's home directory)

And display an error message like:
```
refusing to run in home directory (~) - this would watch too many files. Please run air in a project directory
```

## Steps to Reproduce (DO NOT RUN IN HOME DIRECTORY!)

**WARNING: Do NOT actually run these commands - they are for documentation only.**

```bash
# DANGEROUS - DO NOT RUN
cd ~
air  # This would watch ALL files in your home directory

# DANGEROUS - DO NOT RUN
cd /
air  # This would watch ALL files in the entire system
```

## Safe Reproduction Test

Use the `test_fix.sh` script to verify the fix works correctly:

```bash
./test_fix.sh /path/to/air-binary
```

This script:
1. Creates a safe temporary directory
2. Tests that air runs normally in a project directory
3. Tests that air refuses to run in simulated dangerous directories
4. Cleans up after itself

## Fix Implementation

The fix adds a check in `runner/config.go` `preprocess()` function that:

1. Detects if the root directory is a dangerous location
2. Returns an error before starting the file watcher
3. Provides a clear error message to the user

### Files Modified

- `runner/util.go`: Added `isDangerousRoot()` function
- `runner/config.go`: Added check in `preprocess()` after root path expansion
- `runner/util_test.go`: Added unit tests for `isDangerousRoot()`

### Dangerous Directories Blocked

| Directory | Description |
|-----------|-------------|
| `~` | User's home directory |
| `/` | Root directory (entire filesystem) |
| `/root` | Root user's home directory |

## Testing

```bash
cd air2
go test -run TestIsDangerousRoot ./runner/
```
