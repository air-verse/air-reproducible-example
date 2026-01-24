.PHONY: build clean

build:
	@echo "Building windows-path-bug..."
	@mkdir -p bin
	@go build -o bin/windows-path-bug.exe main.go
	@echo "Build complete: bin/windows-path-bug.exe"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin tmp
	@echo "Clean complete"
