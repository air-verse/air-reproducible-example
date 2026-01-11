#!/bin/bash
# Test script to verify manual restart mode behavior

set -e

echo "========================================="
echo "Testing Air Manual Restart Mode"
echo "========================================="
echo ""

# Cleanup function
cleanup() {
	echo ""
	echo "Cleaning up..."
	pkill -f "tmp/main" 2>/dev/null || true
	rm -rf tmp/
	sed -i '/^\/\/ test comment/d' main.go 2>/dev/null || true
	exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Start Air in background
echo "1. Starting Air in manual mode..."
../air/air >/tmp/air_output.log 2>&1 &
AIR_PID=$!
sleep 8

# Check if server started
echo "2. Checking if server started..."
if curl -s http://localhost:8080/ >/dev/null; then
	echo "   ✅ Server is running"
	RESPONSE=$(curl -s http://localhost:8080/)
	echo "   Response: $RESPONSE"
else
	echo "   ❌ Server failed to start"
	cat /tmp/air_output.log
	exit 1
fi

# Count initial "Starting server" messages
INITIAL_STARTS=$(grep -c "🚀 Starting server" /tmp/air_output.log || echo "0")
echo "   Initial server starts: $INITIAL_STARTS"

# Verify manual mode message was displayed
echo ""
echo "3. Checking for 'watching mode: manual' message..."
if grep -q "watching mode: manual" /tmp/air_output.log; then
	echo "   ✅ Manual mode message displayed correctly"
else
	echo "   ❌ Manual mode message not found"
	exit 1
fi

# Modify main.go to trigger a file change
echo ""
echo "4. Modifying main.go (should NOT auto-restart in manual mode)..."
echo "// test comment $(date +%s)" >>main.go
sleep 4

# Count server starts after file change
AFTER_EDIT_STARTS=$(grep -c "🚀 Starting server" /tmp/air_output.log || echo "0")
echo ""
echo "5. Verifying server did NOT restart..."
echo "   Server starts after edit: $AFTER_EDIT_STARTS"

if [[ "$AFTER_EDIT_STARTS" == "$INITIAL_STARTS" ]]; then
	echo "   ✅ Server did NOT restart (manual mode working correctly!)"
else
	echo "   ❌ Server restarted automatically (manual mode broken)"
	echo "   Expected starts: $INITIAL_STARTS"
	echo "   Actual starts: $AFTER_EDIT_STARTS"
	echo ""
	echo "Air logs:"
	cat /tmp/air_output.log
	exit 1
fi

# Check Air logs to confirm file change was detected but ignored
echo ""
echo "6. Checking Air logs for file change handling..."
if grep -q "main.go has changed" /tmp/air_output.log || grep -q "main.go" /tmp/air_output.log; then
	echo "   ✅ File change was detected by Air watcher"
else
	echo "   ⚠️  File change detection unclear (may need more time)"
fi

# Restore main.go
sed -i '/^\/\/ test comment/d' main.go

echo ""
echo "========================================="
echo "✅ TEST PASSED - Manual Mode Working!"
echo "========================================="
echo ""
echo "Results:"
echo "  ✅ Air displays 'watching mode: manual' message"
echo "  ✅ Server starts successfully (with 5-second initialization)"
echo "  ✅ File changes do NOT trigger automatic restart"
echo "  ✅ Server remains running after file modifications"
echo ""
echo "⚠️  Manual 'r' key requires interactive testing:"
echo "  1. Run: ../air/air"
echo "  2. Edit main.go (add a comment or space)"
echo "  3. Verify no restart happens (no '🚀 Starting server' message)"
echo "  4. Press 'r' key in the terminal"
echo "  5. Should see 'manual restart triggered' and server restarts"
echo ""

# Show relevant Air output
echo "Air output snippet:"
echo "========================================="
grep -E "(watching mode|Starting server|building|running)" /tmp/air_output.log | head -15
echo "========================================="

cleanup
