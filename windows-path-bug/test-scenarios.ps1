# Test script for Windows Path Bug - Issue #589
# Run this in PowerShell on Windows

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Path Bug Test - Issue #589" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Cleanup function
function Cleanup {
    Write-Host "`nCleaning up..." -ForegroundColor Yellow
    if (Test-Path "bin") { Remove-Item -Recurse -Force bin }
    if (Test-Path "tmp") { Remove-Item -Recurse -Force tmp }
}

# Scenario 1: Config file (should work)
Write-Host "Test 1: Using .air.toml config file (forward slash)" -ForegroundColor Green
Write-Host "Command: air" -ForegroundColor Gray
Write-Host "Expected: SUCCESS - binary runs correctly" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to run test 1 (Ctrl+C to stop air after it starts)..."
Read-Host
air

Cleanup

# Scenario 2: CLI with forward slash (should fail)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test 2: CLI flag with forward slash" -ForegroundColor Red
Write-Host "Command: air --build.cmd 'make build' --build.bin 'bin/windows-path-bug.exe'" -ForegroundColor Gray
Write-Host "Expected: FAIL - 'bin' is not recognized error" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to run test 2 (Ctrl+C to stop)..."
Read-Host
air --build.cmd "make build" --build.bin "bin/windows-path-bug.exe"

Cleanup

# Scenario 3: CLI with ./ prefix (should fail)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test 3: CLI flag with ./ prefix" -ForegroundColor Red
Write-Host "Command: air --build.cmd 'make build' --build.bin './bin/windows-path-bug.exe'" -ForegroundColor Gray
Write-Host "Expected: FAIL - '.' is not recognized error" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to run test 3 (Ctrl+C to stop)..."
Read-Host
air --build.cmd "make build" --build.bin "./bin/windows-path-bug.exe"

Cleanup

# Scenario 4: CLI with backslash (should work)
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test 4: CLI flag with backslash" -ForegroundColor Green
Write-Host "Command: air --build.cmd 'make build' --build.bin 'bin\windows-path-bug.exe'" -ForegroundColor Gray
Write-Host "Expected: SUCCESS - binary runs correctly" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Enter to run test 4 (Ctrl+C to stop)..."
Read-Host
air --build.cmd "make build" --build.bin "bin\windows-path-bug.exe"

Cleanup

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "All tests completed!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- Test 1 (config file): Should WORK" -ForegroundColor Green
Write-Host "- Test 2 (CLI forward slash): Should FAIL" -ForegroundColor Red
Write-Host "- Test 3 (CLI ./ prefix): Should FAIL" -ForegroundColor Red
Write-Host "- Test 4 (CLI backslash): Should WORK" -ForegroundColor Green
