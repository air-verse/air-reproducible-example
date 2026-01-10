#!/bin/bash
# Test script demonstrating issue #545 with old Air version (before the fix)

set -e

echo "=========================================="
echo "Testing Air Issue #545 with OLD Air"
echo "Air version: v1.52.3 (before fix)"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# Clean up any previous runs
rm -rf tmp air-old.log
pkill -f "include-file-issue-545" 2>/dev/null || true
sleep 1

# Reset files to original state
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

echo "Step 1: Starting OLD Air (v1.52.3) in background..."
../air/air > air-old.log 2>&1 &
AIR_PID=$!
echo "Air started with PID: $AIR_PID"
sleep 3

echo ""
echo "Step 2: Verify app is running..."
START_TIME=$(curl -s http://localhost:8080/health | grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
echo "App started at: $START_TIME"

echo ""
echo "Step 3: Check initial file content..."
echo "myfile.txt contains: $(curl -s http://localhost:8080 | grep 'myfile.txt:' | cut -d: -f2-)"

echo ""
echo "=== DEMONSTRATING THE BUG ==="
echo "Step 4: Modify myfile.txt..."
echo "MODIFIED CONTENT - VERSION 2" > myfile.txt
echo "Waiting 4 seconds for rebuild (won't happen - this is the bug!)..."
sleep 4

echo ""
echo "Step 5: Check if rebuild happened..."
NEW_START_TIME=$(curl -s http://localhost:8080/health | grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
if [ "$START_TIME" == "$NEW_START_TIME" ]; then
    echo "✗ BUG CONFIRMED: No rebuild! Start time unchanged: $START_TIME"
    echo "✗ File content NOT updated: $(curl -s http://localhost:8080 | grep 'myfile.txt:' | cut -d: -f2-)"
else
    echo "✓ Rebuild happened (unexpected!)"
fi

echo ""
echo "Step 6: Modify Makefile (no extension)..."
echo ".PHONY: test" > Makefile
echo "Waiting 4 seconds for rebuild (won't happen - this is the bug!)..."
sleep 4

echo ""
echo "Step 7: Check if rebuild happened for Makefile..."
NEW_START_TIME2=$(curl -s http://localhost:8080/health | grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
if [ "$NEW_START_TIME" == "$NEW_START_TIME2" ]; then
    echo "✗ BUG CONFIRMED: No rebuild for Makefile! Start time unchanged: $NEW_START_TIME2"
else
    echo "✓ Rebuild happened (unexpected!)"
fi

echo ""
echo "Step 8: Now modify main.go to prove Air is still working..."
# Add a comment to trigger change
sed -i '2 i // Test comment' main.go
echo "Waiting 4 seconds for rebuild (should work for .go files)..."
sleep 4

echo ""
echo "Step 9: Verify .go file changes trigger rebuilds..."
NEW_START_TIME3=$(curl -s http://localhost:8080/health | grep -o "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
if [ "$NEW_START_TIME2" != "$NEW_START_TIME3" ]; then
    echo "✓ REBUILD WORKED for .go files! New start time: $NEW_START_TIME3"
    echo "  This proves Air is working, but NOT for include_file entries!"
else
    echo "✗ Unexpected: even .go changes didn't trigger rebuild"
fi

echo ""
echo "Step 10: Check what Air logs say..."
echo "  Air said it was 'watching myfile.txt' and 'watching Makefile'"
grep -E "(watching myfile|watching Makefile)" air-old.log || true
echo ""
echo "  But did Air detect the changes?"
grep -E "(myfile.txt has changed|Makefile has changed)" air-old.log && echo "  Changes were detected (bug not reproduced)" || echo "  ✗ NO - Changes NOT detected (BUG CONFIRMED!)"

echo ""
echo "=========================================="
echo "Cleaning up..."
kill $AIR_PID 2>/dev/null || true
pkill -f "include-file-issue-545" 2>/dev/null || true
sleep 1

# Restore files
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
sed -i '/^\/\/ Test comment$/d' main.go

echo "Test complete!"
echo "=========================================="
echo ""
echo "CONCLUSION:"
echo "  - include_file entries are listed as 'watching' but don't trigger rebuilds"
echo "  - Only include_ext entries trigger rebuilds"
echo "  - This is Air issue #545"
echo ""
echo "Check air-old.log for full Air output."
