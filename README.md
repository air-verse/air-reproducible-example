# Air Reproducible Examples

This repo collects minimal projects that reproduce bugs when running apps with [Air](https://github.com/air-verse/air). If you hit an Air bug, add the smallest repro you can here and open a PR so others can run it quickly.

## Quick start
- Install Go (1.21+ recommended) and Air: `go install github.com/air-verse/air@latest`.
- Pick a sample directory, `cd` into it, and run `air`.
- Hit the route noted below; stop with `Ctrl+C` when you are done.

## Current samples
- `air-proxy-timeout/`: Delays startup by one second so Air's proxy on `:8888` times out while the app comes up on `:7777` (reproduces air-verse/air#732).
- `race-condition-issue-784/`: Race condition where Build B cancels itself when triggered during Build A, leaving outdated binary running (reproduces air-verse/air#784).
- `"with space"/`: Gin app kept in a path containing a space to check watcher/build behavior; `air` serves `/ping` and `/index` on `:8080`.
- `with-template/`: Gin app rendering templates (LoadHTMLGlob) with a couple nested packages to see how template changes are picked up; `air` serves `/ping` and `/index` on `:8080`.

## Add a new reproduction
1. Create a new folder named after the bug or upstream issue; keep code and dependencies minimal.
2. Include a `.air.toml`, `go.mod`, and a short README inside that folder explaining expected vs actual behavior, ports used, and exact steps to trigger the bug.
3. Make sure `air` runs cleanly from that folder (the shared `tmp/` patterns are already gitignored).
4. Update this README with a one-line description of your sample and open a PR linking to the upstream Air issue you are reproducing.
