package main

import (
	"fmt"
	"net/http"
	"time"
)

func main() {
	version := "v2" // Modify this value to test hot reload

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from %s at %s\n", version, time.Now().Format(time.RFC3339))
	})

	fmt.Printf("Server starting with version %s on :8080\n", version)
	http.ListenAndServe(":8080", nil)
}
