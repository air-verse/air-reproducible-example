package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	startTime := time.Now().Format("15:04:05.000")
	pid := os.Getpid()

	// These messages help identify double-build issues
	// If you see these printed twice in quick succession, the bug is triggered
	fmt.Printf("running... (PID: %d, started at %s)\n", pid, startTime)
	fmt.Println("Starting the server on :3000...")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! PID=%d, Started=%s\n", pid, startTime)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "OK")
	})

	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Build Time: %s\nPID: %d\n", startTime, pid)
	})

	if err := http.ListenAndServe(":3000", nil); err != nil {
		// This error is expected when the bug triggers - two servers try to bind the same port
		log.Fatalf("Server error: %v", err)
	}
}
