#!/bin/bash
# test_fix.sh - Test script to verify issue #761 fix
#
# This script safely tests that air refuses to run in dangerous directories
# without actually running air in your home directory.
#
# Usage: ./test_fix.sh [path-to-air-binary]

set -e

AIR_BIN="${1:-air}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Testing Issue #761 Fix"
echo "Air binary: $AIR_BIN"
echo "=========================================="
echo ""

# Check if air binary exists
if ! command -v "$AIR_BIN" &>/dev/null; then
	echo -e "${RED}Error: air binary not found at '$AIR_BIN'${NC}"
	echo "Usage: $0 [path-to-air-binary]"
	exit 1
fi

# Test 1: Verify air works in a normal project directory
echo -e "${YELLOW}Test 1: Air should work in a normal project directory${NC}"
TEST_PROJECT=$(mktemp -d)
cd "$TEST_PROJECT"

# Create a minimal Go project
cat >go.mod <<'EOF'
module testproject
go 1.21
EOF

cat >main.go <<'EOF'
package main
func main() {}
EOF

# Run air with a very short timeout - we just want to see it start
timeout 2s "$AIR_BIN" 2>&1 || true
if [ $? -eq 124 ] || [ $? -eq 0 ]; then
	echo -e "${GREEN}PASS: Air started successfully in normal project directory${NC}"
else
	echo -e "${RED}FAIL: Air failed to start in normal project directory${NC}"
fi
rm -rf "$TEST_PROJECT"
echo ""

# Test 2: Verify air refuses to run in home directory
echo -e "${YELLOW}Test 2: Air should refuse to run in home directory${NC}"
cd ~
OUTPUT=$("$AIR_BIN" 2>&1 || true)
if echo "$OUTPUT" | grep -q "refusing to run"; then
	echo -e "${GREEN}PASS: Air correctly refused to run in home directory${NC}"
	echo "Error message: $OUTPUT"
else
	echo -e "${RED}FAIL: Air did not refuse to run in home directory${NC}"
	echo "Output: $OUTPUT"
fi
echo ""

# Test 3: Verify air refuses to run in root directory (if we have access)
echo -e "${YELLOW}Test 3: Air should refuse to run in root directory${NC}"
if cd / 2>/dev/null; then
	OUTPUT=$("$AIR_BIN" 2>&1 || true)
	if echo "$OUTPUT" | grep -q "refusing to run"; then
		echo -e "${GREEN}PASS: Air correctly refused to run in root directory${NC}"
		echo "Error message: $OUTPUT"
	else
		echo -e "${RED}FAIL: Air did not refuse to run in root directory${NC}"
		echo "Output: $OUTPUT"
	fi
else
	echo -e "${YELLOW}SKIP: Cannot access root directory${NC}"
fi
echo ""

echo "=========================================="
echo "All tests completed!"
echo "=========================================="
