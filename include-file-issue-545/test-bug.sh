#!/bin/bash
# Test script to demonstrate issue #545

set -e

echo "=========================================="
echo "Testing Air Issue #545 Reproduction"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Clean up any previous runs
rm -rf tmp
pkill -f "include-file-issue-545" 2>/dev/null || true

echo "Step 1: Starting Air in background..."
air > air.log 2>&1 &
AIR_PID=$!
echo "Air started with PID: $AIR_PID"

# Wait for app to start
sleep 3

echo ""
echo "Step 2: Verify app is running..."
curl -s http://localhost:8080/health
echo ""

echo ""
echo "Step 3: Check initial file content..."
curl -s http://localhost:8080 | grep "myfile.txt"
echo ""

echo ""
echo "Step 4: Modify myfile.txt (should trigger rebuild but won't - BUG!)..."
echo "Updated content - version 2" > myfile.txt
echo "Waiting 3 seconds for rebuild..."
sleep 3

echo ""
echo "Step 5: Check if content updated (it won't - demonstrating the bug)..."
curl -s http://localhost:8080 | grep "myfile.txt"
echo ""

echo ""
echo "Step 6: Modify Makefile (should trigger rebuild but won't - BUG!)..."
echo -e ".PHONY: build\n\nbuild:\n\tgo build ." > Makefile
echo "Waiting 3 seconds for rebuild..."
sleep 3

echo ""
echo "Step 7: Check if Makefile content updated (it won't - demonstrating the bug)..."
curl -s http://localhost:8080 | grep -A1 "Makefile"
echo ""

echo ""
echo "Step 8: Modify main.go (should trigger rebuild and will - works correctly)..."
sed -i 's/Visit http/Access http/' main.go
echo "Waiting 3 seconds for rebuild..."
sleep 3

echo ""
echo "Step 9: Verify rebuild happened (new start time) but old file content remains..."
curl -s http://localhost:8080
echo ""

echo ""
echo "=========================================="
echo "Cleaning up..."
kill $AIR_PID 2>/dev/null || true
pkill -f "include-file-issue-545" 2>/dev/null || true

# Restore original files
echo "Initial content - version 1" > myfile.txt
cat > Makefile << 'EOF'
.PHONY: build test clean

build:
	go build -o bin/app .

test:
	go test ./...

clean:
	rm -rf bin tmp
EOF

sed -i 's/Access http/Visit http/' main.go

echo "Test complete. Check air.log for Air's output."
echo "=========================================="
