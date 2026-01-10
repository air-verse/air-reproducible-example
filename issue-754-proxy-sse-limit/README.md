# Air Issue 754 Reproduction

This example reproduces [air-verse/air#754](https://github.com/air-verse/air/issues/754): proxy hangs when the browser hits the SSE stream limit (usually 6 per host).

## Prerequisites

- Go 1.21+
- Air installed: `go install github.com/air-verse/air@latest`

## Steps to Reproduce

1. Start Air from this directory:
   ```bash
   cd issue-754-proxy-sse-limit
   air
   ```
2. Open the proxied page in a browser:
   ```
   http://localhost:8081
   ```
3. Open 7 tabs (use the "Open another tab" link on the page).
4. Observe the 7th tab hanging for ~1 minute before it loads.

## Expected vs Actual

- Expected: All tabs load immediately.
- Actual: The 7th tab hangs until the browser can free an EventSource slot.

## Notes

Each tab creates an injected EventSource connection via Air's proxy. Most browsers cap EventSource connections to 6 per host, so the 7th connection blocks until the cleanup logic releases a slot.
