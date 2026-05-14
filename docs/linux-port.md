---
summary: "Linux port feasibility notes and migration plan"
read_when:
  - "planning Linux support"
  - "planning Hyprland support"
  - "touching platform automation boundaries"
  - "splitting macOS-specific automation code from portable runtime code"
---

# Linux Port Feasibility

Peekaboo can be ported to Linux, but not by making the existing Swift packages
compile with `#if os(Linux)` guards alone. The reusable parts are the CLI shape,
agent/MCP runtime, snapshot model, command formatting, provider configuration, and
some service protocols. The non-portable parts are the current platform backends:
screen capture, accessibility tree traversal, input synthesis, window/app
management, menu/dock/Spaces behavior, clipboard, permissions, visual overlays,
and Apple image/OCR helpers.

Hyprland should be the first Linux target. It is the user's desktop, this local
workspace is running a Hyprland Wayland session, and Hyprland exposes useful
first-party IPC through `hyprctl` plus the compositor sockets. See
[`docs/linux-port-research.md`](linux-port-research.md) for the deeper research
pass and backend design.

The right port is a platform backend split:

1. Extract shared contracts and data models into packages that build on Linux.
2. Keep the current macOS implementation behind a `PeekabooPlatformMac` backend.
3. Add a Linux backend with explicit display-server support tiers.
4. Re-enable CLI/MCP tools incrementally as Linux capabilities become real.

## Current Status

- Swift 6.2.1 is installed locally through Swiftly. On Arch Linux,
  `scripts/linux-env.sh` supplies the `libncurses.so.6` compatibility path needed
  by the UBI9 Swift toolchain.
- Submodules are initialized.
- `Core/PeekabooTypes` builds and tests on Linux.
- `Apps/LinuxCLI` builds and tests on Linux.
- The first live Hyprland smoke tests pass:
  - `peekaboo-linux doctor`
  - `peekaboo-linux list screens --json`
  - `peekaboo-linux list windows --json`
  - `peekaboo-linux image --mode screen --path /tmp/peekaboo-linux-smoke.png`

## Current Blockers

- `Swiftdansi` fails on Linux because `Sources/Swiftdansi/Hyperlink.swift`
  imports `Darwin` unconditionally. Fix it in the submodule repo, then bump the
  gitlink here.
- All main packages currently declare macOS-only platforms:
  - root `Package.swift`: `.macOS(.v14)`
  - `Core/PeekabooCore/Package.swift`: `.macOS(.v14)`
  - `Core/PeekabooAutomationKit/Package.swift`: `.macOS(.v14)`
  - `Core/PeekabooFoundation/Package.swift`: `.macOS(.v14)`
  - `Core/PeekabooProtocols/Package.swift`: `.macOS(.v14)`
  - `Apps/CLI/Package.swift`: `.macOS(.v15)`
- `CoreGraphics` leaks into shared-looking packages:
  - `Core/PeekabooFoundation/Sources/PeekabooFoundation/CommonUtilities.swift`
  - `Core/PeekabooProtocols/Sources/PeekabooProtocols/UIServiceProtocols.swift`
- The automation backend depends heavily on Apple frameworks:
  `AppKit`, `ApplicationServices`, `ScreenCaptureKit`, `CoreGraphics`,
  `CoreImage`, `Vision`, and `IOKit`.

## What Can Be Reused

- Agent loop and MCP tool orchestration once the service provider can be backed by
  Linux services.
- Command parsing and output formatting if `Commander`, `TauTUI`, and
  `Swiftdansi` build on Linux.
- AI provider configuration and model calls if `Tachikoma` builds on Linux.
- Snapshot JSON shape and UI element model after replacing Apple geometry types
  with portable equivalents.
- Pure logic in target resolution, movement planning, retries, command validation,
  and JSON output generation after removing platform type leakage.

## What Must Be Reimplemented

### Capture

Linux has no direct equivalent of ScreenCaptureKit. Support has to be explicit:

- Wayland desktop portals: safest default for screenshots and screen capture, but
  user approval and compositor behavior vary.
- Wayland compositor-specific tooling: `grim`/`slurp` on wlroots, KWin APIs on
  KDE, Mutter/Shell APIs on GNOME where available.
- X11: `XGetImage`, EWMH window IDs, `xwd`, ImageMagick, or `scrot` style capture
  are easier but increasingly not the default on modern desktops.

MVP recommendation: support full-screen and rectangular capture first. Treat
window-specific capture as best effort until window identity is stable.

### Accessibility Tree

macOS AX APIs need a Linux equivalent. The best candidate is AT-SPI2 over D-Bus.
It can expose roles, names, bounds, actions, and settable values for GTK, Qt,
Electron, Chromium, and many desktop apps, but coverage varies by toolkit and
application settings.

MVP recommendation: implement `see` from screenshot plus AT-SPI element bounds.
Defer deep menu/dialog parity until role mapping is proven.

### Input

Input injection depends heavily on display server and permissions:

- X11: `xdotool`/XTest can move, click, type, and hotkey.
- Wayland: compositor restrictions block global input synthesis. Practical
  options are `ydotool`/uinput, `wtype` for focused text on wlroots-like
  compositors, or compositor-specific APIs.

MVP recommendation: implement one Hyprland-capable input path first:

- semantic AT-SPI actions/direct text where available.
- `UInputDriver` or a small ydotool-style helper for trusted local coordinate
  click/type on Hyprland.
- libei/RemoteDesktop portal as the long-term compositor-mediated route once
  Hyprland/XDPH support is confirmed in practice.
- `X11InputDriver` later for a separate X11 backend.

### Window And App Management

macOS app/window/Space concepts do not map cleanly to Linux:

- App launch can use `.desktop` files, `gio launch`, `gtk-launch`, or subprocesses.
- X11 window listing/focus/move/resize can use EWMH.
- Wayland global window management is compositor-specific or unavailable.
- Dock, menu bar, Spaces, and menu extras are macOS-specific and need Linux names
  or reduced behavior.

MVP recommendation: support app launch, active window detection, and X11 window
focus first. Mark Dock, Spaces, menu extras, and global menu support unavailable
on Linux initially.

### Clipboard

Linux clipboard support should use backend adapters:

- Wayland: `wl-clipboard` or a native protocol binding.
- X11: X selections via Xlib or `xclip`/`xsel`.

### OCR And Annotation

Apple Vision and AppKit image handling need replacement:

- OCR: Tesseract or external OCR provider.
- Image read/write/draw: a portable image package, Cairo, ImageMagick, or a small
  Rust helper if Swift bindings are too weak.

## Proposed Package Shape

```text
Core/
  PeekabooTypes/              # Linux-safe geometry, IDs, errors, JSON helpers
  PeekabooServices/           # Platform-neutral service protocols
  PeekabooAutomationMac/      # Current AppKit/AX/ScreenCaptureKit backend
  PeekabooAutomationLinux/    # New AT-SPI/X11/Wayland/uinput backend
  PeekabooAgentRuntime/       # Shared agent and MCP runtime
Apps/
  CLI/                        # Cross-platform command surface
  Mac/                        # macOS menubar app remains macOS-only
```

This does not have to be the final naming, but the ownership boundary matters:
portable packages must not import Apple frameworks.

## Linux MVP

Target one known environment first:

- Hyprland on Wayland
- Swift 6.2 toolchain installed
- AT-SPI enabled
- `xdg-desktop-portal` available
- `xdg-desktop-portal-hyprland` available
- Practical CLI tools installed: `hyprctl`, `grim`, `slurp`, `wl-clipboard`
- Optional input tools: `ydotool`/uinput, libei/RemoteDesktop portal, or a
  compositor-protocol helper if Hyprland exposes the required virtual input
  protocols in the target environment

Initial commands:

- `peekaboo image --mode screen`
- `peekaboo image --mode area`
- `peekaboo see --mode screen`
- `peekaboo click --coords x,y`
- `peekaboo type --text ...`
- `peekaboo hotkey ...`
- `peekaboo mcp`
- `peekaboo agent` using only the tools above

Deferred commands:

- app/window parity on Wayland
- menu, menubar, dock, dialog, space
- visualizer overlays
- background/process-targeted input
- window-specific capture on Wayland

## First Milestones

1. Initialize submodules and install Swift 6.2 on Linux. Done.
2. Create a compile-only target for portable types. Done in `Core/PeekabooTypes`.
3. Add a standalone Linux CLI for Hyprland state and full-screen capture. Started
   in `Apps/LinuxCLI`.
4. Replace direct `CoreGraphics` usage in shared model/protocol packages with
   portable geometry types.
5. Move macOS concrete services into macOS-only targets without changing CLI
   behavior on macOS.
6. Build a stub Linux service provider that compiles and returns structured
   `unsupported` errors.
7. Implement Linux screen capture for full-screen screenshots.
8. Add AT-SPI element discovery and map roles/bounds into Peekaboo element models.
9. Add coordinate click/type for one Hyprland-capable backend, preferably uinput
   first for a fast local proof, while keeping libei as the preferred long-term
   architecture.
10. Run the MCP server on Linux with the reduced tool registry.
11. Expand to Wayland input only after permission/setup UX is explicit.

## Risk Assessment

The port is technically feasible, but full macOS feature parity is not. Linux
desktop automation is fragmented by design, especially under Wayland. A credible
Linux port should advertise backend capabilities honestly and degrade cleanly
instead of pretending every command works everywhere.

The best first success criterion is not "all Peekaboo commands on Linux." It is:

> On one Linux desktop target, an agent can take a screenshot, identify visible UI
> elements, click/type by coordinates, and run through MCP without macOS APIs in
> the process.
