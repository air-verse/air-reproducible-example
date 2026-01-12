# Air Require TTY - Reproduction Example

This is a minimal reproduction example for [Air issue #737](https://github.com/air-verse/air/issues/737).

## Problem Description

Air runs the program but does not trigger hot reload when running in Docker Compose **without** `tty: true`. The issue was reported to affect both fsnotify mode and polling mode.

## Environment

- Docker with Docker Compose
- Go 1.21+
- Air (latest)

## Services

| Service | Port | TTY | Polling | Expected Behavior |
|---------|------|-----|---------|-------------------|
| `app-no-tty` | 3001 | No | No | Hot reload may NOT work |
| `app-with-tty` | 3002 | Yes | No | Hot reload should work |
| `app-no-tty-poll` | 3003 | No | Yes | Test if polling helps |

## Reproduction Steps

### 1. Build and start the containers

```bash
docker compose up --build -d
```

### 2. Verify all services are running

```bash
curl http://localhost:3001  # app-no-tty
curl http://localhost:3002  # app-with-tty
curl http://localhost:3003  # app-no-tty-poll
```

All should return: `Hello, World! v1`

### 3. Modify the source code

Edit `main.go` and change the `Version` constant:

```go
const Version = "v2"
```

### 4. Wait a few seconds and test again

```bash
# Wait for hot reload
sleep 5

curl http://localhost:3001  # Expected: still v1 (no hot reload)
curl http://localhost:3002  # Expected: v2 (hot reload worked)
curl http://localhost:3003  # Expected: ??? (test polling mode)
```

### 5. Check container logs

```bash
docker compose logs app-no-tty
docker compose logs app-with-tty
docker compose logs app-no-tty-poll
```

Look for:
- `watching ...` messages (watcher initialized)
- `main.go has changed` messages (file change detected)
- `building...` messages (rebuild triggered)

## Expected Results

| Service | File Change Detected | Rebuild Triggered | New Version Served |
|---------|---------------------|-------------------|-------------------|
| `app-no-tty` | ? | ? | ? |
| `app-with-tty` | Yes | Yes | Yes |
| `app-no-tty-poll` | ? | ? | ? |

## Workaround

Add `tty: true` to your Docker Compose service:

```yaml
services:
  app:
    build: .
    tty: true  # <-- This fixes the issue
    volumes:
      - .:/app
```

## Cleanup

```bash
docker compose down -v
```

## Related Issues

- [Air #737](https://github.com/air-verse/air/issues/737) - docs: Air **requires** tty
- [fsnotify #292](https://github.com/fsnotify/fsnotify/issues/292) - Docker on Windows (different issue)

## Analysis Notes

From code analysis, Air does not appear to have explicit TTY dependency:
- `go-isatty` is only used by `fatih/color` for colored output
- `fsnotify` and polling mechanisms don't depend on TTY
- No stdin reading or TTY detection in Air source

The root cause needs further investigation through this reproduction.
