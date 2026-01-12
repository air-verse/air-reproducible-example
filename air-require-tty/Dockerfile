FROM golang:1.25

# Install air for hot reload
RUN go install github.com/air-verse/air@v1.61.7

WORKDIR /app

# Copy go mod files first for caching
COPY go.mod ./
RUN go mod download

# Copy source code
COPY . .

# Default command - run with air
CMD ["air", "-c", ".air.toml"]
