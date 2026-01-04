#!/bin/bash

# ============================================================================
# reproduce-auto.sh - Fully Automated Race Condition Bug #784 Reproducer
# ============================================================================
# This script automatically reproduces the race condition bug where Build B
# cancels itself when triggered during Build A.
#
# Usage: ./reproduce-auto.sh
# ============================================================================

set -e  # Exit on error (except where explicitly handled)

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
AIR_LOG="air-reproduce.log"
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
    echo -e "${BOLD}${CYAN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_bug() {
    echo -e "${RED}${BOLD}[🐛 BUG REPRODUCED]${NC} $1"
}

print_fixed() {
    echo -e "${GREEN}${BOLD}[✓ NO BUG]${NC} $1"
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    print_step "Cleaning up..."
    
    # Stop air if running
    if [ ! -z "$AIR_PID" ] && kill -0 "$AIR_PID" 2>/dev/null; then
        print_info "Stopping air (PID: $AIR_PID)..."
        kill "$AIR_PID" 2>/dev/null || true
        wait "$AIR_PID" 2>/dev/null || true
        print_success "Air stopped"
    fi
    
    # Restore original files
    if [ -f "main.go.bak" ]; then
        print_info "Restoring main.go..."
        mv main.go.bak main.go
    fi
    
    if [ -f "helper.go.bak" ]; then
        print_info "Restoring helper.go..."
        mv helper.go.bak helper.go
    fi
    
    # Clean tmp directory
    if [ -d "tmp" ]; then
        print_info "Removing tmp/ directory..."
        rm -rf tmp/
    fi
    
    print_success "Cleanup complete"
    echo ""
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# ============================================================================
# Pre-flight Checks
# ============================================================================

print_header "🐛 Race Condition Bug #784 - Automated Reproducer"

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

# Check if port 8080 is available
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_error "Port 8080 is already in use"
    print_info "Please stop the process using port 8080 and try again"
    exit 1
fi
print_success "Port 8080 is available"

echo ""

# ============================================================================
# Backup Original Files
# ============================================================================

print_step "Backing up original files..."
cp main.go main.go.bak
cp helper.go helper.go.bak
print_success "Files backed up"

echo ""

# ============================================================================
# Start Air
# ============================================================================

print_step "Starting air in background..."

# Clean any previous logs and tmp
rm -f "$AIR_LOG"
rm -rf tmp/

# Start air and redirect output to log file
air > "$AIR_LOG" 2>&1 &
AIR_PID=$!

print_success "Air started (PID: $AIR_PID)"
print_info "Logs: tail -f $AIR_LOG"

echo ""

# ============================================================================
# Wait for Initial Build
# ============================================================================

print_step "Waiting for initial build to complete..."
print_info "This may take up to 20 seconds..."

# Wait for server to be ready
MAX_WAIT=30
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if grep -q "Server listening on :8080" "$AIR_LOG" 2>/dev/null; then
        print_success "Server is ready!"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    echo -ne "\r${BLUE}[INFO]${NC} Waiting... ${ELAPSED}s"
done
echo ""

if [ $ELAPSED -ge $MAX_WAIT ]; then
    print_error "Timeout waiting for server to start"
    print_info "Check $AIR_LOG for details"
    exit 1
fi

# Additional wait to ensure everything is stable
sleep 2

echo ""

# ============================================================================
# Trigger Build A
# ============================================================================

print_step "Triggering Build A (modifying main.go and helper.go)..."

BUILD_A_TIME=$(date +%H:%M:%S.%3N)
echo "// Build A triggered at $BUILD_A_TIME" >> main.go
# Set helper.go version to BUILD-A
sed -i 's/return "v[^"]*"/return "v1.0.0-BUILD-A"/g' helper.go

print_success "Build A triggered at $BUILD_A_TIME"
print_info "Helper version set to: v1.0.0-BUILD-A"
print_info "Build A will take ~10 seconds (includes sleep)"

echo ""

# ============================================================================
# Trigger Build B (During Build A)
# ============================================================================

print_step "Waiting ${TRIGGER_DELAY}s before triggering Build B..."
sleep "$TRIGGER_DELAY"

print_step "Triggering Build B (modifying helper.go)..."
print_warning "This should happen WHILE Build A is still running!"

BUILD_B_TIME=$(date +%H:%M:%S.%3N)
# Modify helper.go version to BUILD-B
sed -i 's/return "v[^"]*"/return "v2.0.0-BUILD-B"/g' helper.go

print_success "Build B triggered at $BUILD_B_TIME"
print_info "Helper version set to: v2.0.0-BUILD-B"
print_info "If bug exists, Build B will cancel itself!"

echo ""

# ============================================================================
# Wait for Builds to Complete
# ============================================================================

print_step "Waiting for builds to complete..."
print_info "This will take ~15 seconds..."

sleep 15

echo ""

# ============================================================================
# Analyze Results
# ============================================================================

print_header "📊 ANALYSIS RESULTS"

# Count build starts and completions
BUILD_STARTS=$(grep -c "🔨 Build started at" "$AIR_LOG" || echo "0")
BUILD_COMPLETES=$(grep -c "✅ Build complete at" "$AIR_LOG" || echo "0")

print_info "Build starts detected: $BUILD_STARTS"
print_info "Build completions detected: $BUILD_COMPLETES"

echo ""

# Extract build times from log
print_step "Build timeline:"
grep "🔨 Build started at\|✅ Build complete at" "$AIR_LOG" | while read -r line; do
    echo "  $line"
done

echo ""

# Check running server version
print_step "Checking running server version..."

if curl -s http://localhost:8080/version > /dev/null 2>&1; then
    RUNNING_VERSION=$(curl -s http://localhost:8080/version)
    print_success "Server response:"
    echo "  $RUNNING_VERSION"
else
    print_error "Failed to connect to server"
    exit 1
fi

echo ""

# ============================================================================
# Determine if Bug is Reproduced
# ============================================================================

print_header "🔍 BUG DETECTION"

# Extract the build time and helper version from server response
RUNNING_BUILD_TIME=$(echo "$RUNNING_VERSION" | grep -oP '\d{2}:\d{2}:\d{2}\.\d{3}' || echo "")
RUNNING_HELPER_VERSION=$(echo "$RUNNING_VERSION" | grep "Helper Version:" | sed 's/Helper Version: //' || echo "")

if [ -z "$RUNNING_BUILD_TIME" ]; then
    print_error "Could not parse build time from server response"
    exit 1
fi

if [ -z "$RUNNING_HELPER_VERSION" ]; then
    print_error "Could not parse helper version from server response"
    exit 1
fi

print_info "Build A triggered at: $BUILD_A_TIME"
print_info "Build B triggered at: $BUILD_B_TIME"
print_info "Server running build: $RUNNING_BUILD_TIME"
print_info "Helper version running: $RUNNING_HELPER_VERSION"

echo ""

# Analyze the results
# The bug manifests in two ways:
# 1. More file changes than build starts (Build B cancelled before printing "Build started")
# 2. More build starts than completions (Build B cancelled after printing "Build started")

FILE_CHANGES=$(grep -c "has changed" "$AIR_LOG" || echo "0")
print_info "File changes detected: $FILE_CHANGES (excluding initial)"

echo ""

# Detect the bug
BUG_DETECTED=0

# Method 1: Check helper version to see which build completed
MAIN_CHANGES=$(grep -c "main.go has changed" "$AIR_LOG" || echo "0")
HELPER_CHANGES=$(grep -c "helper.go has changed" "$AIR_LOG" || echo "0")

# We trigger: main.go+helper.go (Build A) then helper.go again (Build B)
# Expected: 1 main.go change + 2 helper.go changes = 3 file changes
# Expected: 1 initial build + 1 Build A + 1 Build B = 3 build starts
# If Build B cancelled, we'll see: 2 build starts and helper version = BUILD-A

if [ "$HELPER_CHANGES" -ge 1 ]; then
    # Check: Is the helper version BUILD-A (old) or BUILD-B (latest)?
    if echo "$RUNNING_HELPER_VERSION" | grep -q "BUILD-A"; then
        print_bug "Race condition detected!"
        echo ""
        echo -e "${RED}${BOLD}Analysis:${NC}"
        echo "  • main.go changes: $MAIN_CHANGES"
        echo "  • helper.go changes: $HELPER_CHANGES (Build A set to BUILD-A, Build B set to BUILD-B)"  
        echo "  • Total build starts: $BUILD_STARTS"
        echo "  • Helper version running: $RUNNING_HELPER_VERSION"
        echo "  • Expected version: v2.0.0-BUILD-B (latest)"
        echo "  • Actual version: $RUNNING_HELPER_VERSION (OLD!)"
        echo ""
        echo -e "${YELLOW}What happened:${NC}"
        echo "  1. Build A started (main.go + helper.go changed to BUILD-A)"
        echo "  2. Build B was triggered (helper.go changed to BUILD-B) while Build A was running"
        echo "  3. Build B sent stop signal to buildRunStopCh (intended for Build A)"
        echo "  4. Build B called go buildRun()"
        echo "  5. Build B's buildRun() immediately checked buildRunStopCh"
        echo "  6. Build B found the signal IT JUST SENT"
        echo "  7. Build B cancelled itself!"
        echo "  8. Only Build A completed with BUILD-A version"
        echo ""
        
        print_bug "Server is running OLD code (Build A)!"
        echo "  • Helper version shows: $RUNNING_HELPER_VERSION"
        echo "  • Should show: v2.0.0-BUILD-B (latest changes)"
        echo "  • Build B changes are NOT reflected"
        echo "  • This confirms the race condition bug!"
        
        BUG_DETECTED=1
    elif echo "$RUNNING_HELPER_VERSION" | grep -q "v2.0.0-BUILD-B"; then
        print_fixed "Helper version is correct (v2.0.0-BUILD-B)"
        echo "  • Build B completed successfully"
        echo "  • Bug was NOT reproduced"
        BUG_DETECTED=0
    else
        print_warning "Unexpected helper version: $RUNNING_HELPER_VERSION"
        echo "  • Could not determine if bug was reproduced"
        BUG_DETECTED=0
    fi
# Method 2: More build starts than completions
elif [ "$BUILD_STARTS" -gt "$BUILD_COMPLETES" ]; then
    print_bug "Race condition detected!"
    echo ""
    echo -e "${RED}${BOLD}Analysis:${NC}"
    echo "  • $BUILD_STARTS builds were started"
    echo "  • Only $BUILD_COMPLETES builds completed"
    echo "  • $(($BUILD_STARTS - $BUILD_COMPLETES)) build(s) were cancelled"
    echo ""
    BUG_DETECTED=1
else
    print_fixed "All builds completed successfully"
    echo "  • No builds were cancelled"
    echo "  • Bug may be fixed or not triggered"
    BUG_DETECTED=0
fi

echo ""

# ============================================================================
# Final Summary
# ============================================================================

print_header "📋 SUMMARY"

if [ $BUG_DETECTED -eq 1 ]; then
    echo -e "${RED}${BOLD}🐛 BUG SUCCESSFULLY REPRODUCED!${NC}"
    echo ""
    echo "This confirms the race condition in air/runner/engine.go where:"
    echo "  • Build B cancels itself when triggered during Build A"
    echo "  • The running binary contains outdated code"
    echo ""
    echo "For detailed logs, check: $AIR_LOG"
    EXIT_CODE=0
else
    echo -e "${GREEN}${BOLD}✓ Bug was NOT reproduced${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  • Timing was off (try running again)"
    echo "  • Bug has been fixed"
    echo "  • Build completed too quickly"
    echo ""
    echo "For detailed logs, check: $AIR_LOG"
    EXIT_CODE=1
fi

echo ""

# ============================================================================
# Ask about cleanup
# ============================================================================

read -p "Keep log file for analysis? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$AIR_LOG"
    print_info "Log file deleted"
else
    print_info "Log preserved: $AIR_LOG"
fi

echo ""
print_success "Script completed"

exit $EXIT_CODE
