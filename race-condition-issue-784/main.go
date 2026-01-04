package main

import (
	"fmt"
	"log"
	"net/http"
)

// BuildTime will be injected at compile time via -ldflags
// This is the REAL compile time, not the startup time
var BuildTime string

func main() {
	fmt.Printf("========================================\n")
	fmt.Printf("🚀 Server started\n")
	fmt.Printf("📅 BUILD TIME: %s\n", BuildTime)
	fmt.Printf("📦 HELPER VERSION: %s\n", getVersion())
	fmt.Printf("========================================\n")

	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		response := fmt.Sprintf("Build Time: %s\nHelper Version: %s\n", BuildTime, getVersion())
		fmt.Fprint(w, response)
		log.Printf("Version check - Build: %s, Helper: %s", BuildTime, getVersion())
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! Build Time: %s, Helper: %s\n", BuildTime, getVersion())
	})

	log.Println("Server listening on :8080")
	log.Printf("Try: curl http://localhost:8080/version")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
