package main

import (
	"fmt"
	"os"
	"time"

	"github.com/labstack/echo/v4"
)

// This reproduces https://github.com/air-verse/air/issues/744
//
// The issue: Air preserves the separation between subprocess stdout and stderr.
// When piping `air | jq`, only stdout is captured, and stderr output is lost.
//
// Run with: air | jq -R 'try fromjson catch .'
// Workaround: air 2>&1 | jq -R 'try fromjson catch .'

func main() {
	e := echo.New()
	go e.Start(":0")
	log := e.Logger

	ticker := time.NewTicker(100 * time.Millisecond)

	i := 0
	for range ticker.C {
		i++
		// Echo logger outputs JSON to stdout
		log.Print(fmt.Sprintf("tick-%d", i))

		// Many Go libraries/frameworks write to stderr for various reasons
		// (errors, warnings, debug info, etc.)
		// Air faithfully preserves this separation, which breaks piping.
		if i%5 == 0 {
			fmt.Fprintf(os.Stderr, `{"time":"%s","level":"WARN","source":"stderr","message":"warning-tick-%d"}`+"\n",
				time.Now().Format(time.RFC3339), i)
		}
	}
}
