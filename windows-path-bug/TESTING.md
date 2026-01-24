# Testing Guide for Windows VM

This guide helps you quickly test all scenarios on your Windows VM.

## Prerequisites

1. **Install Go** (if not already installed):
   - Download from: https://go.dev/dl/
   - Add to PATH: `C:\Go\bin`

2. **Install Air**:
   ```powershell
   go install github.com/air-verse/air@latest
   ```

3. **Install Make for Windows** (if not already installed):
   - **Option A - Chocolatey:**
     ```powershell
     choco install make
     ```
   - **Option B - Manual:**
     - Download from: http://gnuwin32.sourceforge.net/packages/make.htm
     - Add to PATH

4. **Clone this repo** to your Windows VM

## Quick Test (Automated)

Run one of these scripts to test all scenarios automatically:

### PowerShell:
```powershell
cd windows-path-bug
.\test-scenarios.ps1
```

### CMD:
```cmd
cd windows-path-bug
test-scenarios.bat
```

## Manual Testing

### Setup
```powershell
cd windows-path-bug
go mod tidy
```

### Test 1: Config file ✅ (Should WORK)
```powershell
air
```
**Expected:** Binary builds and runs successfully. You'll see:
```
Hello from Air! Running successfully...
Running... 1/30
```

Press `Ctrl+C` to stop, then clean up:
```powershell
rm -r bin, tmp
```

---

### Test 2: CLI with forward slash ❌ (Should FAIL)
```powershell
air --build.cmd "make build" --build.bin "bin/windows-path-bug.exe"
```
**Expected:** Build succeeds but running fails with:
```
'bin' is not recognized as an internal or external command,
operable program or batch file.
Process Exit with Code: 1
```

Press `Ctrl+C` to stop, then clean up:
```powershell
rm -r bin, tmp
```

---

### Test 3: CLI with ./ prefix ❌ (Should FAIL)
```powershell
air --build.cmd "make build" --build.bin "./bin/windows-path-bug.exe"
```
**Expected:** Build succeeds but running fails with:
```
'.' is not recognized as an internal or external command,
operable program or batch file.
```

Press `Ctrl+C` to stop, then clean up:
```powershell
rm -r bin, tmp
```

---

### Test 4: CLI with backslash ✅ (Should WORK)
```powershell
air --build.cmd "make build" --build.bin "bin\windows-path-bug.exe"
```
**Expected:** Binary builds and runs successfully. You'll see:
```
Hello from Air! Running successfully...
Running... 1/30
```

Press `Ctrl+C` to stop, then clean up:
```powershell
rm -r bin, tmp
```

---

## Troubleshooting

### "make: command not found"
Install Make for Windows (see Prerequisites above) or modify the tests to use direct Go commands:
```powershell
# Instead of "make build", use:
air --build.cmd "go build -o bin/windows-path-bug.exe main.go" --build.bin "bin\windows-path-bug.exe"
```

### "air: command not found"
Make sure `$GOPATH/bin` is in your PATH:
```powershell
# PowerShell
$env:Path += ";$env:USERPROFILE\go\bin"

# Or permanently via System Properties > Environment Variables
```

### Port already in use
This example doesn't use any ports, so this shouldn't happen. If you see port conflicts, another Air instance might be running:
```powershell
# Kill all air processes
taskkill /F /IM air.exe
```

## Expected Results Summary

| Test | Command | Expected Result |
|------|---------|----------------|
| 1 | Config file with `/` | ✅ **WORKS** |
| 2 | CLI flag with `/` | ❌ **FAILS** - Bug! |
| 3 | CLI flag with `./` | ❌ **FAILS** - Bug! |
| 4 | CLI flag with `\` | ✅ **WORKS** |

**The bug:** Tests 2 and 3 should work (like Test 1), but they fail because PowerShell misinterprets the path.

## Reporting Results

After testing, please report:
1. Which tests passed/failed (should match table above)
2. Windows version (e.g., Windows 10, Windows 11)
3. PowerShell version: `$PSVersionTable.PSVersion`
4. Air version: `air -v`
5. Any error messages or unexpected behavior

You can add results as a comment on: https://github.com/air-verse/air/issues/589
