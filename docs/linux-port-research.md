---
summary: "Research-backed Linux and Hyprland port architecture"
read_when:
  - "planning Linux support"
  - "planning Hyprland support"
  - "selecting capture/input/accessibility backends"
  - "designing cross-platform package boundaries"
---

# Linux Port Research: Hyprland First

This document captures the first deep research pass for porting Peekaboo from a
macOS automation stack to Linux, with Hyprland as the initial target.

For fork setup, branch strategy, milestones, issue labels, and CI tiers, see
[`docs/peekaboo-linux-project-plan.md`](peekaboo-linux-project-plan.md).

The goal is not full Linux desktop parity on day one. The goal is a credible,
testable Linux fork that can:

1. Run the CLI/MCP/agent process on Linux.
2. Capture the visible desktop on Hyprland.
3. Read visible UI structure with AT-SPI where applications expose it.
4. Click/type/scroll using an explicit, permission-aware input backend.
5. Report unsupported commands cleanly rather than pretending macOS semantics
   exist on Linux.

## Local Target Inventory

The current development machine is a useful Hyprland test host:

- `XDG_CURRENT_DESKTOP=Hyprland`
- `XDG_SESSION_TYPE=wayland`
- `WAYLAND_DISPLAY=wayland-1`
- `DISPLAY=:1` for Xwayland clients
- Hyprland version: `0.54.3`
- Installed and usable from `PATH`:
  - `hyprctl`
  - `grim`
  - `slurp`
  - `wl-copy`
  - `wl-paste`
  - `gdbus`
  - `busctl`
  - `dbus-send`
- Not currently installed:
  - `wtype`
  - `ydotool`
  - `xclip`
  - `xsel`

`hyprctl` needed escalation from the coding sandbox to query the live compositor,
but works outside the sandbox. `hyprctl -j monitors` reports a focused `DP-1`
monitor at `2560x1440`, scale `1.00`, with Hyprland global coordinates starting
at `(0, 0)`.

## Source Research

Primary references used:

- Hyprland hyprctl docs:
  <https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/>
- Hyprland IPC docs:
  <https://wiki.hypr.land/IPC/>
- Hyprland dispatcher docs:
  <https://wiki.hypr.land/Configuring/Dispatchers/>
- Hyprland XDG Desktop Portal docs:
  <https://wiki.hypr.land/0.50.0/Hypr-Ecosystem/xdg-desktop-portal-hyprland/>
- xdg-desktop-portal API docs:
  <https://flatpak.github.io/xdg-desktop-portal/docs/api-reference>
- xdg-desktop-portal Screenshot:
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Screenshot.html>
- xdg-desktop-portal ScreenCast:
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html>
- xdg-desktop-portal RemoteDesktop:
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html>
- xdg-desktop-portal InputCapture:
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.InputCapture.html>
- libei protocol/API:
  <https://libinput.pages.freedesktop.org/libei/>
  <https://libinput.pages.freedesktop.org/libei/api/index.html>
- AT-SPI development docs:
  <https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/index.html>
  <https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/doc-org.a11y.atspi.Action.html>
  <https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/doc-org.a11y.atspi.Component.html>
- Ubuntu AT-SPI DBus reference:
  <https://documentation.ubuntu.com/desktop/en/latest/reference/accessibility/dbus/>
- Linux uinput docs:
  <https://kernel.org/doc/html/latest/input/uinput.html>
- grim:
  <https://github.com/emersion/grim>
- slurp:
  <https://github.com/emersion/slurp>
- wl-clipboard:
  <https://github.com/bugaevc/wl-clipboard>
- xdg-desktop-portal-hyprland repository:
  <https://github.com/hyprwm/xdg-desktop-portal-hyprland>

## Hyprland Capabilities

Hyprland is better than a generic Wayland target for this project because it has
stable-ish first-party control surfaces:

- `hyprctl` is installed with Hyprland and can emit JSON with `-j`.
- Info commands include `monitors`, `workspaces`, `clients`, `activewindow`,
  `cursorpos`, `layers`, `devices`, and `binds`.
- Dispatchers can control focus, workspace selection, cursor movement, focused
  window movement/resizing, selected-window movement/resizing, window focus by
  matcher, monitor focus, fullscreen, close, and more.
- Hyprland exposes two UNIX sockets:
  - `.socket.sock` for hyprctl-like request/response control.
  - `.socket2.sock` for live events like workspace changes, focused monitor,
    active window, fullscreen changes, monitor added/removed, and window events.

Important caveat: Hyprland documents that control socket requests are evaluated
synchronously; clients must open, write, read, and close promptly. A long-lived
or wedged connection can stall the compositor until timeout. Peekaboo should use
short-lived calls or a carefully written IPC client with strict timeouts.

### Hyprland Backend Responsibilities

`HyprlandCompositorClient` should own:

- session detection:
  - `XDG_CURRENT_DESKTOP`
  - `XDG_SESSION_DESKTOP`
  - `HYPRLAND_INSTANCE_SIGNATURE`
  - `XDG_RUNTIME_DIR`
- version/capability probing
- monitor enumeration from `hyprctl -j monitors`
- window enumeration from `hyprctl -j clients`
- focused window from `hyprctl -j activewindow`
- cursor position from `hyprctl -j cursorpos`
- workspace enumeration from `hyprctl -j workspaces`
- dispatchers for:
  - `focuswindow`
  - `workspace`
  - `movetoworkspace`
  - `movewindowpixel`
  - `resizewindowpixel`
  - `movecursor`
  - `closewindow` or `killactive` only when semantics are clear
- event subscription from `.socket2.sock` for cache invalidation

Do not shell out forever. The first implementation can call `hyprctl`, but the
production implementation should speak directly to the sockets once behavior is
well understood.

## Capture Backends

### Recommended Order

For Hyprland MVP:

1. `grim` for deterministic noninteractive screenshots.
2. Hyprland/XDPH portal/PipeWire for future video/live capture and user-approved
   screen sharing flows.
3. X11 capture only for an X11 backend, not for Hyprland-native automation.

### `grim`

`grim` can capture all outputs, a named output, or a region:

- all outputs: `grim -`
- output: `grim -o DP-1 -`
- region: `grim -g "x,y widthxheight" -`

This maps well to Peekaboo's current `image`/`see` MVP:

- `image --mode screen`: `grim -`
- `image --mode screen --screen-index N`: map index to Hyprland monitor name,
  then `grim -o <name> -`
- `image --mode area --region x,y,w,h`: convert to grim geometry and run
  `grim -g "x,y wxh" -`
- `image --mode window`: get bounds from `hyprctl -j clients`, then capture by
  region; this is not occlusion-free, so report it as "visible-region window
  capture" rather than native window capture.

The first Swift implementation can use a subprocess bridge for `grim`, because
it provides PNG bytes directly. Later, a native Wayland screencopy client may
replace it if dependency and packaging constraints justify the work.

### XDG Screenshot Portal

The portal Screenshot backend supports targets for screen, user-selected window,
user-selected area, and active window, depending on the backend's advertised
`AvailableTargets`. It returns a URI to the screenshot. This is useful for a
permission-mediated fallback but less ergonomic for an automation loop because
interactive portal UI can interrupt every capture unless persistence is
supported and configured.

### ScreenCast Portal And PipeWire

The ScreenCast portal creates sessions, selects monitor/window/virtual sources,
starts a user-approved session, and returns PipeWire streams. Version 6 adds a
stable `pipewire-serial` stream property that clients should prefer over the
node ID. This matters for Peekaboo's `capture` live/video tooling and future
watch mode.

For MVP screenshots, `grim` is simpler. For live capture and high-FPS watch
sessions, the portal/PipeWire path is the correct long-term backend.

### xdg-desktop-portal-hyprland

XDPH provides Hyprland's portal backend for screen sharing, global shortcuts, and
related desktop integration. Hyprland's own docs say XDPH starts via D-Bus after
Hyprland starts, and that features available only on Hyprland, such as window
sharing, will not work on other wlroots compositors.

For Peekaboo, this means:

- Require `xdg-desktop-portal-hyprland` for the Hyprland backend's portal path.
- Detect portal availability with D-Bus introspection.
- Keep `grim` as a direct capture path for local automation where possible.
- Provide clear errors when XDPH or PipeWire is missing.

## Accessibility And Element Detection

macOS AX should map to AT-SPI2 on Linux.

AT-SPI exposes D-Bus interfaces for accessible objects:

- `Accessible`: name, role, description, parent/children, state set, process ID,
  interfaces, toolkit metadata.
- `Component`: visible GUI components, screen-relative extents, point hit testing,
  focus grabbing, scroll-to-point, size/position changes where supported.
- `Action`: lists and invokes actions such as a button click.
- `EditableText`: set/insert/delete/paste text content.
- `Text`: read text content and text bounds.
- `Value`: get/set numeric value ranges for sliders and similar widgets.

The most important mapping:

```text
AT-SPI Accessible + Component + Action
  -> Peekaboo UIElement / DetectedElement

Component.GetExtents(coord_type: screen)
  -> element bounds

Action.GetActions / DoAction
  -> perform-action

EditableText.SetTextContents / InsertText
  -> set-value / direct text insertion
```

Coverage caveats:

- Native GTK/Qt apps are the best case.
- Electron/Chromium apps often expose useful trees, but quality varies.
- Some Wayland-native surfaces, games, terminal UIs, custom renderers, and
  sandboxed apps may expose little or nothing.
- AT-SPI bounds and screenshot coordinates must be tested carefully under
  fractional scaling, multi-monitor layouts, and Xwayland windows.

### Element Strategy

The Linux `see` pipeline should combine:

1. Capture screenshot with `grim`.
2. Query Hyprland active window/client geometry.
3. Crawl AT-SPI applications and windows.
4. Keep only visible or relevant elements by intersecting with the target bounds.
5. Assign stable Peekaboo IDs by role/type order, like macOS does today.
6. Use screenshot-based annotation as a visual fallback when AT-SPI has gaps.

AT-SPI should be a separate adapter, not baked into the Hyprland adapter:

```text
LinuxDesktopObservationService
  - LinuxScreenCaptureService
  - LinuxAccessibilityService
  - LinuxCompositorClient
  - SnapshotManager
```

This keeps the same accessibility layer reusable for GNOME/KDE/X11 later.

## Input Backends

Input is the hardest part. There is no universal, permissionless Wayland
equivalent of `CGEvent` or `xdotool`, and that is intentional.

### Backend Matrix

| Backend | Scope | Strengths | Weaknesses | MVP Role |
| --- | --- | --- | --- | --- |
| AT-SPI Action/EditableText | Element actions and direct values | Safe, semantic, no fake hardware input | Only works for accessible apps/elements | First choice for `perform-action`, `set-value`, some `click/type` |
| Hyprland dispatchers | Compositor focus/window/cursor control | Native Hyprland, good for focus/window/workspace | Not general text/click input | First choice for window/workspace/focus/cursor movement |
| libei via RemoteDesktop portal | Wayland emulated input | Proper long-term direction, compositor-controlled | Needs compositor/portal support and user approval; not fire-and-forget | Research/prototype after basic MVP |
| uinput / `ydotool` style | Kernel-level virtual devices | Works below Wayland/X11, can click/type globally | Requires `/dev/uinput` permissions; bypasses compositor policy; no focus awareness | Practical fallback for trusted local setup |
| X11 XTest / `xdotool` | X11 sessions and maybe Xwayland windows | Mature and simple | Not native Wayland; not useful for pure Hyprland surfaces | Later X11 backend |
| `wtype` / virtual-keyboard protocol | Text typing on wlroots-like compositors | Simple when protocol is available | Protocol support varies; not a full automation stack | Optional focused-text helper |

### Recommended Input Order

For each requested user action:

1. Use semantic AT-SPI action if target is an accessible element and the requested
   action exists.
2. Use AT-SPI value/text interfaces for settable fields.
3. For coordinate click/type/drag:
   - use a configured Linux input driver.
   - prefer libei/RemoteDesktop when Hyprland support is confirmed.
   - otherwise support uinput with explicit setup.
4. For focus/window/workspace operations:
   - use Hyprland dispatchers.

### libei And RemoteDesktop

libei is designed for emulated input in the Wayland stack. The compositor owns
the server side (`libeis`), the automation client uses `libei`, and the portal
can broker access. This is the principled long-term route because the compositor
can authenticate, pause, filter, or discard emulated input.

Important constraints from the libei docs:

- libei is not a short-lived fire-and-forget model like `xdotool`; the client
  negotiates devices and may need to stay alive.
- Pure libei does not give window focus/query control; focus still needs a
  compositor-specific channel such as Hyprland IPC.
- Keyboard layout and modifier state need careful handling.

For Peekaboo, use libei as a long-lived `LinuxInputSession` owned by the service
container, not as a subprocess per click.

### uinput

Linux uinput can emulate input devices from userspace by writing to
`/dev/uinput`. It works below the display server and can therefore work under
Hyprland, GNOME, KDE, X11, and tty. The tradeoff is security and setup: access to
`/dev/uinput` is normally restricted, and events look like physical device input
to the compositor.

For a local trusted developer workflow, uinput may be the fastest route to an
end-to-end Hyprland MVP. For distribution, it needs:

- explicit opt-in
- permission checks
- udev group instructions or a helper daemon
- visible warnings in `peekaboo permissions status`
- tests that avoid typing into the wrong focused app

## Clipboard

For Hyprland MVP:

- Use `wl-copy` and `wl-paste` subprocesses for text and binary MIME data.
- Later, add native Wayland clipboard protocol support if needed.
- Treat portal Clipboard as relevant mainly when using RemoteDesktop/InputCapture
  sessions; it does not create its own session.

MVP operations:

- `clipboard get`: `wl-paste --no-newline` for text, optional MIME query later.
- `clipboard set`: pipe bytes into `wl-copy`.
- `clipboard clear`: `wl-copy --clear`, if available.
- `save/restore`: keep an in-process representation where possible; cross-process
  persistence is weaker than NSPasteboard slots and should be documented.

## Window, App, Workspace, And Menu Semantics

macOS concepts do not map one-to-one.

### Hyprland Window Service

Use Hyprland clients as the source of truth:

- `windowID`: Hyprland window address or a stable derived ID; avoid pretending it
  is a CoreGraphics ID.
- `title`: Hyprland client title.
- `app`: class/initialClass where available.
- `bounds`: client `at` + `size`.
- `workspace`: workspace ID/name.
- `monitor`: monitor ID/name.
- `floating`, `fullscreen`, `mapped`, `hidden`, `focusHistoryID` as Linux-only
  metadata.

Expose this through the existing `ServiceWindowInfo` shape at first, but plan a
portable model rename:

```text
PlatformWindowID
  case macCGWindow(UInt32)
  case hyprlandAddress(String)
  case x11Window(UInt64)
```

The current `windowID: Int` will become a liability for Hyprland addresses.

### App Service

Linux "application" is less defined than macOS bundle apps. For MVP:

- running apps: group Hyprland clients and `/proc` processes by PID/class
- launch: use `.desktop` files via `gio launch`/`gtk-launch` where available, or
  shell command fallback
- activate: focus first matching Hyprland client
- quit: SIGTERM by PID, with force as SIGKILL, but expose warning
- hide/unhide: unsupported on Hyprland unless mapped to minimize/special
  workspace behavior later

### Menus, Dock, Dialogs, Spaces

Initial status:

- `space`: map to Hyprland workspaces, but rename user-facing Linux docs to
  "workspace" where possible.
- `dock`: unsupported in core Hyprland; panels/launchers vary.
- `menubar`: unsupported; Hyprland does not have a global app menu bar.
- `menu`: use AT-SPI menus when exposed by apps, not compositor-level menus.
- `dialog`: detect via AT-SPI roles/window types; no macOS file dialog parity.

## Cross-Platform Architecture

The existing architecture already has a useful service-provider shape, but too
many packages import Apple-only APIs or `CoreGraphics`:

- `PeekabooServiceProviding` aggregates protocol-based services.
- `PeekabooServices` currently constructs concrete macOS services directly.
- The CLI and MCP tools call service protocols, which is good.
- The protocols and models leak Apple geometry and IDs, which blocks Linux.
- `ToolRegistry` is currently `@available(macOS 14.0, *)`, which blocks Linux
  even before the service backend is considered.

### Target Package Layout

```text
Core/
  PeekabooTypes/
    Portable geometry, IDs, errors, JSON coding, capability metadata.

  PeekabooServiceProtocols/
    Capture, automation, app/window, clipboard, permissions protocols.
    No AppKit, CoreGraphics, ScreenCaptureKit, Vision, or Darwin-only APIs.

  PeekabooAutomationMac/
    Existing macOS concrete implementations.

  PeekabooAutomationLinux/
    Linux service container and backend selection.

  PeekabooPlatformHyprland/
    Hyprland IPC, compositor state, dispatchers.

  PeekabooAccessibilityAT_SPI/
    AT-SPI DBus client and role/action mapping.

  PeekabooAgentRuntime/
    Shared agent/MCP/tool registry. Depends only on service protocols.
```

The exact names can change, but the dependency rule should not:

> Portable packages must not import Apple frameworks.

### Service Construction

Replace direct `PeekabooServices()` platform construction with a factory:

```swift
public enum PeekabooServicesFactory {
    @MainActor
    public static func makeDefault() throws -> any PeekabooServiceProviding {
        #if os(macOS)
        return MacPeekabooServices()
        #elseif os(Linux)
        return try LinuxPeekabooServices.detect()
        #else
        throw PlatformError.unsupported
        #endif
    }
}
```

Linux service detection:

```text
if XDG_CURRENT_DESKTOP contains Hyprland and hyprctl works:
  compositor = HyprlandCompositorClient
else if DISPLAY exists and X11 libs/tools are available:
  compositor = X11CompositorClient
else:
  compositor = UnsupportedCompositorClient

capture = GrimCaptureService if grim exists and WAYLAND_DISPLAY exists
accessibility = ATSPIAccessibilityService if org.a11y.Bus is available
clipboard = WlClipboardService if wl-copy/wl-paste exist
input = configured backend:
  atspi-only | libei | uinput | unsupported
```

### Capability Registry

Linux needs first-class capabilities so the CLI and MCP tools can hide or return
clear unavailable messages.

Example:

```swift
struct PlatformCapabilities: Codable, Sendable {
    var captureScreen: Capability
    var captureArea: Capability
    var captureWindowVisibleRegion: Capability
    var captureWindowOcclusionFree: Capability
    var accessibilityTree: Capability
    var semanticActions: Capability
    var coordinateClick: Capability
    var textInput: Capability
    var hotkeys: Capability
    var windowFocus: Capability
    var windowMoveResize: Capability
    var workspaces: Capability
    var menus: Capability
    var dock: Capability
}
```

Each capability should include:

- `supported`
- `backend`
- `requiresUserSetup`
- `requiresInteractiveConsent`
- `diagnostic`
- `installHint`

This is how `peekaboo tools`, `peekaboo permissions status`, MCP tool metadata,
and agent prompts stay honest.

## Forking And Upstream Strategy

This is a large fork. Treat it like a long-lived port branch, not a throwaway
experiment.

### Git Remotes

Recommended remotes:

```text
origin      user's Linux port fork
upstream    https://github.com/openclaw/Peekaboo.git
```

Keep the current `main` tracking upstream. Do port work on topic branches:

```text
linux/main
linux/types
linux/service-protocols
linux/hyprland-capture
linux/atspi
linux/input-uinput
linux/mcp-minimal
```

### Submodules

The repo uses submodules. Do not edit submodule contents from the superproject.
For Linux viability, each submodule must be checked:

- `Commander`: must build on Linux or be forked/replaced.
- `Tachikoma`: likely valuable and should be made Linux-compatible if it is not.
- `TauTUI`, `Swiftdansi`: likely portable but must be verified.
- `AXorcist`: macOS accessibility-specific; should become macOS-only.

Linux package extraction should reduce unconditional dependency on `AXorcist`.

### PR Strategy

Keep PRs small enough to review:

1. Docs and capability matrix.
2. Portable geometry types.
3. Move macOS implementations behind `Mac` target without behavior changes.
4. Linux stub services compile.
5. Hyprland monitor/window listing.
6. `grim` screen/area capture.
7. AT-SPI tree crawl.
8. Reduced `see` command.
9. Coordinate click backend.
10. MCP reduced tool registry.

Each step should preserve macOS behavior.

## Implementation Milestones

### Milestone 0: Environment

- Install Swift 6.2 on the Linux machine.
- Initialize submodules.
- Verify `swift test` can run for at least a new portable package.
- Record Hyprland, xdg-desktop-portal-hyprland, PipeWire, and AT-SPI versions.

### Milestone 1: Portable Types

- Add `PeekabooGeometry`:
  - `PBPoint`
  - `PBSize`
  - `PBRect`
  - `PBInsets`
- Add conversion shims:
  - `PBRect <-> CGRect` in macOS-only target
- Replace `CoreGraphics` in portable protocols/models.
- Add compile-only Linux CI target once Swift is present.

### Milestone 2: Linux Service Stubs

- Add `LinuxPeekabooServices`.
- Implement all service protocols with `unsupported` responses.
- Make CLI/MCP start on Linux with no working automation yet.
- Make `peekaboo tools` show capabilities/unavailable reasons.

### Milestone 3: Hyprland Compositor Client

- Implement `HyprlandCompositorClient`.
- Parse `hyprctl -j monitors`.
- Parse `hyprctl -j clients`.
- Parse focused window/workspace/cursor.
- Add strict timeouts.
- Add fixture tests with captured JSON.

### Milestone 4: Capture

- Implement `GrimCaptureService`.
- Support:
  - full screen
  - monitor by index/name
  - rectangular area
  - visible-region window capture from Hyprland client bounds
- Add image byte tests using mocked subprocess output.
- Add live local smoke test gated by `PEEKABOO_INCLUDE_LINUX_DESKTOP_TESTS=true`.

### Milestone 5: AT-SPI

- Implement a DBus client or small helper for AT-SPI.
- Crawl applications/windows/elements.
- Map roles, names, descriptions, states, actions, bounds.
- Implement `perform-action` via `Action.DoAction`.
- Implement `set-value` for `EditableText`/`Value` where available.
- Merge with screenshot snapshots.

### Milestone 6: Input

Start with one explicit backend:

- Fastest practical route: uinput helper / `ydotool` style backend.
- Long-term route: libei RemoteDesktop session if Hyprland/XDPH supports it
  sufficiently for our target version.

Implement:

- click
- move
- scroll
- type text
- hotkey

Add guardrails:

- require explicit input backend config
- check focused window before typing
- offer dry-run logs
- visible permission status

### Milestone 7: Reduced Agent/MCP

Enable only tools with working Linux capabilities:

- `image`
- `see`
- `click`
- `type`
- `hotkey`
- `scroll`
- `move`
- `clipboard`
- `sleep`
- `shell`
- `mcp`
- `agent`

Disable or mark unavailable:

- `dock`
- `menubar`
- `menu` until AT-SPI menu mapping is good
- `dialog` until AT-SPI dialog mapping is good
- `space` until renamed/mapped to Hyprland workspaces
- background-targeted input

## Testing Strategy

### Unit Tests

- portable geometry conversions
- Hyprland JSON parsing fixtures
- AT-SPI role mapping fixtures
- capability selection
- unsupported errors
- command output compatibility

### Local Desktop Smoke Tests

Gate these behind an env var:

```bash
PEEKABOO_INCLUDE_LINUX_DESKTOP_TESTS=true swift test ...
```

Suggested smoke tests:

- capture screen and assert non-empty PNG
- capture known rectangle
- list Hyprland monitors
- list Hyprland clients
- start a simple GTK test app and find a button via AT-SPI
- click a button through AT-SPI action
- type into a text field through direct text interface or configured input backend

### Test Fixture App

Create a small Linux fixture app, preferably GTK or Qt, with:

- button
- text field
- checkbox
- slider
- menu
- dialog

This mirrors the macOS automation fixture approach but makes accessibility
behavior deterministic.

## Biggest Risks

1. **Input under Wayland**: Hyprland may not expose a portal/libei path matching
   our needs today. uinput works but has trust/setup costs.
2. **Accessibility coverage**: AT-SPI quality varies by toolkit and app.
3. **Coordinate mismatches**: multi-monitor and scaling must be tested early.
4. **Window capture semantics**: `grim` region capture captures visible pixels,
   not occlusion-free window contents.
5. **Swift package portability**: Core packages and submodules may require
   meaningful Linux work before any backend code runs.
6. **Fork drift**: a broad rewrite will become unmergeable. The port must extract
   platform boundaries in reviewable increments.

## Recommended First Build Slice

The first useful implementation should be narrow:

```text
Hyprland + grim + AT-SPI + wl-clipboard + unsupported input
```

Then add one input backend:

```text
trusted local uinput backend
```

Only after the end-to-end agent loop works should we invest deeply in the
portal/libei path.

The earliest demo should be:

```bash
peekaboo image --mode screen --path /tmp/hyprland.png
peekaboo see --mode screen --json
peekaboo clipboard set --text "hello from Peekaboo Linux"
peekaboo click --coords 100,100
peekaboo type --text "hello"
```

For the agent:

```bash
peekaboo agent "Take a screenshot, identify the focused app, and describe the visible UI."
```

Then:

```bash
peekaboo agent "Open a test GTK app, click the button, and type hello into the text field."
```
