#!/bin/bash
# Interactive demonstration of manual restart mode
# This script helps you manually verify the 'r' key functionality

echo "========================================================================"
echo "   Air Manual Restart Mode - Interactive Demonstration"
echo "========================================================================"
echo ""
echo "This demo will help you verify the 'r' key functionality works correctly."
echo ""
echo "What will happen:"
echo "  1. Air starts in manual mode"
echo "  2. Server takes 5 seconds to initialize (simulating slow startup)"
echo "  3. You'll edit main.go"
echo "  4. Observe: NO automatic restart"
echo "  5. Press 'r' key to manually trigger restart"
echo "  6. Observe: Restart happens with your changes"
echo ""
echo "Press Ctrl+C to stop Air at any time."
echo ""
echo "------------------------------------------------------------------------"
read -p "Press ENTER to start Air in manual mode..."

# Clean up from previous runs
rm -rf tmp/

# Start Air
echo ""
echo "🚀 Starting Air with manual restart mode..."
echo "------------------------------------------------------------------------"
echo ""

../air/air
