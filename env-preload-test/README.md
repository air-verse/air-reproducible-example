# Env Preload Test

This directory contains a minimal reproduction environment for testing [Air PR #856](https://github.com/air-verse/air/pull/856) - the `.env` file preload feature.

## Related Issues

- **Issue**: [#849 - Preload .env files](https://github.com/air-verse/air/issues/849)
- **PR**: [#856 - Implement .env file preload](https://github.com/air-verse/air/pull/856)

## Purpose

Test that Air can:
1. Load environment variables from `.env` file before build/run
2. Expand variable references (e.g., `${VAR}`)
3. Hot-reload `.env` changes on file modification
4. Handle edge cases (empty values, quoted strings, special characters)

## Setup

### 1. Build Air with PR #856

```bash
cd ../air
git fetch origin pull/856/head:pr-856
git checkout pr-856
make build
```

### 2. Run the test

```bash
cd ../env-preload-test
../air/air
```

Or if Air is installed globally with the PR:
```bash
air
```

## Expected Behavior

When Air starts, you should see output like:

```
=== Environment Variables Loaded by Air ===
APP_NAME = EnvPreloadTest
APP_PORT = 8080
DEBUG = true
BASE_URL = http://localhost
API_URL = http://localhost:8080/api
DB_CONNECTION_STRING = host=localhost port=5432 user=test
EMPTY_VAR = <empty>
MESSAGE = Hello World from Air!
============================================

=== Expansion Test ===
OK: API_URL correctly expanded to: http://localhost:8080/api
======================

Server starting on http://localhost:8080
```

## Test Cases

| Test | How to verify | Expected |
|------|---------------|----------|
| Basic loading | Check startup output | All variables printed |
| Variable expansion | Check `API_URL` value | `http://localhost:8080/api` |
| Quoted strings | Check `MESSAGE` | `Hello World from Air!` |
| Empty value | Check `EMPTY_VAR` | Should be empty, not undefined |
| Hot reload | Edit `.env`, save | Air restarts with new values |
| Delete variable | Remove a line from `.env` | Variable reverts to system value |

## Files

- `.env` - Test environment variables
- `.air.toml` - Air configuration with `env_file = [".env"]`
- `main.go` - Simple HTTP server that prints env vars
- `go.mod` - Go module definition

## Endpoints

- `http://localhost:8080/` - Shows all loaded environment variables
- `http://localhost:8080/health` - Health check endpoint

## Troubleshooting

**Variables not loading?**
- Ensure you're using Air built from PR #856
- Check that `.air.toml` has `env_file = [".env"]` in `[build]` section

**Expansion not working?**
- Variable expansion (`${VAR}`) is a feature of PR #856
- If `API_URL` shows `${BASE_URL}:${APP_PORT}/api` literally, expansion isn't working
