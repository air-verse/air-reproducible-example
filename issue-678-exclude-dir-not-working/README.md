# Issue #678: Exclude dir not working

**Issue**: https://github.com/air-verse/air/issues/678  
**Status**: Bug confirmed and reproduced  
**Air Version**: v1.63.7 (latest)

## Problem Description

When `.air.toml` contains duplicate keys (e.g., `delay` defined twice), Air silently falls back to the default configuration instead of reporting a TOML parse error. This causes user-configured options like `exclude_dir` to be ignored.

## Root Cause

In `runner/config.go`, the `defaultPathConfig()` function silently ignores TOML parse errors:

```go
func defaultPathConfig() (*Config, error) {
    cfg, err := readConfByName(dftTOML)
    if err == nil {
        return cfg, nil
    }
    // BUG: Error is silently ignored, falls back to default config
    dftCfg := defaultConfig()
    return &dftCfg, nil
}
```

When running `air` without `-c` flag, parse errors are silently swallowed.
When running `air -c .air.toml`, errors are properly reported.

## Reproduction Steps

### Step 1: Build latest air

```bash
cd ../air
make build
```

### Step 2: Run air without -c flag (Bug scenario)

```bash
cd ../issue-678-exclude-dir-not-working
../air/air
```

**Expected**: Error message about duplicate TOML key  
**Actual**: Air starts silently with default config (BUG)

Output shows:
```
watching .
watching node_modules    <-- BUG! Should be excluded
!exclude tmp
```

### Step 3: Verify exclude_dir is not working

In another terminal, modify a .go file in node_modules:

```bash
echo '// modified' >> node_modules/dummy.go
```

**Expected**: No rebuild (node_modules is in exclude_dir)  
**Actual**: Air rebuilds (because it's using default config)

Output shows:
```
node_modules/dummy.go has changed
building...
```

### Step 4: Compare with -c flag (Error is reported)

```bash
../air/air -c .air.toml
```

**Expected**: Error message about duplicate TOML key  
**Actual**: Error is reported correctly ✓

Output:
```
(12, 1): The following key was defined twice: build.delay
```

## Reproduction Results Summary

| Test | Command | Expected | Actual | Status |
|------|---------|----------|--------|--------|
| No -c flag | `air` | Error: duplicate key | Silent start, uses default config | ❌ BUG |
| Modify excluded file | modify `node_modules/dummy.go` | No rebuild | Rebuilds | ❌ BUG |
| With -c flag | `air -c .air.toml` | Error: duplicate key | Error reported | ✅ OK |

## Files

- `.air.toml` - Config with duplicate `delay` key to trigger parse error
- `main.go` - Simple HTTP server
- `node_modules/dummy.go` - Test file in excluded directory

## Suggested Fix

Modify `defaultPathConfig()` to report errors when `.air.toml` exists but fails to parse:

```go
func defaultPathConfig() (*Config, error) {
    cfg, err := readConfByName(dftTOML)
    if err == nil {
        return cfg, nil
    }
    // Check if file exists but failed to parse
    if !os.IsNotExist(err) {
        return nil, fmt.Errorf("failed to parse %s: %w", dftTOML, err)
    }
    // Only use defaults if no config file exists
    dftCfg := defaultConfig()
    return &dftCfg, nil
}
```

The fix needs to distinguish between:
1. Config file not found → use defaults (OK)
2. Config file found but parse error → report error (current bug)
