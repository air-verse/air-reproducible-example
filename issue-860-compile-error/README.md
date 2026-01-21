# Issue #860: Air kills app on compile error

**Issue URL**: https://github.com/air-verse/air/issues/860  
**Status**: ENHANCEMENT (requested behavior change)  
**Air Version Tested**: local build from `air/` (HEAD)

## Summary

With `stop_on_error = false` and `rerun = false`, Air still stops the running app process when a compile error occurs. The request is to keep the existing process alive on build failures.

## Expected Behavior

- When a compile error happens, the currently running binary keeps running.
- Air reports the build failure but does not kill the running process.

## Actual Behavior

- Air stops the running process after a compile error, then restarts once the error is fixed.

## Reproduction Steps

1. Build the latest Air from source:
   ```bash
   cd ../air
   go build -o air
   ```
2. Run Air in this directory:
   ```bash
   cd ../issue-860-compile-error
   ../air/air
   ```
3. Confirm the app is running (you should see a log line with the PID).
4. Introduce a compile error in `main.go` (e.g., delete a closing parenthesis).
5. Save the file and watch Air rebuild.

**Expected**: the running process stays alive.  
**Actual**: Air kills the running process even though `stop_on_error = false`.
