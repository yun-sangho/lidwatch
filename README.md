# lidwatch

Event-driven helper that turns off your Mac's display the moment you close the lid — even when an external display keeps the Mac awake (clamshell mode).

Built on IOKit's `IOServiceAddInterestNotification`: zero polling, zero CPU when idle, sub-millisecond reaction time.

## Why

In clamshell mode macOS does not sleep the internal display when you close the lid, because the lid state alone doesn't trigger a power transition. That leaves the internal panel powered on and sometimes visible through the hinge gap. A tiny watcher that calls `pmset displaysleepnow` on the close event solves it.

Common solutions poll `ioreg` every few seconds. This one subscribes to the kernel's IOKit notification directly.

## Install

Requires Xcode Command Line Tools (`xcode-select --install`). No Apple Developer account needed — the tool is compiled locally on your Mac.

```bash
git clone <this-repo> lidwatch
cd lidwatch
./install.sh
```

This does:

1. Builds a universal (arm64 + x86_64) release binary with `swift build`.
2. Copies it to `~/.local/bin/lidwatch`.
3. Writes `~/Library/LaunchAgents/com.lidwatch.agent.plist` and loads it.
4. Enables the feature (creates the state flag file).

Uninstall with `./uninstall.sh`.

## Usage

```
lidwatch status       # show current state + LaunchAgent status
lidwatch enable       # turn on
lidwatch disable      # turn off (agent keeps running, but acts as a no-op)
lidwatch toggle
lidwatch watch        # run the watcher in foreground (for testing)
```

Live logs:

```bash
tail -f ~/Library/Logs/lidwatch.log
```

## How it works

- Gets the `IOPMrootDomain` service from the IOKit registry.
- Subscribes with `kIOGeneralInterest`.
- On every callback, re-reads the `AppleClamshellState` property.
- Acts only on the open → closed transition, and only if the `enabled` flag is set.

The callback runs on `DispatchQueue.main`; the process blocks in `dispatchMain()` and only wakes on actual kernel events. Steady-state CPU is 0.

No private IOKit symbols or message-type constants are used, so this should remain stable across macOS versions.

## Project layout

```
Package.swift
Sources/lidwatch/main.swift      # entry point, watcher, CLI
com.lidwatch.agent.plist.template
install.sh
uninstall.sh
```

## License

MIT. See `LICENSE`.
