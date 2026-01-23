# Issue #667 - Brotli Compression Breaks Proxy Script Injection

Related: https://github.com/air-verse/air/issues/667

## Problem

Air's proxy feature injects a live reload script into HTML responses.
When the backend compresses the response with **brotli** (`Content-Encoding: br`),
the proxy cannot decompress it, so it fails to find `</body>` and skips injection.

**Note:** gzip compression was fixed in PR #876. Brotli is NOT yet supported.

## Expected vs Actual

| Encoding | Expected | Actual |
|----------|----------|--------|
| None     | Script injected ✓ | Script injected ✓ |
| gzip     | Script injected ✓ | Script injected ✓ (after PR #876) |
| brotli   | Script injected ✓ | Script NOT injected ✗ |

## Reproduction Steps

1. Build Air from source (or use latest with gzip fix):
   ```bash
   cd ../air && make build
   ```

2. Run the reproduction server with Air:
   ```bash
   ../air/air
   ```

3. Open in browser: http://localhost:3001

4. View Page Source (`Ctrl+U` or `Cmd+Option+U`)

5. Search for `__air_internal`

6. **Bug confirmed if NOT found**

## Workaround

Disable brotli compression in your Go server when using Air proxy:

```go
// Skip brotli when running in development
if os.Getenv("AIR_DEV") != "" {
    // Don't compress
}
```

## Technical Root Cause

In `runner/proxy.go`, the `isGzipEncoded()` function only handles gzip:

```go
func isGzipEncoded(header http.Header) bool {
    // Only checks for "gzip" or "x-gzip"
    // Returns false for "br" (brotli)
}
```

When `Content-Encoding: br` is present, `isGzipEncoded()` returns `false`,
so the proxy reads the raw brotli bytes and fails to find `</body>`.

## Ports

- App port: 3000 (direct access, bypassing proxy)
- Proxy port: 3001 (access through Air proxy)
