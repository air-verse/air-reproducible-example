package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	// Read content from myfile.txt
	content, err := os.ReadFile("myfile.txt")
	if err != nil {
		log.Printf("Warning: could not read myfile.txt: %v", err)
		content = []byte("(file not found)")
	}

	// Read Makefile content
	makefileContent, err := os.ReadFile("Makefile")
	if err != nil {
		log.Printf("Warning: could not read Makefile: %v", err)
		makefileContent = []byte("(file not found)")
	}

	startTime := time.Now()

	log.Printf("===========================================")
	log.Printf("App started at: %s", startTime.Format("15:04:05.000"))
	log.Printf("myfile.txt content: %s", string(content))
	log.Printf("Makefile content: %s", string(makefileContent))
	log.Printf("===========================================")

	// Simple HTTP server
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "App started: %s\n", startTime.Format("15:04:05.000"))
		fmt.Fprintf(w, "myfile.txt: %s\n", string(content))
		fmt.Fprintf(w, "Makefile: %s\n", string(makefileContent))
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "OK - Started at %s\n", startTime.Format("15:04:05.000"))
	})

	log.Println("Server listening on :8080")
	log.Println("Visit http://localhost:8080 to see file contents")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
