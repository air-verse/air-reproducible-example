FROM cosmtrek/air:v1.63.3

WORKDIR /app

# Download dependencies first to leverage Docker layer caching.
COPY go.mod go.sum ./
RUN go mod download

# Bring in the rest of the source.
COPY . .

EXPOSE 8080

# Run Air with the requested build command and exclusions.
CMD ["air", "--build.cmd", "go build -o /tmp/content main.go", "--build.bin", "/tmp/content", "--build.exclude_dir", "assets,tmp,vendor,testdata,tests"]
