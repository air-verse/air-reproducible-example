package main

import (
	"fmt"
	"net/http"
	"os"
	"strings"
)

func main() {
	// List of environment variables to test
	envVars := []string{
		"APP_NAME",
		"APP_PORT",
		"DEBUG",
		"BASE_URL",
		"API_URL",
		"DB_CONNECTION_STRING",
		"EMPTY_VAR",
		"MESSAGE",
	}

	fmt.Println("=== Environment Variables Loaded by Air ===")
	for _, key := range envVars {
		value := os.Getenv(key)
		if value == "" {
			fmt.Printf("%s = <empty>\n", key)
		} else {
			fmt.Printf("%s = %s\n", key, value)
		}
	}
	fmt.Println("============================================")

	// Verify variable expansion
	fmt.Println("\n=== Expansion Test ===")
	apiURL := os.Getenv("API_URL")
	expectedURL := fmt.Sprintf("%s:%s/api", os.Getenv("BASE_URL"), os.Getenv("APP_PORT"))
	if apiURL == expectedURL {
		fmt.Printf("OK: API_URL correctly expanded to: %s\n", apiURL)
	} else {
		fmt.Printf("WARN: API_URL = %s (expected: %s)\n", apiURL, expectedURL)
		fmt.Println("      Variable expansion may not be working")
	}
	fmt.Println("======================")

	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		var sb strings.Builder
		sb.WriteString("=== Env Preload Test Server ===\n\n")
		for _, key := range envVars {
			sb.WriteString(fmt.Sprintf("%s = %s\n", key, os.Getenv(key)))
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(sb.String()))
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	fmt.Printf("\nServer starting on http://localhost:%s\n", port)
	fmt.Println("Press Ctrl+C to stop")
	fmt.Println("\nTry modifying .env file to test hot reload!")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Printf("Server error: %v\n", err)
		os.Exit(1)
	}
}
