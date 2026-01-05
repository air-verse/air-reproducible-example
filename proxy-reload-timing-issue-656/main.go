package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

var (
	// comment
	processStartTime = time.Now()
	serverReadyTime  time.Time
)

func timestamp() string {
	return time.Now().Format("15:04:05.000")
}

func main() {
	// 1. Process start - Log immediately
	fmt.Printf("[%s] ========================================\n", timestamp())
	fmt.Printf("[%s] Process started (PID: %d)\n", timestamp(), os.Getpid())
	fmt.Printf("[%s] ========================================\n", timestamp())

	// Parse startup delay from environment variable
	delayStr := os.Getenv("STARTUP_DELAY")
	if delayStr == "" {
		delayStr = "2s" // Default: 2 seconds (exceeds proxy 1s timeout)
	}
	delay, err := time.ParseDuration(delayStr)
	if err != nil {
		fmt.Printf("[%s] ERROR: Invalid STARTUP_DELAY '%s', using 2s default\n", timestamp(), delayStr)
		delay = 2 * time.Second
	}

	// 2. Before startup delay
	if delay > 0 {
		fmt.Printf("[%s] Starting initialization (delay: %v)...\n", timestamp(), delay)
		fmt.Printf("[%s] (This simulates slow app startup - database connections, config loading, etc.)\n", timestamp())
		time.Sleep(delay)
		fmt.Printf("[%s] Initialization complete!\n", timestamp())
	} else {
		fmt.Printf("[%s] No startup delay (STARTUP_DELAY=%s)\n", timestamp(), delayStr)
	}

	// 3. Setup HTTP handlers
	http.HandleFunc("/", serveIndex)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/api/time", timeHandler)

	// 4. Start server in a goroutine to log when ready
	fmt.Printf("[%s] Starting HTTP server on :8080...\n", timestamp())

	server := &http.Server{Addr: ":8080"}

	// Channel to signal server is listening
	serverReady := make(chan struct{})

	go func() {
		// Small delay to ensure ListenAndServe has started
		time.Sleep(10 * time.Millisecond)

		// Try to connect to ourselves to verify server is ready
		for i := 0; i < 50; i++ {
			resp, err := http.Get("http://localhost:8080/health")
			if err == nil {
				resp.Body.Close()
				serverReadyTime = time.Now()
				close(serverReady)
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
		// Fallback - assume ready if we can't verify
		serverReadyTime = time.Now()
		close(serverReady)
	}()

	// Start server
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Wait for server to be ready
	<-serverReady
	elapsed := serverReadyTime.Sub(processStartTime)
	fmt.Printf("[%s] ========================================\n", timestamp())
	fmt.Printf("[%s] ✓ Server ready to accept connections!\n", timestamp())
	fmt.Printf("[%s] ✓ Listening on http://localhost:8080\n", timestamp())
	fmt.Printf("[%s] ✓ Time from process start to ready: %v\n", timestamp(), elapsed)
	fmt.Printf("[%s] ========================================\n", timestamp())
	fmt.Printf("[%s] \n", timestamp())
	fmt.Printf("[%s] IMPORTANT: Air's proxy triggers browser reload IMMEDIATELY when process starts\n", timestamp())
	fmt.Printf("[%s] This means the browser tried to reload %.0fms BEFORE the server was ready!\n", timestamp(), elapsed.Seconds()*1000)
	fmt.Printf("[%s] Air's proxy only retries for 1000ms (10 x 100ms)\n", timestamp())
	if elapsed.Milliseconds() > 1000 {
		fmt.Printf("[%s] ⚠️  RESULT: Browser will show 'proxy handler: unable to reach app' error\n", timestamp())
	} else {
		fmt.Printf("[%s] ✓ RESULT: Browser reload might succeed (but could race)\n", timestamp())
	}
	fmt.Printf("[%s] \n", timestamp())
	fmt.Printf("[%s] Access the app through Air's proxy at: http://localhost:8081\n", timestamp())
	fmt.Printf("[%s] Press Ctrl+C to stop\n", timestamp())
	fmt.Printf("[%s] ========================================\n", timestamp())

	// Graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	fmt.Printf("\n[%s] Shutting down gracefully...\n", timestamp())
}

func serveIndex(w http.ResponseWriter, r *http.Request) {
	logRequest(r, http.StatusOK)

	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Serve static file directly
	http.ServeFile(w, r, "static/index.html")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	uptime := time.Since(processStartTime)
	var startupTime float64
	if !serverReadyTime.IsZero() {
		startupTime = serverReadyTime.Sub(processStartTime).Seconds()
	}

	health := map[string]interface{}{
		"status":          "healthy",
		"pid":             os.Getpid(),
		"uptime_seconds":  uptime.Seconds(),
		"startup_seconds": startupTime,
		"process_started": processStartTime.Format(time.RFC3339Nano),
		"server_ready":    serverReadyTime.Format(time.RFC3339Nano),
		"current_time":    time.Now().Format(time.RFC3339Nano),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(health)

	logRequest(r, http.StatusOK)
}

func timeHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"timestamp": time.Now().Format(time.RFC3339Nano),
		"unix":      time.Now().Unix(),
		"unix_nano": time.Now().UnixNano(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)

	logRequest(r, http.StatusOK)
}

func logRequest(r *http.Request, statusCode int) {
	fmt.Printf("[%s] %s %s - %d\n", timestamp(), r.Method, r.URL.Path, statusCode)
}
