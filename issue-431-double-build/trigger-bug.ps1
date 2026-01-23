# Issue #431 Bug Reproducer - Windows PowerShell
# https://github.com/air-verse/air/issues/431
#
# Usage: .\trigger-bug.ps1
#
# This script automates the reproduction of the double-build bug on Windows.
# The bug occurs when delay=0 and files are saved rapidly, causing Air to
# start multiple builds simultaneously, resulting in "fatal: morestack on g0"
# or port binding errors.

param(
    [switch]$SkipCleanup = $false
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Issue #431: Double Build Bug Reproducer" -ForegroundColor Cyan
Write-Host " Platform: Windows" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if air is available
$airPath = Get-Command air -ErrorAction SilentlyContinue
if (-not $airPath) {
    Write-Host "[ERROR] 'air' not found in PATH. Please install it first:" -ForegroundColor Red
    Write-Host "  go install github.com/air-verse/air@latest" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Air found: $($airPath.Source)" -ForegroundColor Green

# Check if port 3000 is available
$portCheck = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if ($portCheck) {
    Write-Host "[WARNING] Port 3000 is already in use. Attempting to free it..." -ForegroundColor Yellow
    Get-Process -Name "main" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# Cleanup previous runs
Write-Host ""
Write-Host "[STEP 1/6] Cleaning up previous runs..." -ForegroundColor Yellow
Remove-Item -Path "air.log" -ErrorAction SilentlyContinue
Remove-Item -Path "air.err" -ErrorAction SilentlyContinue
Remove-Item -Path "tmp" -Recurse -ErrorAction SilentlyContinue

# Restore main.go to original state
$originalContent = @"
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	startTime := time.Now().Format("15:04:05.000")
	pid := os.Getpid()

	fmt.Printf("running... (PID: %d, started at %s)\n", pid, startTime)
	fmt.Println("Starting the server on :3000...")

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! PID=%d, Started=%s\n", pid, startTime)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "OK")
	})

	http.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Build Time: %s\nPID: %d\n", startTime, pid)
	})

	if err := http.ListenAndServe(":3000", nil); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
"@
Set-Content -Path "main.go" -Value $originalContent -NoNewline
Write-Host "[OK] Cleanup complete" -ForegroundColor Green

# Start air
Write-Host ""
Write-Host "[STEP 2/6] Starting air in background..." -ForegroundColor Yellow
$airProcess = Start-Process -FilePath "air" -NoNewWindow -RedirectStandardOutput "air.log" -RedirectStandardError "air.err" -PassThru
Write-Host "[OK] Air started (PID: $($airProcess.Id))" -ForegroundColor Green

# Wait for initial build
Write-Host ""
Write-Host "[STEP 3/6] Waiting for initial build to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 6
Write-Host "[OK] Initial build should be complete" -ForegroundColor Green

# Trigger first reload
Write-Host ""
Write-Host "[STEP 4/6] Triggering first reload (single save)..." -ForegroundColor Yellow
Add-Content -Path "main.go" -Value "`n// Trigger 1: $(Get-Date -Format 'HH:mm:ss.fff')"
Start-Sleep -Seconds 4
Write-Host "[OK] First reload triggered" -ForegroundColor Green

# Trigger rapid saves (this is where the bug manifests)
Write-Host ""
Write-Host "[STEP 5/6] Triggering rapid file saves (BUG TRIGGER)..." -ForegroundColor Yellow
Write-Host "          Saving file multiple times in quick succession..." -ForegroundColor Gray

for ($i = 1; $i -le 3; $i++) {
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    Add-Content -Path "main.go" -Value "// Rapid save $i at $timestamp"
    Write-Host "          Save $i at $timestamp" -ForegroundColor Gray
    Start-Sleep -Milliseconds 50  # Very short delay between saves
}

Write-Host "[OK] Rapid saves complete" -ForegroundColor Green

# Wait for builds to complete (or fail)
Write-Host ""
Write-Host "[STEP 6/6] Waiting for builds to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# Analyze results
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ANALYSIS RESULTS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$logExists = Test-Path "air.log"
if (-not $logExists) {
    Write-Host "[ERROR] air.log not found!" -ForegroundColor Red
    exit 1
}

$logContent = Get-Content "air.log" -Raw -ErrorAction SilentlyContinue
$errContent = Get-Content "air.err" -Raw -ErrorAction SilentlyContinue

# Count key patterns
$runningCount = ([regex]::Matches($logContent, "running\.\.\.")).Count
$startingCount = ([regex]::Matches($logContent, "Starting the server")).Count
$bindError = $logContent -match "bind: " -or $errContent -match "bind: "
$morestackError = $logContent -match "morestack" -or $errContent -match "morestack"

Write-Host "  'running...' occurrences:        $runningCount"
Write-Host "  'Starting the server' count:     $startingCount"
Write-Host "  Port bind error detected:        $(if ($bindError) { 'YES' } else { 'NO' })"
Write-Host "  'morestack on g0' error:         $(if ($morestackError) { 'YES' } else { 'NO' })"
Write-Host ""

# Determine if bug was reproduced
$bugReproduced = $false
$bugIndicators = @()

if ($runningCount -gt 5) {
    $bugIndicators += "Multiple 'running...' messages ($runningCount)"
    $bugReproduced = $true
}
if ($startingCount -gt 5) {
    $bugIndicators += "Multiple server starts ($startingCount)"
    $bugReproduced = $true
}
if ($bindError) {
    $bugIndicators += "Port bind error (double server start)"
    $bugReproduced = $true
}
if ($morestackError) {
    $bugIndicators += "fatal: morestack on g0 error"
    $bugReproduced = $true
}

if ($bugReproduced) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " BUG REPRODUCED!" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Indicators:" -ForegroundColor Red
    foreach ($indicator in $bugIndicators) {
        Write-Host "  - $indicator" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "WORKAROUND: Set 'delay = 10' in .air.toml" -ForegroundColor Yellow
} else {
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host " BUG NOT TRIGGERED THIS TIME" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The bug may be timing-dependent. Try:" -ForegroundColor Yellow
    Write-Host "  1. Run the script again" -ForegroundColor Gray
    Write-Host "  2. Manually edit and save main.go rapidly" -ForegroundColor Gray
    Write-Host "  3. Check air.log for detailed output" -ForegroundColor Gray
}

# Cleanup
Write-Host ""
Write-Host "[CLEANUP] Stopping processes..." -ForegroundColor Yellow
Stop-Process -Id $airProcess.Id -ErrorAction SilentlyContinue
Get-Process -Name "main" -ErrorAction SilentlyContinue | Stop-Process -Force

if (-not $SkipCleanup) {
    # Restore main.go
    Set-Content -Path "main.go" -Value $originalContent -NoNewline
    Write-Host "[OK] main.go restored to original state" -ForegroundColor Green
}

Write-Host ""
Write-Host "Log files:" -ForegroundColor Cyan
Write-Host "  - air.log (stdout)" -ForegroundColor Gray
Write-Host "  - air.err (stderr)" -ForegroundColor Gray
Write-Host ""
Write-Host "Done!" -ForegroundColor Green
