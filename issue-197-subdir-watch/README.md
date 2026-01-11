# Issue #197 Reproduction: Air only watches root folder files

GitHub Issue: https://github.com/air-verse/air/issues/197

## Problem

Air does not detect file changes in subdirectories (e.g., `cmd/app/`) even though
the log shows "watching cmd/app". This is particularly common on WSL2.

## Root Cause

1. **WSL2 inotify limitation**: WSL2 uses 9P protocol to access Windows filesystem 
   (`/mnt/c/...`), which does not support inotify events
2. **fsnotify dependency**: fsnotify relies on Linux inotify, so filesystem events 
   are never received
3. **Poll mode workaround**: Poll mode (`poll = true`) works because it uses 
   `os.Stat()` and `os.Readdir()` instead of inotify

## Code Analysis

### Key Code Locations (air/ directory)

- `runner/watcher.go:9-24` - Watcher creation (fsnotify vs poll mode)
- `runner/engine.go:168-206` - Directory traversal with `filepath.Walk`
- `runner/engine.go:301-303` - Event handling and `watchNewDir` call
- `runner/util.go:280-286` - `isDir()` check (potential race condition)

### Why poll=true Works

Poll mode in Hugo's filenotify library:
- Uses `os.Readdir(-1)` to scan directory contents every poll interval
- Compares `FileInfo` snapshots (ModTime, Size) to detect changes
- Does not rely on kernel inotify events
- Works on any filesystem including NFS, 9P, etc.

## Reproduction Steps

1. **Run Air**:
   ```bash
   cd issue-197-subdir-watch
   air
   ```

2. **Verify watching log** shows:
   ```
   watching .
   watching cmd
   watching cmd/app
   !exclude tmp
   building...
   running...
   ```

3. **Test server** (in another terminal):
   ```bash
   curl http://localhost:8080
   # Output: Hello from v1 at 2026-01-11T...
   ```

4. **Modify subdirectory file**:
   - Edit `cmd/app/main.go`
   - Change `version := "v1"` to `version := "v2"`
   - Save the file

### Expected Behavior

Air should detect the change and rebuild automatically:
```
cmd/app/main.go has changed
building...
running...
```

### Actual Behavior (on WSL2 with /mnt/c/... path)

Air does **not** respond to changes in `cmd/app/main.go`.

## Workaround

Uncomment `poll = true` in `.air.toml`:

```toml
[build]
poll = true
poll_interval = 500  # milliseconds, minimum 500
```

Restart Air and test again - it should now detect subdirectory changes.

## Environment Matrix

| Environment | Expected Result |
|-------------|-----------------|
| WSL2 + `/mnt/c/...` path | **Bug confirmed** (inotify doesn't work) |
| WSL2 + `/home/...` path | Usually works (native ext4 filesystem) |
| Native Linux | Usually works |
| macOS | Needs testing (uses FSEvents instead of inotify) |
| Windows | Needs testing (uses ReadDirectoryChangesW) |

## Technical Details

### fsnotify Mode (Default)

```
watcher.Add("/path/to/dir") 
  ↓
inotify_add_watch() syscall
  ↓
Kernel sends events when files change
  ↓
fsnotify.Watcher.Events channel receives events
```

**Problem**: WSL2's 9P filesystem driver does not generate inotify events.

### Poll Mode (Workaround)

```
watcher.Add("/path/to/dir")
  ↓
Spawn goroutine with ticker (500ms default)
  ↓
Every tick: os.Stat() + os.Readdir()
  ↓
Compare FileInfo snapshots
  ↓
Generate synthetic fsnotify.Event
```

**Advantage**: Works on any filesystem, no kernel events needed.

**Trade-off**: Higher CPU usage, minimum 500ms latency.

## Related Issues

- #274 - WSL file watching issues
- #509 - Poll mode discussion
- fsnotify/fsnotify#9 - Poll-based watcher feature request

## Potential Fixes

1. **Auto-detect WSL2**: Check `/proc/version` for "microsoft", auto-enable poll mode
2. **Improve error messaging**: Warn users when inotify watches fail to add
3. **Hybrid mode**: Use poll for specific problematic paths
4. **Better docs**: Clearly document WSL2 limitations and poll mode solution
