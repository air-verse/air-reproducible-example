# Window Kill Twice - Air Issue #777 Reproduction

Minimal reproduction for [air-verse/air#777](https://github.com/air-verse/air/issues/777): **Windows doesn't kill processes properly**.

## Problem Summary

On Windows, when Air detects file changes and attempts to restart the application:
1. Air uses `TASKKILL /T /F /PID <pid>` to kill the process
2. However, `startCmd` launches the binary via PowerShell: `powershell cmd`
3. TASKKILL only kills the PowerShell process, not the actual Go application (child process)
4. The child process becomes orphaned and continues running
5. The new process fails to start due to port conflict

## Environment

- **OS**: Windows 11
- **Air Version**: 1.62.0+
- **Go Version**: 1.21+

## Reproduction Steps

1. **Install Air** (if not already installed):
   ```powershell
   go install github.com/air-verse/air@latest
   ```

2. **Navigate to this directory**:
   ```powershell
   cd window-kill-twice
   ```

3. **Start Air**:
   ```powershell
   air
   ```
   Note the PID printed in the output.

4. **Trigger hot reload** by modifying `main.go`:
   - Add a blank line or change the greeting text
   - Save the file

5. **Observe the error**:
   ```
   listen tcp :8080: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted.
   ```

6. **Verify orphaned processes**:
   ```powershell
   Get-Process | Where-Object {$_.Name -eq "main"}
   # OR
   tasklist | findstr main.exe
   ```
   You'll see multiple `main.exe` processes still running.

## Expected Behavior

- Air should terminate the entire process tree (PowerShell + child Go process)
- The port should be released
- The new process should start successfully

## Actual Behavior

- Only the PowerShell process is killed
- The Go application continues running as an orphan process
- Port 8080 remains occupied
- New process fails with "bind: address already in use"

## Workaround

Add `pre_cmd` to `.air.toml` to manually kill the process before rebuild:

```toml
[build]
pre_cmd = ["taskkill /F /IM main.exe 2>nul || echo ok"]
```

## Root Cause Analysis

In `runner/util_windows.go`:

```go
func (e *Engine) startCmd(cmd string) (*exec.Cmd, ...) {
    c := exec.Command("powershell", cmd)  // Starts via PowerShell
    // ...
}

func (e *Engine) killCmd(cmd *exec.Cmd) (pid int, err error) {
    pid = cmd.Process.Pid  // This is PowerShell's PID, not the app's PID
    kill := exec.Command("TASKKILL", "/T", "/F", "/PID", strconv.Itoa(pid))
    // TASKKILL /T should kill child processes, but PowerShell's process tree
    // handling may not work as expected
    // ...
}
```

Compare with Linux implementation (`util_linux.go`) which:
- Uses process groups (`Setpgid: true`)
- Has `sendSignalToProcessTree()` to recursively kill all descendants
- Uses `/proc/<pid>/task/<pid>/children` to find child processes

## Potential Fix

1. Use `cmd.exe` instead of PowerShell, or run the binary directly
2. Implement Windows-specific process tree termination using Job Objects
3. Use WMI to find and kill child processes

## Related Links

- [Issue #777](https://github.com/air-verse/air/issues/777)
- [TASKKILL Documentation](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/taskkill)
- [Windows Job Objects](https://docs.microsoft.com/en-us/windows/win32/procthread/job-objects)
