package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	pid := os.Getpid()
	ppid := os.Getppid()
	fmt.Printf("Server starting... PID=%d, PPID=%d\n", pid, ppid)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! PID=%d, PPID=%d\n", pid, ppid)
	})

	// Graceful shutdown signal handling
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigCh
		fmt.Printf("Received signal: %v, shutting down...\n", sig)
		os.Exit(0)
	}()

	addr := ":8080"
	fmt.Printf("Listening on %s\n", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}
