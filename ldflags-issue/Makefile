VERSION := 0.1.0-dev
BUILD_TIME := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)

.PHONY: build

build:
	@mkdir -p ./tmp
	go build -ldflags "$(LDFLAGS)" -o ./tmp/main .
