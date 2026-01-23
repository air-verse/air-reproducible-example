#!/bin/bash
# Issue #431 Bug Reproducer - Linux/macOS
# https://github.com/air-verse/air/issues/431
#
# Usage: ./trigger-bug.sh
#
# NOTE: This bug is primarily Windows-specific due to differences in how
# fsnotify handles file events on different platforms. This script is
# provided for comparison testing and may not reproduce the bug on Unix.

set -e

echo ""
echo "============================================"
echo " Issue #431: Double Build Bug Reproducer"
echo " Platform: $(uname -s)"
echo "============================================"
echo ""

# Check if air is available
if ! command -v air &>/dev/null; then
	echo "[ERROR] 'air' not found in PATH. Please install it first:"
	echo "  go install github.com/air-verse/air@latest"
	exit 1
fi
echo "[OK] Air found: $(which air)"

# Check if port 3000 is available
if lsof -i :3000 &>/dev/null; then
	echo "[WARNING] Port 3000 is in use. Attempting to free it..."
	pkill -f "tmp/main" 2>/dev/null || true
	sleep 1
fi

# Cleanup previous runs
echo ""
echo "[STEP 1/6] Cleaning up previous runs..."
rm -f air.log air.err
rm -rf tmp/

# Save original main.go content
ORIGINAL_CONTENT='package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	startTime := time.Now().Format("15:04:05.000")
	pid := os.Getpid()

	fmt.Printf("running... (PID: %d, started at %s)\n", pid, startTime)
	fmt.Println("Starting the server on :3000...")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! PID=%d, Started=%s\n", pid, startTime)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "OK")
	})

	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Build Time: %s\nPID: %d\n", startTime, pid)
	})

	if err := http.ListenAndServe(":3000", nil); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}'

echo "$ORIGINAL_CONTENT" >main.go
echo "[OK] Cleanup complete"

# Start air
echo ""
echo "[STEP 2/6] Starting air in background..."
air >air.log 2>&1 &
AIR_PID=$!
echo "[OK] Air started (PID: $AIR_PID)"

# Wait for initial build
echo ""
echo "[STEP 3/6] Waiting for initial build to complete..."
sleep 6
echo "[OK] Initial build should be complete"

# Trigger first reload
echo ""
echo "[STEP 4/6] Triggering first reload (single save)..."
echo "// Trigger 1: $(date +%H:%M:%S.%3N)" >>main.go
sleep 4
echo "[OK] First reload triggered"

# Trigger rapid saves
echo ""
echo "[STEP 5/6] Triggering rapid file saves (BUG TRIGGER)..."
echo "          Saving file multiple times in quick succession..."

for i in 1 2 3; do
	timestamp=$(date +%H:%M:%S.%3N)
	echo "// Rapid save $i at $timestamp" >>main.go
	echo "          Save $i at $timestamp"
	sleep 0.05 # 50ms between saves
done

echo "[OK] Rapid saves complete"

# Wait for builds
echo ""
echo "[STEP 6/6] Waiting for builds to complete..."
sleep 8

# Analyze results
echo ""
echo "============================================"
echo " ANALYSIS RESULTS"
echo "============================================"
echo ""

if [ ! -f "air.log" ]; then
	echo "[ERROR] air.log not found!"
	exit 1
fi

RUNNING_COUNT=$(grep -c "running\.\.\." air.log 2>/dev/null || echo 0)
STARTING_COUNT=$(grep -c "Starting the server" air.log 2>/dev/null || echo 0)
BIND_ERROR=$(grep -c "bind:" air.log 2>/dev/null || echo 0)

echo "  'running...' occurrences:        $RUNNING_COUNT"
echo "  'Starting the server' count:     $STARTING_COUNT"
echo "  Port bind errors:                $BIND_ERROR"
echo ""

# Check for bug indicators
BUG_REPRODUCED=false

if [ "$RUNNING_COUNT" -gt 5 ] || [ "$STARTING_COUNT" -gt 5 ] || [ "$BIND_ERROR" -gt 0 ]; then
	BUG_REPRODUCED=true
fi

if [ "$BUG_REPRODUCED" = true ]; then
	echo -e "\033[31m============================================\033[0m"
	echo -e "\033[31m BUG REPRODUCED!\033[0m"
	echo -e "\033[31m============================================\033[0m"
	echo ""
	echo -e "\033[33mWORKAROUND: Set 'delay = 10' in .air.toml\033[0m"
else
	echo -e "\033[33m============================================\033[0m"
	echo -e "\033[33m BUG NOT TRIGGERED\033[0m"
	echo -e "\033[33m============================================\033[0m"
	echo ""
	echo "This bug is primarily Windows-specific."
	echo "On Unix systems, fsnotify typically debounces events better."
	echo ""
	echo "To test on Windows:"
	echo "  1. Copy this directory to a Windows machine"
	echo "  2. Run: .\\trigger-bug.ps1"
fi

# Cleanup
echo ""
echo "[CLEANUP] Stopping processes..."
kill $AIR_PID 2>/dev/null || true
pkill -f "tmp/main" 2>/dev/null || true

# Restore main.go
echo "$ORIGINAL_CONTENT" >main.go
echo "[OK] main.go restored to original state"

echo ""
echo "Log file: air.log"
echo ""
echo "Done!"
