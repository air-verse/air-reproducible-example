@echo off
REM Test script for Windows Path Bug - Issue #589
REM Run this in CMD on Windows

echo ========================================
echo Windows Path Bug Test - Issue #589
echo ========================================
echo.

echo Test 1: Using .air.toml config file (forward slash)
echo Command: air
echo Expected: SUCCESS - binary runs correctly
echo.
echo Press Ctrl+C to stop air after it starts...
echo.
air
if exist bin rmdir /s /q bin
if exist tmp rmdir /s /q tmp

echo.
echo ========================================
echo Test 2: CLI flag with forward slash
echo Command: air --build.cmd "make build" --build.bin "bin/windows-path-bug.exe"
echo Expected: FAIL - 'bin' is not recognized error
echo.
echo Press Ctrl+C to stop...
echo.
air --build.cmd "make build" --build.bin "bin/windows-path-bug.exe"
if exist bin rmdir /s /q bin
if exist tmp rmdir /s /q tmp

echo.
echo ========================================
echo Test 3: CLI flag with ./ prefix
echo Command: air --build.cmd "make build" --build.bin "./bin/windows-path-bug.exe"
echo Expected: FAIL - '.' is not recognized error
echo.
echo Press Ctrl+C to stop...
echo.
air --build.cmd "make build" --build.bin "./bin/windows-path-bug.exe"
if exist bin rmdir /s /q bin
if exist tmp rmdir /s /q tmp

echo.
echo ========================================
echo Test 4: CLI flag with backslash
echo Command: air --build.cmd "make build" --build.bin "bin\windows-path-bug.exe"
echo Expected: SUCCESS - binary runs correctly
echo.
echo Press Ctrl+C to stop...
echo.
air --build.cmd "make build" --build.bin "bin\windows-path-bug.exe"
if exist bin rmdir /s /q bin
if exist tmp rmdir /s /q tmp

echo.
echo ========================================
echo All tests completed!
echo ========================================
echo.
echo Summary:
echo - Test 1 (config file): Should WORK
echo - Test 2 (CLI forward slash): Should FAIL
echo - Test 3 (CLI ./ prefix): Should FAIL
echo - Test 4 (CLI backslash): Should WORK
