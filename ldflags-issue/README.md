# Issue #513: ldflags not applied when run by Air

## Issue Link
https://github.com/air-verse/air/issues/513

## Problem Description
When Air runs a build command that uses `-ldflags`, the resulting binary does not include the
expected `Version` and `BuildTime` values. Running the same build command manually produces
the correct values.

## Setup
```bash
cd ldflags-issue
go mod download
```

## Expected Behavior
The server reports the `Version` and `BuildTime` values injected by `-ldflags`.

## Steps to Reproduce
### 1) Manual build (control)
```bash
make build
./tmp/main
```

In another terminal:
```bash
curl http://localhost:8080
```

You should see output similar to:
```
Version: 0.1.0-dev
BuildTime: 2026-01-24T12:34:56Z
```

### 2) Air build
```bash
air
```

Then check the running app:
```bash
curl http://localhost:8080
```

If the bug reproduces, `Version` or `BuildTime` remains `unknown` or does not change after
rebuilds. Edit `main.go` to trigger a rebuild and check the output again.

## Files in This Example
- `.air.toml` - Uses `make build` as the build command
- `Makefile` - Injects `Version` and `BuildTime` via `-ldflags`
- `main.go` - HTTP server that prints the injected values
- `go.mod` - Minimal module definition
