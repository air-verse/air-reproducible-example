package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	// Create a Gin router with default middleware (logger and recovery)
	r := gin.Default()

	fmt.Println("Starting server...")

	// Define a simple GET endpoint
	r.GET("/", func(c *gin.Context) {
		fmt.Println("Home page requested")
		// Return JSON response
		c.String(http.StatusOK, "Hello, World!")
	})

	// Start server on port 8080 (default)
	// Server will listen on 0.0.0.0:8080 (localhost:8080 on Windows)
	if err := r.Run(); err != nil {
		log.Fatalf("failed to run server: %v", err)
	}
}
