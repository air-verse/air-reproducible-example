package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

const DELAY_BEFORE_START = 1

func main() {
	// Sleep before starting the server
	fmt.Printf("Waiting %d second(s) before starting hello world server...", DELAY_BEFORE_START)
	time.Sleep(DELAY_BEFORE_START * time.Second)
	fmt.Println("")

	// Simple hello world handler
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprintf(w, `<!DOCTYPE html>
			<html>
			<head>
			    <title>Hello World</title>
			</head>
			<body>
			    <h1>Hello, World!</h1>
			</body>
			</html>`)
		log.Printf("Request received: %s %s", r.Method, r.URL.Path)
	})

	// Start the server on port 7777
	fmt.Println("Hello world server starting on :7777")
	if err := http.ListenAndServe(":7777", nil); err != nil {
		log.Fatalf("Failed to start hello world server: %v", err)
	}
}
