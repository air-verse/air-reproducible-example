package main

import (
	"fmt"
	"net/http"
	"time"
)

func main() {
	fmt.Println("Server starting on :3000...")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! Time: %s\n", time.Now().Format(time.RFC3339))
	})

	if err := http.ListenAndServe(":3000", nil); err != nil {
		fmt.Printf("Server error: %v\n", err)
	}
}
