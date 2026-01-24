package main

import (
	"fmt"
	"time"
)

func main() {
	fmt.Println("Hello from Air! Running successfully...")
	fmt.Println("This confirms that the binary path was properly resolved.")

	// Keep running for 30 seconds to observe behavior
	for i := 1; i <= 30; i++ {
		fmt.Printf("Running... %d/30\n", i)
		time.Sleep(1 * time.Second)
	}

	fmt.Println("Program completed successfully!")
}
