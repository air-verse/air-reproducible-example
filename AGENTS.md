# AGENTS

Guidelines for contributors and AI coding agents working in this repository.

## Repository Overview

This repository contains minimal reproducible examples for [Air](https://github.com/air-verse/air) bugs, plus a clone of the Air source code for testing fixes. The primary goal is to isolate and demonstrate specific issues.

**Structure:**
- `air/` - Clone of the Air live-reload tool (Go project)
- Root-level directories - Individual bug reproduction examples (e.g., `air-proxy-timeout/`, `sse-chunking-issue/`)
- Each example is a standalone Go project with its own `.air.toml`, `go.mod`, and `README.md`

## Quick Start

### Air Project (air/ directory)

**Build & Install:**
```bash
cd air
make build          # Build air binary
make install        # Install to $GOPATH/bin
make ci             # Prepare CI environment (go mod tidy)
make init           # One-time setup: install goimports, golangci-lint, pre-commit hook
```

**Testing:**
```bash
cd air
go test ./...                    # Run all tests
go test ./runner/                # Run tests in runner package
go test -run TestRegexes ./runner/  # Run a single test
go test -v ./...                 # Verbose output
go test -coverprofile=coverage.txt ./...  # With coverage
```

**Linting & Formatting:**
```bash
cd air
make check          # Format with goimports + lint with golangci-lint
./hack/check.sh     # Same as above (staged files only by default)
./hack/check.sh all # Check all Go files
```

### Reproduction Examples

Each example directory is independent:
```bash
cd air-proxy-timeout/  # or any other example
air                    # Run the example with Air
go run server.go       # Or run directly without Air
```

Refer to each example's README.md for specific behavior, ports, and trigger steps.

## Code Style (Go)

**Imports:**
- Use `goimports` for automatic import formatting and organization
- Standard library imports first, then external packages, then project packages
- Run `make check` before committing

**Formatting:**
- Rely on `goimports` (automatically handles `gofmt` compliance)
- Enforced via `hack/check.sh` and pre-commit hook

**Types:**
- Use explicit types for struct fields with TOML/JSON tags
- Prefer named return values for complex functions with multiple returns
- Table-driven tests with clear struct field names

**Naming Conventions:**
- Exported: `PascalCase` (functions, types, constants)
- Unexported: `camelCase` (variables, fields, private functions)
- Test files: `*_test.go` (e.g., `config_test.go`)
- Test functions: `TestFunctionName` or `TestFeature` (e.g., `TestRegexes`)
- Receiver names: short (1-2 letters, e.g., `e *Engine`)
- Constants: `camelCase` or `PascalCase` depending on export

**Error Handling:**
- Wrap errors with context using `fmt.Errorf("context: %w", err)`
- Return errors early, avoid deep nesting
- Avoid panics in library code; use them only in main or unrecoverable situations
- Check errors immediately after operations

**Concurrency:**
- Use contexts for cancellation and timeouts
- Prefer channels or mutexes over ad-hoc global state
- Avoid data races (verify with `go test -race ./...`)
- Document goroutine lifecycle and ownership

**Logging:**
- Use the custom `logger` type in `runner/logger.go`
- Keep logs concise, actionable, and consistent with existing patterns
- Avoid verbose logging in hot paths

**Comments:**
- Exported items must have doc comments starting with the item name
- Use `//` for single-line, `/* */` for multi-line or inline
- Keep comments updated when code changes

## Testing Guidelines

**Location:**
- Tests live alongside code as `*_test.go` (e.g., `runner/config_test.go`)
- Test data in `_testdata/` directories (gitignored if in `tmp/`)

**Scope:**
- Unit tests for behavior changes and edge cases
- Table-driven tests for multiple input scenarios
- Integration tests in `smoke_test/` directory

**Patterns:**
```go
// Table-driven test example
func TestExample(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
    }{
        {name: "case1", input: "a", expected: "A"},
        {name: "case2", input: "b", expected: "B"},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Process(tt.input)
            if result != tt.expected {
                t.Errorf("got %v, want %v", result, tt.expected)
            }
        })
    }
}
```

**Assertions:**
- Prefer `github.com/stretchr/testify/assert` for readable assertions
- Use `t.Fatalf()` for setup failures, `t.Errorf()` for assertion failures

## Common Change Points (Air Project)

**Config fields** (`runner/config.go`):
1. Add field to appropriate `cfg*` struct with TOML tags
2. Update defaults in `defaultConfig()` or `preprocess()`
3. Add tests in `runner/config_test.go`
4. Update `air_example.toml` and README.md

**CLI flags** (`runner/flag.go`):
1. Add flag parsing in `ParseConfigFlag()`
2. Update help text
3. Update main.go if needed
4. Document in README.md

**Watcher behavior** (`runner/watcher.go`):
- Add tests for file events (create/delete/move)
- Test include/exclude patterns
- Verify debouncing logic

**Proxy/browser reload** (`runner/proxy*.go`):
- Keep proxy injection logic minimal
- Test chunked transfer encoding edge cases
- Update README proxy section if behavior changes

## Linting Configuration

Linters enabled (`.golangci.yml`):
- `copyloopvar` - Detect loop variable capture issues
- `errcheck` - Check unchecked errors
- `ineffassign` - Detect ineffectual assignments
- `misspell` - Catch common spelling mistakes
- `revive` - General Go linting
- `staticcheck` - Static analysis
- `testifylint` - Best practices for testify
- `unconvert` - Remove unnecessary conversions
- `unused` - Find unused code

**Note:** Pre-commit hook runs `hack/check.sh` automatically on staged files.

## Development Workflow

1. **Before making changes:**
   - Run `make init` once to set up tools
   - Read the relevant README (root or `air/README.md`)

2. **During development:**
   - Make focused, minimal changes
   - Keep behavior backward-compatible unless explicitly changing it
   - Add tests for new behavior or bug fixes

3. **Before committing:**
   - Run `make check` (or rely on pre-commit hook)
   - Run `go test ./...` to verify tests pass
   - Update documentation if user-facing changes

4. **Commit messages:**
   - Use imperative mood: "Fix proxy timeout" not "Fixed" or "Fixes"
   - Be concise but descriptive
   - Reference issue numbers when applicable

## Adding New Reproduction Examples

1. Create a new directory with a descriptive name (e.g., `issue-123-description/`)
2. Include minimal files:
   - `.air.toml` - Air configuration
   - `go.mod` - Go module definition
   - `README.md` - Expected vs actual behavior, ports, trigger steps
   - `main.go` or `server.go` - Minimal reproduction code
3. Test that `air` runs from that directory
4. Update root `README.md` with one-line description
5. Link to upstream Air issue in PR

## AI Coding Agent Specifics

**Planning:**
- For multi-step tasks, create a plan before executing
- State what you're about to do before running commands
- Mark progress as you complete steps

**File Operations:**
- Read files before editing them
- Prefer targeted edits over full rewrites
- Don't reformat unrelated code

**Searches:**
- Use `rg` (ripgrep) for fast content searches
- Use `fd` or `find` for file searches
- Read files in manageable chunks

**Validation:**
- Run `make check` to verify Go formatting and linting
- Run `go test ./...` to ensure tests pass
- Test the actual Air binary with reproduction examples when fixing bugs

**Scope Control:**
- Avoid touching files unrelated to the task
- Don't add dependencies without explicit need
- Keep changes minimal and focused

## References

- Air upstream: https://github.com/air-verse/air
- Go testing: https://pkg.go.dev/testing
- golangci-lint: https://golangci-lint.run/

---

**Questions?** Open an issue or check existing issues before implementing major changes.
