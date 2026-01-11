# Issue #744: Air randomly outputs same thing on either stdout and stderr

## Issue Links

- **Air Issue:** https://github.com/air-verse/air/issues/744
- **Related fblog Issue:** https://github.com/brocode/fblog/issues/115

## Problem Description

Air preserves the separation between subprocess stdout and stderr. When piping `air | jq`, only stdout is captured, and any stderr output from the subprocess is lost (it goes directly to the terminal, bypassing the pipe).

This breaks compatibility with Unix pipe commands like:

```bash
air | jq -R 'try fromjson catch .'   # stderr logs are missed by jq
air | fblog                           # Same problem
```

## Root Cause Analysis

Air uses two parallel goroutines to copy subprocess output:

```go
// runner/engine.go:678-679
go copyOutput(os.Stdout, stdout)
go copyOutput(os.Stderr, stderr)
```

This causes:
1. Subprocess stdout → Air stdout (captured by pipe)
2. Subprocess stderr → Air stderr (NOT captured by pipe)

The issue manifests when applications write logs to stderr (which is common for warnings, errors, and debug info). Air faithfully preserves this separation, but users expect `air | command` to capture ALL subprocess output.

## Reproduction Steps

### Prerequisites

```bash
# Install Air (or use local build)
go install github.com/air-verse/air@latest

# Optional: Install jq for JSON parsing test
# apt install jq  # or brew install jq
```

### Quick Test

```bash
cd issue-744-stdout-stderr
go mod tidy
bash test.sh
```

### Manual Test

```bash
cd issue-744-stdout-stderr
go mod tidy

# Run air with stdout/stderr separated
air 2>stderr.log 1>stdout.log &
sleep 10
kill %1

# Check if anything went to stderr
wc -l stderr.log  # Should show lines if bug is present
cat stderr.log
```

### Using jq (as reported in issue)

```bash
# Bug: stderr logs are not processed by jq
air | jq -R 'try fromjson catch .'

# Workaround: Redirect stderr to stdout
air 2>&1 | jq -R 'try fromjson catch .'
```

## Expected Behavior

All subprocess output (both stdout and stderr) should be available through the pipe, or Air should provide a configuration option to merge streams.

## Actual Behavior

- Subprocess stderr goes to Air's stderr (bypasses pipe)
- This breaks JSON formatters and log processors piped to Air's stdout
- Users must use `air 2>&1 | ...` as a workaround

## Workaround

Redirect stderr to stdout:

```bash
air 2>&1 | jq -R 'try fromjson catch .'
air 2>&1 | fblog
```

## Files

| File | Description |
|------|-------------|
| `main.go` | Echo server that logs to both stdout and stderr |
| `.air.toml` | Air configuration (from original issue) |
| `go.mod` | Go module with Echo dependency |
| `test.sh` | Automated test script to verify the bug |

## Test Output Example

```
=== ANALYSIS RESULTS ===

--- stdout.log (117 lines) ---
{"time":"...","level":"-","prefix":"echo","message":"tick-1"}
{"time":"...","level":"-","prefix":"echo","message":"tick-2"}
...

--- stderr.log (19 lines) ---
{"time":"...","level":"WARN","source":"stderr","message":"warning-tick-5"}
{"time":"...","level":"WARN","source":"stderr","message":"warning-tick-10"}
...

=== VERDICT ===
BUG CONFIRMED: Air wrote 19 lines to stderr!

CRITICAL: 19 JSON log lines went to stderr!
These would be missed by JSON formatters piped to stdout.
```

## Potential Fix Directions

1. **Add config option to merge streams** - `[log] merge_streams = true`
2. **Change default behavior** - Redirect subprocess stderr to stdout by default
3. **Provide CLI flag** - `air --merge-output | jq ...`
