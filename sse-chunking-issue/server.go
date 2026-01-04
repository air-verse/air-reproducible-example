package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	// Serve static files
	r.Static("/static", "./static")

	// Homepage - serves the HTML client
	r.GET("/", func(c *gin.Context) {
		c.File("./static/index.html")
	})

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	})

	// Ping endpoint
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})

	// SSE endpoint - emits events every 3 seconds
	r.GET("/sse", func(c *gin.Context) {
		// Set SSE headers
		c.Header("Content-Type", "text/event-stream")
		c.Header("Cache-Control", "no-cache")
		c.Header("Connection", "keep-alive")

		// Get the ResponseWriter flusher
		flusher, ok := c.Writer.(http.Flusher)
		if !ok {
			c.String(http.StatusInternalServerError, "Streaming not supported")
			return
		}

		// Stream events indefinitely
		c.Stream(func(w io.Writer) bool {
			// Static iteration counter
			iteration := 0

			ticker := time.NewTicker(3 * time.Second)
			defer ticker.Stop()

			for {
				select {
				case <-c.Request.Context().Done():
					// Client disconnected
					log.Println("Client disconnected from SSE")
					return false
				case <-ticker.C:
					// Create the event payload
					// Format: event: datastar-patch-signals\ndata: signals {"ssetstsignal":{"iteration":"N"}}\n\n
					// Target size: 0x50 (80 bytes) total

					event := fmt.Sprintf("event: datastar-patch-signals\ndata: signals {\"ssetstsignal\":{\"iteration\":\"%d\"}}\n\n", iteration)

					// Pad to exactly 80 bytes (0x50)
					targetSize := 80
					currentSize := len(event)

					if currentSize < targetSize {
						// Add padding spaces before the final \n\n
						padding := strings.Repeat(" ", targetSize-currentSize)
						event = fmt.Sprintf("event: datastar-patch-signals\ndata: signals {\"ssetstsignal\":{\"iteration\":\"%d\"}}%s\n\n", iteration, padding)
					}

					// Write the event
					_, err := w.Write([]byte(event))
					if err != nil {
						log.Printf("Error writing SSE event: %v", err)
						return false
					}

					// Flush immediately after writing
					flusher.Flush()

					log.Printf("Sent SSE event: iteration=%d, size=%d bytes", iteration, len(event))
					iteration++
				}
			}
		})
	})

	// Start server
	port := ":3002"
	log.Printf("Starting server on port %s", port)
	log.Printf("Access the demo at: http://localhost:3002/")
	log.Printf("SSE endpoint: http://localhost:3002/sse")
	log.Printf("With Air proxy: http://localhost:3082/")

	if err := r.Run(port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
