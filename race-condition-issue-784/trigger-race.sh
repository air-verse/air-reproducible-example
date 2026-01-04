#!/bin/bash

# ============================================================================
# trigger-race.sh - Manual-Assisted Race Condition Bug #784 Reproducer
# ============================================================================
# This script triggers Build A and Build B at the right timing while you
# watch air's output in another terminal.
#
# Usage:
#   Terminal 1: air
#   Terminal 2: ./trigger-race.sh
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
TRIGGER_DELAY=2  # Seconds to wait before triggering Build B

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "${BOLD}${MAGENTA}"
    echo "════════════════════════════════════════════════════════════════"
    echo "$1"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BOLD}${CYAN}▶${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_observe() {
    echo -e "${CYAN}${BOLD}👁 OBSERVE:${NC} $1"
}

countdown() {
    local seconds=$1
    local message=$2
    for ((i=seconds; i>0; i--)); do
        echo -ne "\r${YELLOW}${message} ${i}s...${NC}  "
        sleep 1
    done
    echo -ne "\r${GREEN}${message} NOW!${NC}     \n"
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

print_header "🎯 Race Condition Bug #784 - Manual Trigger Script"

print_step "Running pre-flight checks..."

# Check if we're in the right directory
if [ ! -f "main.go" ] || [ ! -f "helper.go" ] || [ ! -f ".air.toml" ]; then
    print_error "This script must be run from the race-condition-issue-784 directory"
    exit 1
fi
print_success "Correct directory confirmed"

# Check if air is installed
if ! command -v air &> /dev/null; then
    print_error "air is not installed or not in PATH"
    print_info "Install with: go install github.com/air-verse/air@latest"
    exit 1
fi
print_success "air found: $(which air)"

echo ""

# ============================================================================
# Backup Original Files
# ============================================================================

print_step "Backing up files..."
cp main.go main.go.manual-bak 2>/dev/null || true
cp helper.go helper.go.manual-bak 2>/dev/null || true
print_success "Backup created"

echo ""

# ============================================================================
# Instructions
# ============================================================================

print_header "📋 INSTRUCTIONS"

echo "This script will trigger two builds in quick succession to reproduce"
echo "the race condition bug."
echo ""
echo -e "${BOLD}What you need to do:${NC}"
echo "  1. Make sure air is running in another terminal"
echo "  2. Watch the output in that terminal carefully"
echo "  3. This script will modify files at the right timing"
echo ""
echo -e "${BOLD}What to observe in the air terminal:${NC}"
echo "  • You should see TWO '🔨 Build started' messages"
echo "  • But only ONE '✅ Build complete' message"
echo "  • This means Build B cancelled itself!"
echo ""

# ============================================================================
# Wait for User Confirmation
# ============================================================================

print_step "Checking if air is running..."

# Check if server is responding
if curl -s http://localhost:8080/version > /dev/null 2>&1; then
    print_success "Server detected on port 8080"
    RUNNING_VERSION=$(curl -s http://localhost:8080/version)
    print_info "Current version: $RUNNING_VERSION"
else
    print_warning "No server detected on port 8080"
    echo ""
    echo -e "${YELLOW}${BOLD}Please start air in another terminal:${NC}"
    echo "  ${CYAN}cd $(pwd)${NC}"
    echo "  ${CYAN}air${NC}"
    echo ""
    read -p "Press Enter when air is running and the server is ready... "
    
    # Verify again
    if ! curl -s http://localhost:8080/version > /dev/null 2>&1; then
        print_error "Still no server detected. Please start air first."
        exit 1
    fi
    print_success "Server is now responding!"
fi

echo ""

# ============================================================================
# Ready to Start
# ============================================================================

print_header "🚀 READY TO REPRODUCE BUG"

echo -e "${BOLD}Timeline:${NC}"
echo "  1. This script will modify main.go (triggers Build A)"
echo "  2. Wait ${TRIGGER_DELAY} seconds"
echo "  3. Modify helper.go (triggers Build B during Build A)"
echo "  4. You observe the race condition in air's output"
echo ""

read -p "Press Enter to start the reproduction sequence... "

echo ""

# ============================================================================
# Trigger Build A
# ============================================================================

print_header "⚡ TRIGGERING BUILD A"

BUILD_A_TIME=$(date +%H:%M:%S.%3N)
echo "// Build A triggered at $BUILD_A_TIME" >> main.go
# Also change helper.go version for Build A
sed -i 's/return "v[^"]*"/return "v1.0.0-BUILD-A"/g' helper.go

print_success "main.go modified at $BUILD_A_TIME"
print_success "helper.go version set to v1.0.0-BUILD-A"
echo ""
print_observe "Check air terminal - you should see:"
echo "  ${CYAN}main.go has changed${NC}"
echo "  ${CYAN}🔨 Build started at XX:XX:XX${NC}"
echo ""

# ============================================================================
# Wait and Trigger Build B
# ============================================================================

countdown "$TRIGGER_DELAY" "⏱  Triggering Build B in"

print_header "⚡ TRIGGERING BUILD B"

BUILD_B_TIME=$(date +%H:%M:%S.%3N)
sed -i 's/return "v[^"]*"/return "v2.0.0-BUILD-B"/g' helper.go

print_success "helper.go version set to v2.0.0-BUILD-B at $BUILD_B_TIME"
echo ""
print_observe "Check air terminal - you should see:"
echo "  ${CYAN}helper.go has changed${NC}"
echo "  ${CYAN}🔨 Build started at XX:XX:XX${NC} (second one)"
echo ""

print_warning "KEY OBSERVATION:"
echo "  If bug exists, you will see:"
echo "  • Two '🔨 Build started' messages"
echo "  • Only ONE '✅ Build complete' message"
echo "  • Build B started but never completed (cancelled itself)"
echo ""

# ============================================================================
# Wait for Builds
# ============================================================================

print_step "Waiting for builds to complete (15 seconds)..."
echo ""

for ((i=15; i>0; i--)); do
    echo -ne "\r${BLUE}  Waiting... ${i}s remaining${NC}  "
    sleep 1
done
echo -ne "\r${GREEN}  Builds should be complete!${NC}     \n"

echo ""

# ============================================================================
# Verification
# ============================================================================

print_header "🔍 VERIFICATION"

print_step "Checking running server version..."

if curl -s http://localhost:8080/version > /dev/null 2>&1; then
    RUNNING_VERSION=$(curl -s http://localhost:8080/version)
    RUNNING_BUILD_TIME=$(echo "$RUNNING_VERSION" | grep -oP '\d{2}:\d{2}:\d{2}\.\d{3}' || echo "")
    
    echo ""
    echo -e "${BOLD}Build Timeline:${NC}"
    echo "  Build A triggered: $BUILD_A_TIME"
    echo "  Build B triggered: $BUILD_B_TIME"
    echo "  Server running:    $RUNNING_BUILD_TIME"
    echo ""
    
    # Compare times
    if [ ! -z "$RUNNING_BUILD_TIME" ]; then
        # Simple string comparison (works for same-day times)
        if [[ "$RUNNING_BUILD_TIME" < "$BUILD_B_TIME" ]]; then
            echo -e "${RED}${BOLD}🐛 BUG DETECTED!${NC}"
            echo ""
            echo "  The server is running Build A's code (old version)"
            echo "  Build B was triggered but cancelled itself"
            echo "  This confirms the race condition bug!"
        else
            echo -e "${GREEN}${BOLD}✓ NO BUG DETECTED${NC}"
            echo ""
            echo "  The server is running Build B's code (latest version)"
            echo "  Both builds completed successfully"
            echo "  Bug may be fixed or timing was off"
        fi
    else
        print_warning "Could not parse build time from server response"
    fi
else
    print_error "Cannot connect to server"
fi

echo ""

# ============================================================================
# Additional Checks
# ============================================================================

print_step "Additional verification..."

# Check helper version in server response
HELPER_VERSION=$(echo "$RUNNING_VERSION" | grep "Helper Version:" | sed 's/Helper Version: //' | tr -d '\n\r' || echo "")

echo -e "${BOLD}Helper Version Analysis:${NC}"
echo "  File contains:  v2.0.0-BUILD-B (Build B's changes)"
echo "  Server running: $HELPER_VERSION"
echo ""

if echo "$HELPER_VERSION" | grep -q "BUILD-A"; then
    print_bug "Server is running Build A code!"
    echo "  • Build B was cancelled"
    echo "  • Helper.go changes from Build B are NOT running"
elif echo "$HELPER_VERSION" | grep -q "BUILD-B"; then
    print_fixed "Server is running Build B code!"
    echo "  • Build B completed successfully"
    echo "  • Latest changes are running"
else
    print_warning "Version: $HELPER_VERSION (neither BUILD-A nor BUILD-B)"
fi

echo ""

# ============================================================================
# Cleanup Option
# ============================================================================

print_header "🧹 CLEANUP"

echo "Do you want to restore the original files?"
echo "  This will revert main.go and helper.go to their original state"
echo ""
read -p "Restore files? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "main.go.manual-bak" ]; then
        mv main.go.manual-bak main.go
        print_success "main.go restored"
    fi
    
    if [ -f "helper.go.manual-bak" ]; then
        mv helper.go.manual-bak helper.go
        print_success "helper.go restored"
    fi
    
    print_info "Files restored. Air will rebuild automatically."
else
    print_info "Files not restored. You can restore manually:"
    echo "  ${CYAN}mv main.go.manual-bak main.go${NC}"
    echo "  ${CYAN}mv helper.go.manual-bak helper.go${NC}"
fi

echo ""

# ============================================================================
# Final Summary
# ============================================================================

print_header "📚 SUMMARY"

echo "To reproduce the bug again:"
echo "  ${CYAN}./trigger-race.sh${NC}"
echo ""
echo "For fully automated reproduction:"
echo "  ${CYAN}./reproduce-auto.sh${NC}"
echo ""
echo "For detailed explanation:"
echo "  ${CYAN}cat README.md${NC}"
echo ""

print_success "Script completed!"
