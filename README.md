# lidwatch

Turns off your Mac's internal display the moment you close the lid — **even when macOS can't or won't sleep**.

Built on IOKit's `IOServiceAddInterestNotification`: zero polling, zero CPU when idle, sub-millisecond reaction time.

## Why

Closing the lid normally sleeps the Mac and turns displays off. But when sleep is blocked — `pmset disablesleep`, `caffeinate`/Amphetamine, or any background process holding a sleep assertion — the internal panel stays powered on after you close the lid. This includes clamshell mode combined with any of the above.

lidwatch subscribes to the kernel's lid-close event and calls `pmset displaysleepnow`, turning the display off without needing the system to sleep. Event-driven, no polling, zero CPU while idle.

## Install

Requires Xcode Command Line Tools (`xcode-select --install`). No Apple Developer account needed — the tool is compiled locally on your Mac.

### Homebrew (recommended)

```bash
brew install yun-sangho/tap/lidwatch && brew services start lidwatch
```

That's it. Enabled by default; lid close will sleep the display immediately.

Upgrade: `brew upgrade lidwatch` — Uninstall: `brew services stop lidwatch && brew uninstall lidwatch`.

### From source

```bash
git clone https://github.com/yun-sangho/lidwatch.git
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
lidwatch disable      # pause (agent keeps running, but acts as a no-op)
lidwatch enable       # resume
lidwatch toggle
lidwatch watch        # run the watcher in foreground (for testing)
```

Enabled by default after install; `disable` is for temporarily pausing without stopping the service.

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
