#!/bin/bash
#
# Test script to reproduce issue #744
# Air randomly outputs same thing on either stdout and stderr
#
# Reference:
#   - https://github.com/air-verse/air/issues/744
#   - https://github.com/brocode/fblog/issues/115
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Clean up from previous runs
rm -f stdout.log stderr.log main
rm -rf tmp

echo "=== Issue #744 Reproduction Test ==="
echo "Air randomly outputs same thing on either stdout and stderr"
echo ""

# Ensure dependencies are downloaded
if [ ! -f "go.sum" ]; then
	echo "Running go mod tidy..."
	go mod tidy
fi

echo "Starting Air with stdout/stderr separation..."
echo "  stdout -> stdout.log"
echo "  stderr -> stderr.log"
echo ""

# Start air in background, separating stdout and stderr
air 2>stderr.log 1>stdout.log &
AIR_PID=$!

# Give air time to start, build, and generate some log output
echo "Waiting for Air to start and generate logs (10s)..."
sleep 10

# Stop air gracefully
echo "Stopping Air..."
kill $AIR_PID 2>/dev/null || true
wait $AIR_PID 2>/dev/null || true

# Analyze output
echo ""
echo "=========================================="
echo "=== ANALYSIS RESULTS ==="
echo "=========================================="

STDOUT_LINES=$(wc -l <stdout.log 2>/dev/null || echo "0")
STDERR_LINES=$(wc -l <stderr.log 2>/dev/null || echo "0")

echo ""
echo "--- stdout.log ($STDOUT_LINES lines) ---"
head -30 stdout.log 2>/dev/null || echo "(empty)"

echo ""
echo "--- stderr.log ($STDERR_LINES lines) ---"
head -30 stderr.log 2>/dev/null || echo "(empty)"

echo ""
echo "=========================================="
echo "=== JSON Parsing Test (simulating jq) ==="
echo "=========================================="

# Count JSON lines in each file
STDOUT_JSON=$(grep -c '^\s*{' stdout.log 2>/dev/null || echo "0")
STDERR_JSON=$(grep -c '^\s*{' stderr.log 2>/dev/null || echo "0")

echo "JSON lines in stdout: $STDOUT_JSON"
echo "JSON lines in stderr: $STDERR_JSON"

echo ""
echo "=========================================="
echo "=== VERDICT ==="
echo "=========================================="

if [ "$STDERR_LINES" -gt 0 ]; then
	echo "BUG CONFIRMED: Air wrote $STDERR_LINES lines to stderr!"
	echo ""
	echo "This breaks pipe commands like:"
	echo "  air | jq -R 'try fromjson catch .'"
	echo "  air | fblog"
	echo ""
	echo "Workaround: air 2>&1 | your-command"
	echo ""

	if [ "$STDERR_JSON" -gt 0 ]; then
		echo "CRITICAL: $STDERR_JSON JSON log lines went to stderr!"
		echo "These would be missed by JSON formatters piped to stdout."
	fi
	exit 1
else
	echo "OK: All Air output went to stdout ($STDOUT_LINES lines)"
	echo "Bug may not be reproducible in this scenario."
	exit 0
fi
