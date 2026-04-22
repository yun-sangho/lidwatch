# lidwatch

Turns off your Mac's internal display the moment you close the lid — **even when macOS can't or won't sleep**.

Built on IOKit's `IOServiceAddInterestNotification`: zero polling, zero CPU when idle, sub-millisecond reaction time.

## Why

Normally closing the lid puts the Mac to sleep, which turns every display off. But in a lot of real setups sleep is blocked:

- **Clamshell mode** — external display attached, so macOS keeps the Mac awake.
- **`sudo pmset -a disablesleep 1`** (a.k.a. `SleepDisabled`) — sleep disabled at the system level.
- **`caffeinate`, Amphetamine, KeepingYouAwake**, or any process holding a `PreventUserIdleSystemSleep` assertion.
- Background tasks (file sharing, Time Machine, screen recording, Handoff, audio playback) silently holding display-sleep assertions.

In all of these the internal panel stays powered on after you close the lid — sometimes visibly glowing through the hinge. lidwatch catches the lid-close event and calls `pmset displaysleepnow`, which turns the display off **without** needing the system to sleep. Works in every scenario above.

Common solutions poll `ioreg` every few seconds. This one subscribes to the kernel's IOKit notification directly, so it reacts instantly and uses no CPU while idle.

## Install

Requires Xcode Command Line Tools (`xcode-select --install`). No Apple Developer account needed — the tool is compiled locally on your Mac.

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
