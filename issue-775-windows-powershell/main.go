package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("air issue 775 repro")
	for {
		time.Sleep(2 * time.Second)
	}
}
