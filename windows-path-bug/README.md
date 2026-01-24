# Windows Path Bug - Issue #589

Minimal reproduction case for Air issue: https://github.com/air-verse/air/issues/589

## Bug Description

On Windows, Air fails to execute binaries when the path is provided via CLI flags with forward slashes (`/`). However, the same path works perfectly fine when specified in the `.air.toml` configuration file.

**Root Cause:** The `startCmd()` function in `runner/util_windows.go` passes the binary path directly to PowerShell without proper normalization. PowerShell interprets `bin/app.exe` as two separate tokens (`bin` and `/app.exe`) rather than a single path.

## Prerequisites

- **Windows 10/11** (This bug is Windows-specific)
- **Go 1.21+** installed
- **Air** installed (`go install github.com/air-verse/air@latest`)
- **PowerShell** (default on Windows)

## Setup

```bash
cd windows-path-bug
go mod tidy
```

## Test Scenarios

### ✅ Scenario 1: Config file with forward slash (WORKS)

```bash
air
```

**Expected Output:**
```
building...
Building windows-path-bug...
Build complete: bin/windows-path-bug.exe
running...
Hello from Air! Running successfully...
```

**Why it works:** The config file path goes through `filepath.Abs()` which normalizes it to Windows format with backslashes.

---

### ❌ Scenario 2: CLI with forward slash (FAILS)

```bash
air --build.cmd "make build" --build.bin "bin/windows-path-bug.exe"
```

**Expected Error:**
```
building...
Building windows-path-bug...
Build complete: bin/windows-path-bug.exe
running...
'bin' is not recognized as an internal or external command,
operable program or batch file.
Process Exit with Code: 1
```

**Why it fails:** PowerShell receives the command string and interprets `bin/windows-path-bug.exe` as two separate commands instead of a single path.

---

### ❌ Scenario 3: CLI with ./ prefix (FAILS)

```bash
air --build.cmd "make build" --build.bin "./bin/windows-path-bug.exe"
```

**Expected Error:**
```
building...
Building windows-path-bug...
Build complete: bin/windows-path-bug.exe
running...
'.' is not recognized as an internal or external command,
operable program or batch file.
```

**Why it fails:** Same issue - PowerShell treats `.` as a separate command.

---

### ✅ Scenario 4: CLI with backslash (WORKS)

```bash
air --build.cmd "make build" --build.bin "bin\windows-path-bug.exe"
```

**Expected Output:**
```
building...
Building windows-path-bug...
Build complete: bin/windows-path-bug.exe
running...
Hello from Air! Running successfully...
```

**Why it works:** Backslash is the native Windows path separator and PowerShell handles it correctly.

---

## Expected Behavior

**All scenarios should work.** Users should be able to use forward slashes (`/`) in CLI flags just like they do in config files. Air should normalize paths internally for Windows compatibility.

## Root Cause Analysis

### The Problem

In `air/runner/util_windows.go:43-52`:

```go
func (e *Engine) startCmd(cmd string) (*exec.Cmd, io.ReadCloser, io.ReadCloser, error) {
    // ...
    c := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", cmd)
    // ...
}
```

When the binary path contains forward slashes like `bin/windows-path-bug.exe`, PowerShell's `-Command` parameter interprets it as:
- Token 1: `bin` (command)
- Token 2: `/windows-path-bug.exe` (argument)

Instead of a single path: `bin/windows-path-bug.exe`

### Why Config File Works

In `air/runner/config.go:444`, the path goes through `filepath.Abs()`:

```go
c.Build.Bin, err = filepath.Abs(c.Build.Bin)
```

This converts `bin/windows-path-bug.exe` to `C:\path\to\project\bin\windows-path-bug.exe` with proper backslashes.

### The Fix

The binary path should be normalized using `filepath.FromSlash()` or ensured to go through `filepath.Abs()` before being passed to `startCmd()`. This would convert forward slashes to backslashes on Windows.

**Potential fix location:** `air/runner/engine.go:733` in the `runBin()` function, before calling `formatPath()`.

## File Structure

```
windows-path-bug/
├── .air.toml              # Working config (forward slash)
├── go.mod                 # Go module definition
├── main.go                # Simple test program
├── Makefile               # Build commands
├── bin/                   # Build output directory
└── README.md              # This file
```

## Impact

- **Severity:** Medium
- **Workaround:** Use backslashes in CLI flags on Windows
- **Breaking:** No - fix would only improve compatibility
- **Use Case:** Users who need dynamic binary names (as mentioned in the original issue) or cross-platform scripts

## Related Issues

- Original issue: https://github.com/air-verse/air/issues/589
- Related to Windows path handling and PowerShell command parsing

## Testing the Fix

Once the fix is implemented, all four scenarios above should work identically, demonstrating proper cross-platform path handling.
