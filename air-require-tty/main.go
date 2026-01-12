package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

// Version can be changed to test hot reload
const Version = "v2"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello, World! %s\n", Version)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "OK\n")
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	fmt.Printf("[%s] Server starting on :%s (version: %s)\n",
		time.Now().Format("15:04:05"), port, Version)

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Printf("Error starting server: %v\n", err)
		os.Exit(1)
	}
}
