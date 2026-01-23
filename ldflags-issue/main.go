package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

var Version = "unknown"
var BuildTime = "unknown"

func main() {
	startTime := time.Now()

	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "Version: %s\n", Version)
		fmt.Fprintf(w, "BuildTime: %s\n", BuildTime)
		fmt.Fprintf(w, "Started: %s\n", startTime.Format(time.RFC3339))
	})

	log.Printf("starting server on :8080 (version=%s build_time=%s)", Version, BuildTime)
	log.Fatal(http.ListenAndServe(":8080", nil))
}
