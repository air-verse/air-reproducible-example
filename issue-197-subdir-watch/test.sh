#!/bin/bash
# Quick test script for Issue #197 reproduction

set -e

cd "$(dirname "$0")"

echo "==================================================================="
echo "Issue #197 Reproduction Test Script"
echo "==================================================================="
echo ""

# Check if air is installed
if ! command -v air &>/dev/null; then
	echo "❌ Error: 'air' command not found"
	echo "   Please install air first:"
	echo "   cd ../air && make install"
	exit 1
fi

echo "✅ Air found: $(which air)"
echo ""

# Check environment
echo "Environment Info:"
echo "  - OS: $(uname -s)"
echo "  - Kernel: $(uname -r)"
echo "  - Working Dir: $(pwd)"
echo "  - Absolute Path: $(realpath .)"
echo ""

# Check if WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
	echo "⚠️  WSL detected!"
	if [[ "$(pwd)" == /mnt/* ]]; then
		echo "   Path is on Windows filesystem (/mnt/...) - Bug will likely occur"
		echo "   Recommendation: Use poll=true in .air.toml"
	else
		echo "   Path is on Linux filesystem - Bug may not occur"
	fi
else
	echo "ℹ️  Not running on WSL"
fi
echo ""

echo "==================================================================="
echo "Test Instructions:"
echo "==================================================================="
echo ""
echo "1. Start Air (in this terminal):"
echo "   air"
echo ""
echo "2. Verify the log shows:"
echo "   watching ."
echo "   watching cmd"
echo "   watching cmd/app"
echo ""
echo "3. In another terminal, test the server:"
echo "   curl http://localhost:8080"
echo ""
echo "4. Modify cmd/app/main.go:"
echo "   - Change 'version := \"v1\"' to 'version := \"v2\"'"
echo "   - Save the file"
echo ""
echo "5. Check if Air detects the change:"
echo "   ✅ Expected: Air rebuilds automatically"
echo "   ❌ Bug: Air does not respond (especially on WSL2 /mnt/...)"
echo ""
echo "6. If bug occurs, try the workaround:"
echo "   - Uncomment 'poll = true' in .air.toml"
echo "   - Restart Air"
echo "   - Try modifying main.go again"
echo ""
echo "==================================================================="
echo ""

read -p "Press Enter to start Air now, or Ctrl+C to cancel..."

exec air
