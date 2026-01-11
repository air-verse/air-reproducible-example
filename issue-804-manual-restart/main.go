package main

import (
	"fmt"
	"net/http"
	"time"
)

func main() {
	fmt.Println("🚀 Starting server...")

	// Simulate connecting to multiple data sources (slow startup)
	// for i := 1; i <= 5; i++ {
	// 	fmt.Printf("   [%d/5] Connecting to data source...\n", i)
	// 	time.Sleep(1 * time.Second)
	// }

	fmt.Println("✅ Server ready on http://localhost:8080")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello at %s\n", time.Now().Format(time.RFC3339))
	})

	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Server error: %v\n", err)
	}
}
