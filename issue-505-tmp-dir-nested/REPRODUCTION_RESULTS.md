# Issue #505 Reproduction Results

**Date**: 2026-01-10  
**Air Version**: v1.63.6  
**Go Version**: 1.25.4

## Summary

Successfully reproduced issue #505. The bug is confirmed:

- ✅ Air FAILS when tmp_dir requires creating nested directories
- ✅ Air WORKS when only one directory level needs to be created
- ✅ Root cause identified in `air/runner/engine.go:126`

## Test Results

### Scenario 1: Nested path doesn't exist ❌ FAILED

**Setup**:
```bash
rm -rf /tmp/air-test-issue-505
# tmp_dir = "/tmp/air-test-issue-505/nested/build"
```

**Result**:
```
mkdir /tmp/air-test-issue-505/nested/build
failed to mkdir, error: mkdir /tmp/air-test-issue-505/nested/build: no such file or directory
```

**Status**: Air exits immediately, unable to start

### Scenario 2: Parent directory exists ✅ SUCCESS

**Setup**:
```bash
mkdir -p /tmp/air-test-issue-505/nested
# tmp_dir = "/tmp/air-test-issue-505/nested/build"
```

**Result**:
```
mkdir /tmp/air-test-issue-505/nested/build
watching .
building...
running...
Server starting on :3000...
```

**Status**: Air creates the final directory and runs successfully

## Code Analysis

### Current Implementation (BROKEN)
File: `air/runner/engine.go:126`

```go
if err := os.Mkdir(p, 0o755); err != nil {
    e.runnerLog("failed to mkdir, error: %s", err.Error())
    return err
}
```

**Problem**: `os.Mkdir()` can only create a single directory level.

### Proposed Fix (ONE LINE CHANGE)

```go
if err := os.MkdirAll(p, 0o755); err != nil {
    e.runnerLog("failed to mkdir, error: %s", err.Error())
    return err
}
```

**Benefit**: `os.MkdirAll()` creates all parent directories as needed, just like `mkdir -p`.

## Related Context

### PR #318 (Merged Dec 16, 2024)
- Fixed absolute path handling in `tmp_dir`
- Introduced `joinPath()` helper that respects absolute paths
- This PR partially addressed issue #505 but didn't fix the nested directory creation problem

### Issue #505 (Still Open)
- Original reporter encountered this when using Docker with `/tmp/air` as tmp_dir
- The issue affects anyone using nested absolute paths for tmp_dir
- Labeled as "enhancement" but is actually a bug

## Impact

Users cannot use:
- Nested tmp_dir paths: `/tmp/air/myproject/build`
- Project-specific tmp locations: `/tmp/project-name/air`
- Any tmp_dir configuration requiring parent directory creation

## Workaround

Manually create parent directories before running Air:
```bash
mkdir -p /tmp/air/nested
air  # Now works because only 'build/' needs to be created
```

## Recommendation

Apply the one-line fix to `air/runner/engine.go:126` changing `os.Mkdir()` to `os.MkdirAll()`.
