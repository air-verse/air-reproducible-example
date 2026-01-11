#!/bin/bash

echo "=== Testing Air Manual Mode Feature ==="
echo
echo "This will test the watch_mode = 'manual' configuration."
echo
echo "Expected behavior:"
echo "  1. Air starts in manual mode with message: 'watching mode: manual (press 'r' to restart)'"
echo "  2. Server starts (5 second initialization)"
echo "  3. Editing main.go does NOT trigger automatic restart"
echo "  4. Pressing 'r' key triggers manual restart"
echo
echo "Press Ctrl+C to exit when done testing."
echo
echo "Starting air in 3 seconds..."
sleep 3

cd "$(dirname "$0")"
../air/air
