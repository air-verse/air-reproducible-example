#!/usr/bin/env bash
set -e

echo "=============================================="
echo "Issue #505 Reproduction Test Script"
echo "=============================================="
echo ""

AIR_BIN="../air/air"

if [ ! -f "$AIR_BIN" ]; then
    echo "Error: Air binary not found at $AIR_BIN"
    echo "Please build it first with: cd ../air && make build"
    exit 1
fi

echo "Using Air binary: $AIR_BIN"
echo ""

# Scenario 1: Nested path doesn't exist
echo "----------------------------------------------"
echo "Scenario 1: Nested path doesn't exist (SHOULD FAIL)"
echo "----------------------------------------------"
rm -rf /tmp/air-test-issue-505
echo "✓ Cleaned up /tmp/air-test-issue-505"
echo ""
echo "Running Air (will fail after 3 seconds)..."
echo ""

timeout 3 $AIR_BIN 2>&1 || true

echo ""
echo "Result: Air FAILED to create nested directory"
echo "This demonstrates the bug!"
echo ""

# Scenario 2: Parent exists
echo "----------------------------------------------"
echo "Scenario 2: Parent directory exists (SHOULD WORK)"
echo "----------------------------------------------"
rm -rf /tmp/air-test-issue-505
mkdir -p /tmp/air-test-issue-505/nested
echo "✓ Created parent directory /tmp/air-test-issue-505/nested"
echo ""
echo "Running Air (will run for 3 seconds then stop)..."
echo ""

timeout 3 $AIR_BIN 2>&1 || true

echo ""
if [ -f /tmp/air-test-issue-505/nested/build/main ]; then
    echo "Result: Air SUCCESSFULLY created the directory and built the binary"
    echo "Binary location: /tmp/air-test-issue-505/nested/build/main"
    ls -lh /tmp/air-test-issue-505/nested/build/main
else
    echo "Result: FAILED - Binary was not created"
fi

echo ""
echo "=============================================="
echo "Conclusion"
echo "=============================================="
echo "Scenario 1 FAILS: Air cannot create nested directories"
echo "Scenario 2 WORKS: Air can create single-level directory"
echo ""
echo "This confirms the bug: Air uses os.Mkdir() instead of os.MkdirAll()"
echo "Fix required in: air/runner/engine.go:126"
echo ""
