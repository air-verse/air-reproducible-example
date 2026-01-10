# Include File Issue Reproduction Example

This example reproduces [Air issue #545](https://github.com/air-verse/air/issues/545) - `include_file` configuration does not trigger rebuilds unless the file extension is also added to `include_ext`.

## The Issue

When using Air's `include_file` configuration to watch specific files:

- **Expected Behavior:** Files listed in `include_file` should trigger rebuilds when modified, regardless of their extension
- **Actual Behavior:** Files in `include_file` are listed as "watching" on startup, but changes to these files do NOT trigger rebuilds unless their extension is also in `include_ext`

This is problematic for:
- Files without extensions (e.g., `Makefile`, `Dockerfile`)
- Configuration files with extensions not normally watched (e.g., `.txt`, `.json`, `.yaml`)
- Any file you want to watch explicitly without watching all files of that type

## Prerequisites

- Go 1.21 or higher
- [Air](https://github.com/air-verse/air) installed (`go install github.com/air-verse/air@latest`)

## Setup

```bash
cd include-file-issue-545
go mod download
```

## Configuration

The `.air.toml` is configured as follows:

```toml
[build]
  include_ext = ["go"]           # Only watching .go files by extension
  include_file = ["myfile.txt", "Makefile"]  # Explicitly watching these files
```

Notice that:
- `myfile.txt` has `.txt` extension, which is NOT in `include_ext`
- `Makefile` has no extension at all
- Both files are explicitly listed in `include_file`

## Reproducing the Bug

### Step 1: Start Air

```bash
air
```

You should see Air start and display messages like:
```
watching myfile.txt
watching Makefile
```

This confirms Air is watching these files. The app will start on port **8080**.

### Step 2: Verify the app is running

```bash
curl http://localhost:8080
```

You should see output showing the current content of both files:
```
App started: 14:23:45.123
myfile.txt: Initial content - version 1
Makefile: .PHONY: build test clean
...
```

### Step 3: Modify myfile.txt (Bug Demonstration)

In another terminal, edit `myfile.txt`:

```bash
echo "Updated content - version 2" > myfile.txt
```

**Expected:** Air should detect the change and rebuild the app  
**Actual:** Nothing happens - no rebuild triggered (BUG!)

### Step 4: Modify Makefile (Bug Demonstration)

Edit the `Makefile`:

```bash
echo -e ".PHONY: build\n\nbuild:\n\tgo build ." > Makefile
```

**Expected:** Air should detect the change and rebuild the app  
**Actual:** Nothing happens - no rebuild triggered (BUG!)

### Step 5: Modify a .go file (Control Test)

Edit `main.go` to verify Air is still working:

```bash
echo "package main

import (
	\"fmt\"
	\"log\"
	\"net/http\"
	\"os\"
	\"time\"
)

func main() {
	// Add a comment to trigger rebuild
	content, err := os.ReadFile(\"myfile.txt\")
	if err != nil {
		log.Printf(\"Warning: could not read myfile.txt: %v\", err)
		content = []byte(\"(file not found)\")
	}

	makefileContent, err := os.ReadFile(\"Makefile\")
	if err != nil {
		log.Printf(\"Warning: could not read Makefile: %v\", err)
		makefileContent = []byte(\"(file not found)\")
	}

	startTime := time.Now()
	
	log.Printf(\"===========================================\")
	log.Printf(\"App started at: %s\", startTime.Format(\"15:04:05.000\"))
	log.Printf(\"myfile.txt content: %s\", string(content))
	log.Printf(\"Makefile content: %s\", string(makefileContent))
	log.Printf(\"===========================================\")

	http.HandleFunc(\"/\", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, \"App started: %s\\n\", startTime.Format(\"15:04:05.000\"))
		fmt.Fprintf(w, \"myfile.txt: %s\\n\", string(content))
		fmt.Fprintf(w, \"Makefile: %s\\n\", string(makefileContent))
	})

	http.HandleFunc(\"/health\", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, \"OK - Started at %s\\n\", startTime.Format(\"15:04:05.000\"))
	})

	log.Println(\"Server listening on :8080\")
	log.Println(\"Visit http://localhost:8080 to see file contents\")
	log.Fatal(http.ListenAndServe(\":8080\", nil))
}" > main.go
```

**Expected:** Air detects the change and rebuilds  
**Actual:** Air correctly rebuilds! This proves Air is working, but only for `.go` files.

Now check the app again:

```bash
curl http://localhost:8080
```

You'll see the app has restarted with a new start time, but it's STILL showing the OLD content from `myfile.txt` and `Makefile` because those changes never triggered a rebuild.

## Workaround

The only current workaround is to add the file extensions to `include_ext`:

Edit `.air.toml` and change:
```toml
include_ext = ["go", "txt"]  # Added "txt"
```

Now modify `myfile.txt` again:
```bash
echo "Updated content - version 3" > myfile.txt
```

**Result:** Air will now detect the change and rebuild! But this has the side effect of watching ALL `.txt` files in your project, which may not be desired.

**Problem:** This workaround doesn't work for files without extensions like `Makefile`, `Dockerfile`, etc.

## Technical Details

### Root Cause

The bug is in `air/runner/engine.go`. The file watching logic uses incorrect boolean conditions:

**Line 247** (in `cacheFileChecksums`):
```go
if e.isExcludeFile(path) || !e.isIncludeExt(path) && !e.checkIncludeFile(path) {
```

**Line 312** (in event handling):
```go
if !e.isIncludeExt(path) && !e.checkIncludeFile(path) {
    break
}
```

The condition `!e.isIncludeExt(path) && !e.checkIncludeFile(path)` excludes a file only when BOTH:
1. The extension is not in `include_ext` AND
2. The file is not in `include_file`

This means a file is only included when BOTH conditions are false, which is wrong.

**The fix:** The logic should be `!e.isIncludeExt(path) && !e.checkIncludeFile(path)` should become `!(e.isIncludeExt(path) || e.checkIncludeFile(path))` or more simply, files should be included if EITHER condition is true:
```go
if !(e.isIncludeExt(path) || e.checkIncludeFile(path)) {
    // exclude the file
}
```

### Files in This Example

- `main.go` - Simple Go app that reads and displays file contents
- `myfile.txt` - Test file with `.txt` extension (not in `include_ext`)
- `Makefile` - Test file with no extension
- `.air.toml` - Air configuration demonstrating the issue
- `go.mod` - Go module definition

## Expected vs Actual Behavior

| Action | Expected | Actual |
|--------|----------|--------|
| Start Air | Files listed as "watching" | ✅ Works correctly |
| Modify `myfile.txt` | Rebuild triggered | ❌ No rebuild (BUG) |
| Modify `Makefile` | Rebuild triggered | ❌ No rebuild (BUG) |
| Modify `main.go` | Rebuild triggered | ✅ Works correctly |
| Add `.txt` to `include_ext` then modify `myfile.txt` | Rebuild triggered | ✅ Works (workaround) |

## Related Issues

- GitHub Issue: [air-verse/air#545 - include_file also needs include_ext to work](https://github.com/air-verse/air/issues/545)
- Related comment about needing to set `root`: [air-verse/air#603](https://github.com/air-verse/air/issues/603)

## Summary

This example clearly demonstrates that `include_file` does not work as documented. Files are added to the watcher but changes are not processed, making the feature effectively broken for any file whose extension is not already in `include_ext`.
