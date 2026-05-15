---
summary: "Current Linux bootstrap status for peekaboo-linux"
read_when:
  - "setting up the local Linux development environment"
  - "debugging Swift toolchain setup on Arch Linux"
  - "checking current Linux submodule test status"
---

# Linux Bootstrap Status

Date: 2026-05-15

Host:

- OS: Arch Linux
- Kernel: `6.19.14-zen1-1-zen`
- Desktop: Hyprland Wayland
- Hyprland: `0.54.3`

## GitHub

The remote fork is created:

```text
origin   -> https://github.com/5p00kyy/peekaboo-linux.git
upstream -> https://github.com/openclaw/Peekaboo.git
```

`linux/main` is the fork default branch. The original upstream remote has its
push URL disabled locally to reduce accidental upstream pushes:

```bash
git remote set-url --push upstream DISABLED
```

Current pushed branches:

```text
linux/main
linux/portable-types
linux/cli-mvp
```

Current draft PRs:

- <https://github.com/5p00kyy/peekaboo-linux/pull/1> portable types
- <https://github.com/5p00kyy/peekaboo-linux/pull/2> Linux CLI MVP

## Submodules

Initialized successfully:

```bash
git submodule update --init --recursive
```

Submodule revisions:

```text
AXorcist   fbb2a577c98015cbfcefb606eefdd2369ce99de5
Commander  2a4c2f830982e7d5d0bb80c0a599e4a5dbe5ea5b
Swiftdansi ed7d8c9d4e01210077e1386349d252c826070a15
Tachikoma  b55bad720147dca23a52cb5e1871b25f9d384d6f
TauTUI     2e8390466c4df914696c834f486d403e7e3a5605
```

## Swift Toolchain

Swift was installed with Swiftly:

```text
Swift 6.2.1
Target: x86_64-unknown-linux-gnu
```

Arch-specific notes:

- Swiftly does not recognize Arch directly, so initialization used the compatible
  UBI9 platform selector.
- The Swift 6.2.1 UBI9 toolchain expects `libncurses.so.6`.
- Arch provides `libncursesw.so.6` but not `libncurses.so.6`.
- `scripts/linux-env.sh` creates a user-cache compatibility symlink and exports
  `LD_LIBRARY_PATH` when needed.

Use this before running Swift commands:

```bash
source scripts/linux-env.sh
swift --version
```

In Codex's sandbox, Swiftly can emit a `CFSocket` wakeup socket warning and hang
after printing output. Run Swift commands outside the sandbox when necessary.

## Current Test Results

Commands were run with:

```bash
source scripts/linux-env.sh
swift test
```

Passing:

- `Core/PeekabooTypes`: 9 tests passed.
- `Apps/LinuxCLI`: 7 tests passed.
- `Commander`: 15 tests passed.
- `TauTUI`: 147 tests passed.

Failing:

- `Swiftdansi`: fails on Linux because `Sources/Swiftdansi/Hyperlink.swift`
  imports `Darwin` unconditionally.

First Swiftdansi fix:

```swift
#if os(Linux)
import Glibc
#else
import Darwin
#endif
```

Because `Swiftdansi` is a submodule, fix it in its own fork/repo first, then
bump the gitlink in `peekaboo-linux`.

Not yet tested:

- `Tachikoma`
- `AXorcist` (expected macOS-only)
- Peekaboo core packages
- Peekaboo CLI package

## Linux CLI MVP

The first Linux-specific Swift package lives in `Apps/LinuxCLI`.

Build and test:

```bash
source scripts/linux-env.sh
pnpm run build:linux
pnpm run test:linux
```

Direct smoke commands:

```bash
source scripts/linux-env.sh
swift run --package-path Apps/LinuxCLI peekaboo-linux doctor
swift run --package-path Apps/LinuxCLI peekaboo-linux list screens --json
swift run --package-path Apps/LinuxCLI peekaboo-linux list windows --json
swift run --package-path Apps/LinuxCLI peekaboo-linux image --mode screen --path /tmp/peekaboo-linux-smoke.png
swift run --package-path Apps/LinuxCLI peekaboo-linux image --mode area --rect 0,0,640,360 --path /tmp/peekaboo-linux-area.png
```

Verified on this host:

- `doctor` finds `hyprctl`, `grim`, `slurp`, `wl-copy`, and `wl-paste`.
- `list screens --json` reports `DP-1` at `2560x1440`.
- `list windows --json` reports Hyprland window addresses, app IDs, titles,
  frames, workspace names, and focused state.
- `image --mode screen` produced `/tmp/peekaboo-linux-smoke.png`, a `2560x1440`
  PNG.
- `image --mode area` produced `/tmp/peekaboo-linux-area.png`, a `640x360` PNG.

## Useful Local Smoke Commands

```bash
source scripts/linux-env.sh
hyprctl -j version
hyprctl -j monitors
hyprctl -j activewindow
grim - | file -
printf hello | wl-copy
wl-paste
```
