package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/andybalholm/brotli"
)

const htmlTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Issue #667 - %s Encoding Test</title>
</head>
<body>
  <h1>%s Encoding Test</h1>
  <p>Content-Encoding: <code>%s</code></p>
  <p>Check page source for <code>__air_internal</code> to verify script injection.</p>
  <hr>
  <h2>Test Links (via proxy port 3001):</h2>
  <ul>
    <li><a href="/plain">/plain</a> - No compression (should work)</li>
    <li><a href="/brotli">/brotli</a> - Brotli compression (BUG: script not injected)</li>
  </ul>
</body>
</html>`

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/plain", handlePlain)
	mux.HandleFunc("/brotli", handleBrotli)

	log.Println("Server listening on http://localhost:3000")
	log.Println("Access via Air proxy: http://localhost:3001")
	log.Println("")
	log.Println("Test endpoints:")
	log.Println("  http://localhost:3001/plain   - No compression (should inject script)")
	log.Println("  http://localhost:3001/brotli  - Brotli (BUG: no script injection)")
	if err := http.ListenAndServe(":3000", mux); err != nil {
		log.Fatal(err)
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Issue #667 Reproduction</title></head>
<body>
  <h1>Issue #667 - Brotli Breaks Proxy Script Injection</h1>
  <p>Click each link and view page source (Ctrl+U) to check for <code>__air_internal</code>:</p>
  <ul>
    <li><a href="/plain">/plain</a> - Expected: script injected</li>
    <li><a href="/brotli">/brotli</a> - Expected: script NOT injected (BUG)</li>
  </ul>
</body>
</html>`)
}

func handlePlain(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, htmlTemplate, "Plain", "Plain", "none")
}

func handleBrotli(w http.ResponseWriter, r *http.Request) {
	// Check if client accepts brotli
	acceptEncoding := r.Header.Get("Accept-Encoding")
	if !strings.Contains(acceptEncoding, "br") {
		// Fallback to plain HTML if client doesn't support brotli
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(w, htmlTemplate, "Brotli (fallback)", "Brotli", "none (client doesn't support br)")
		return
	}

	// Serve brotli-compressed response
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Encoding", "br")

	br := brotli.NewWriter(w)
	defer br.Close()
	fmt.Fprintf(br, htmlTemplate, "Brotli", "Brotli", "br")
}
