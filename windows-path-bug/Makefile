.PHONY: build clean

# Detect OS and use appropriate commands
ifeq ($(OS),Windows_NT)
    # Windows commands
    MKDIR = if not exist bin mkdir bin
    RM = if exist bin rmdir /s /q bin & if exist tmp rmdir /s /q tmp
else
    # Unix/Linux commands
    MKDIR = mkdir -p bin
    RM = rm -rf bin tmp
endif

build:
	@echo "Building windows-path-bug..."
	@$(MKDIR)
	@go build -o bin/windows-path-bug.exe main.go
	@echo "Build complete: bin/windows-path-bug.exe"

clean:
	@echo "Cleaning build artifacts..."
	@$(RM)
	@echo "Clean complete"
