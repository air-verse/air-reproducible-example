#!/bin/bash

# Simple test to verify the race condition bug
# This shows which version is running

echo "==================================="
echo "Race Condition Bug #784 - Simple Test"
echo "==================================="
echo ""

# Check if server is running
if ! curl -s http://localhost:8080/version > /dev/null 2>&1; then
    echo "❌ Server is not running on port 8080"
    echo "Please start air in another terminal first:"
    echo "  cd $(pwd)"
    echo "  air"
    exit 1
fi

echo "✓ Server is running"
echo ""

# Backup files
cp main.go main.go.simple-bak 2>/dev/null || true
cp helper.go helper.go.simple-bak 2>/dev/null || true

echo "Step 1: Triggering Build A..."
echo "  - Modifying main.go (add comment)"
echo "  - Setting helper.go version to v1.0.0-BUILD-A"
echo ""

# Trigger Build A
echo "// Build A - $(date)" >> main.go
sed -i 's/return "v[^"]*"/return "v1.0.0-BUILD-A"/g' helper.go

BUILD_A_TIME=$(date +%H:%M:%S)
echo "  ✓ Build A triggered at $BUILD_A_TIME"
echo "  ⏱  Build A will take ~10 seconds to complete"
echo ""

sleep 2

echo "Step 2: Triggering Build B (while Build A is still running)..."
echo "  - Setting helper.go version to v2.0.0-BUILD-B"
echo ""

# Trigger Build B
sed -i 's/return "v[^"]*"/return "v2.0.0-BUILD-B"/g' helper.go

BUILD_B_TIME=$(date +%H:%M:%S)
echo "  ✓ Build B triggered at $BUILD_B_TIME"
echo ""

echo "Step 3: Waiting for builds to complete..."
sleep 15

echo ""
echo "==================================="
echo "RESULTS"
echo "==================================="
echo ""

# Get server response
RESPONSE=$(curl -s http://localhost:8080/version)
echo "Server response:"
echo "$RESPONSE"
echo ""

# Extract helper version
HELPER_VERSION=$(echo "$RESPONSE" | grep "Helper Version:" | sed 's/Helper Version: //' | tr -d '\n\r')

echo "Analysis:"
echo "  Build A triggered: $BUILD_A_TIME (version: v1.0.0-BUILD-A)"
echo "  Build B triggered: $BUILD_B_TIME (version: v2.0.0-BUILD-B)"
echo "  Server running:    $HELPER_VERSION"
echo ""

if echo "$HELPER_VERSION" | grep -q "BUILD-A"; then
    echo "🐛 BUG DETECTED!"
    echo "  → Server is running Build A (OLD code)"
    echo "  → Build B was cancelled by the race condition"
    echo "  → Latest changes are NOT running"
elif echo "$HELPER_VERSION" | grep -q "BUILD-B"; then
    echo "✓ NO BUG"
    echo "  → Server is running Build B (LATEST code)"
    echo "  → Bug was not reproduced (or has been fixed)"
else
    echo "⚠ Unknown version: $HELPER_VERSION"
fi

echo ""
echo "==================================="

# Ask about cleanup
echo ""
read -p "Restore original files? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv main.go.simple-bak main.go 2>/dev/null || true
    mv helper.go.simple-bak helper.go 2>/dev/null || true
    echo "✓ Files restored"
else
    echo "Files not restored. To restore manually:"
    echo "  mv main.go.simple-bak main.go"
    echo "  mv helper.go.simple-bak helper.go"
fi
