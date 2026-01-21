package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	fmt.Printf("issue 860 repro: started pid=%d at %s\n", os.Getpid(), time.Now().Format(time.RFC3339))
	for {
		time.Sleep(2 * time.Second)
	}
}
