package main

import (
	"fmt"
	"log"
	"net/http"
	"sync/atomic"
	"time"
)

var requestCount uint64

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/health", handleHealth)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Println("listening on http://localhost:8080")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}

func handleIndex(writer http.ResponseWriter, request *http.Request) {
	count := atomic.AddUint64(&requestCount, 1)
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = fmt.Fprintf(writer, `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Air issue #754 reproduction</title>
</head>
<body>
  <h1>Air proxy SSE stream limit</h1>
  <p>Request count: %d</p>
  <ol>
    <li>Open this page through Air proxy: <code>http://localhost:8081</code></li>
    <li>Open 7 tabs (the button below helps)</li>
    <li>Notice the 7th tab hangs ~1 minute before loading</li>
  </ol>
  <p>
    <a href="/" target="_blank" rel="noopener">Open another tab</a>
  </p>
  <p>
    Each tab creates an injected EventSource connection via Air's proxy.
    Most browsers limit EventSource to 6 concurrent connections per host.
  </p>
</body>
</html>`, count)
}

func handleHealth(writer http.ResponseWriter, request *http.Request) {
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write([]byte("ok"))
}
