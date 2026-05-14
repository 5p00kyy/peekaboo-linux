---
summary: "Project setup, workflow, and implementation plan for the peekaboo-linux fork"
read_when:
  - "setting up the peekaboo-linux fork"
  - "planning Linux development workflow"
  - "creating GitHub issues or milestones for Linux port work"
  - "deciding whether a change should be upstreamable"
---

# peekaboo-linux Project Plan

`peekaboo-linux` should be an independent Linux-first fork of Peekaboo, with
Hyprland as the first supported desktop. The project should preserve Peekaboo's
useful CLI/MCP/agent semantics while replacing the macOS automation backend with
Linux-native backends.

This is not a clean-sheet product and not a one-shot upstream PR. It is a
long-lived fork designed so that the reusable cross-platform seams can still be
contributed upstream if maintainers want them.

## Project Identity

Working identity:

- repository: `peekaboo-linux`
- binary during development: `peekaboo-linux`
- optional compatibility alias later: `peekaboo`
- description: Linux desktop automation CLI/MCP server, forked from Peekaboo and
  initially targeting Hyprland.

Keep the original MIT license and attribution intact. Add Linux-specific
documentation that clearly says this is not the official macOS Peekaboo unless
upstream maintainers explicitly adopt it.

Do not perform a repository-wide rename at the start. Early code should keep
existing module names where that reduces churn. Rename public product surfaces
only when the Hyprland MVP works.

## Fork Setup

Primary references:

- GitHub fork docs:
  <https://docs.github.com/articles/fork-a-repo>
- GitHub CLI `gh repo fork` manual:
  <https://cli.github.com/manual/gh_repo_fork>

The local checkout currently has:

```text
origin -> https://github.com/openclaw/Peekaboo.git
branch -> linux-port-spike
```

Recommended setup once ready to create the remote fork:

```bash
gh auth status
gh repo fork openclaw/Peekaboo --fork-name peekaboo-linux --clone=false --remote=false
git remote rename origin upstream
git remote add origin git@github.com:<your-user-or-org>/peekaboo-linux.git
git fetch upstream
git push -u origin linux-port-spike
```

If HTTPS remotes are preferred:

```bash
git remote add origin https://github.com/<your-user-or-org>/peekaboo-linux.git
```

After setup:

```text
origin   -> your peekaboo-linux fork
upstream -> openclaw/Peekaboo
```

Keep `upstream` read-only in practice. Do not push to upstream from this
workspace.

## Branch Strategy

Use a stable Linux integration branch plus narrow topic branches:

```text
linux/main                 long-lived Linux integration branch
linux/docs-project-plan     planning/docs changes
linux/bootstrap-toolchain   Swift/submodule/toolchain setup
linux/portable-types        geometry and platform-neutral model extraction
linux/service-protocols     portable service protocol split
linux/stub-services         Linux service provider returning unsupported errors
linux/hyprland-ipc          hyprctl/socket client and JSON fixtures
linux/grim-capture          screen/monitor/area/window-visible capture
linux/atspi-tree            AT-SPI element discovery
linux/input-uinput          trusted local coordinate input backend
linux/mcp-minimal           reduced Linux tool registry and MCP startup
```

Rules:

- Keep `main` aligned with upstream unless we intentionally change that later.
- Merge or rebase upstream into `linux/main` regularly.
- Branch off `linux/main`, not upstream `main`, for Linux work.
- Keep PRs small enough to review in one sitting.
- Mark each change as either `upstreamable` or `fork-only`.

## Upstream Sync Workflow

Sync cadence: weekly while upstream is active, and before any broad refactor.

```bash
git switch main
git fetch upstream
git merge --ff-only upstream/main
git push origin main

git switch linux/main
git merge main
git push origin linux/main
```

If Linux changes conflict with upstream macOS changes, resolve the conflict in
the smallest possible compatibility layer. Avoid modifying macOS implementation
files when a platform boundary can absorb the difference.

## Commit And PR Rules

Follow the repo's Conventional Commit style:

```text
docs(linux): add Hyprland backend plan
build(linux): add portable Swift CI
refactor(types): introduce portable geometry
feat(hyprland): list monitors through hyprctl
feat(capture): add grim screen capture backend
test(atspi): add role mapping fixtures
```

Preferred PR structure:

- intent
- files changed
- platform impact: macOS, Linux, both
- tests run
- unsupported/deferred behavior
- upstreamability: upstreamable or fork-only

Avoid mixed PRs that combine renaming, refactoring, and behavior changes.

## Labels

Create labels early so issues stay searchable:

```text
platform/linux
platform/hyprland
platform/x11
backend/capture
backend/input
backend/accessibility
backend/clipboard
backend/windowing
backend/mcp
backend/agent
area/packaging
area/ci
area/docs
area/security
kind/research
kind/refactor
kind/test
kind/bug
kind/feature
risk/high
upstreamable
fork-only
blocked
good-first-linux
```

## Milestones

### M0: Fork Bootstrap

Goal: the project exists as `peekaboo-linux` and has a reproducible development
baseline.

Tasks:

- create GitHub fork
- set `origin` and `upstream`
- initialize submodules
- install Swift 6.2 on the Linux host
- document local Hyprland versions and tools
- add Linux-only docs and roadmap
- add a minimal Linux CI workflow for docs and portable package smoke tests

Exit criteria:

- `gh repo view` points at `peekaboo-linux`
- `swift --version` works locally
- submodules are populated
- docs changes pass lint/checks available in this environment

### M1: Portable Core

Goal: create a package surface that can compile without Apple frameworks.

Tasks:

- introduce portable geometry types
- add macOS-only `CoreGraphics` conversion shims
- remove `CoreGraphics` from shared-looking protocol/model packages
- isolate `AXorcist` and AppKit dependencies behind macOS targets
- remove unconditional `@available(macOS ...)` from shared agent/tool registry

Exit criteria:

- a new portable package builds on Linux CI
- macOS packages still build on macOS CI
- no Linux target imports AppKit, ScreenCaptureKit, ApplicationServices, Vision,
  or CoreGraphics

### M2: Linux Stub Runtime

Goal: the CLI/MCP runtime can start on Linux and report unsupported capabilities.

Tasks:

- add `LinuxPeekabooServices`
- add platform detection
- add platform capability registry
- make unsupported services return structured errors
- make `peekaboo-linux tools` show Linux capability status

Exit criteria:

- Linux binary starts
- MCP server starts with a reduced or unavailable tool list
- unsupported commands fail with actionable messages

### M3: Hyprland State

Goal: query the compositor reliably.

Tasks:

- implement `HyprlandCompositorClient`
- parse `hyprctl -j version`
- parse `hyprctl -j monitors`
- parse `hyprctl -j clients`
- parse `hyprctl -j activewindow`
- parse `hyprctl -j workspaces`
- add fixture tests
- add strict command timeouts

Exit criteria:

- monitor/window/workspace JSON fixtures pass tests
- live local smoke can list monitors and active window

### M4: Capture

Goal: screenshot capture works on Hyprland.

Tasks:

- implement `GrimCaptureService`
- support full-screen capture
- support monitor capture
- support area capture
- support visible-region window capture using Hyprland client bounds
- record occlusion semantics in output metadata

Exit criteria:

- `peekaboo-linux image --mode screen` writes a PNG
- `peekaboo-linux image --mode area --region ...` writes a PNG
- `peekaboo-linux see --mode screen` can use the captured image

### M5: AT-SPI Observation

Goal: `see` returns useful Linux UI element maps.

Tasks:

- choose initial D-Bus approach:
  - Swift D-Bus package
  - small helper process
  - direct C/system D-Bus binding
- connect to AT-SPI bus
- crawl applications/windows/elements
- map roles, names, descriptions, states, actions, and bounds
- merge elements with Hyprland window geometry
- add fixtures for GTK/Qt/Electron where possible

Exit criteria:

- a GTK test app button/text field appears in `see --json`
- bounds line up with screenshot coordinates on the Hyprland host

### M6: Input

Goal: trusted local click/type works on Hyprland.

Tasks:

- implement semantic AT-SPI action/value paths first
- add uinput or ydotool-style backend behind explicit opt-in
- research/prototype libei/RemoteDesktop portal in parallel
- add permission checks for `/dev/uinput`
- add focus guardrails before typing
- expose input backend in `permissions status`

Exit criteria:

- click by coordinates works on Hyprland
- type text works into a known test field
- backend is explicit in logs and JSON metadata

### M7: Minimal Agent/MCP

Goal: agents can use the Linux backend for simple desktop tasks.

Enable:

- `image`
- `see`
- `click`
- `type`
- `hotkey` if input backend supports it
- `scroll` if input backend supports it
- `move`
- `clipboard`
- `sleep`
- `shell`
- `mcp`
- `agent`

Keep unavailable initially:

- `dock`
- `menubar`
- global `menu`
- full `dialog`
- background/process-targeted input
- occlusion-free window capture

Exit criteria:

- MCP server runs on Linux
- agent can screenshot, identify visible UI, and operate a test app

## CI Plan

### Tier 1: Always-On GitHub CI

Runs on hosted Ubuntu/macOS.

- docs lint
- package manifest checks
- portable Swift package build
- JSON fixture tests
- non-desktop unit tests
- macOS CI remains green for upstream behavior

Current repo note: `.github/workflows/commander-multiplatform.yml` already tests
the `Commander` submodule on Ubuntu with Swift 6.2.1. The Linux fork can reuse
that pattern for new portable packages.

### Tier 2: Manual Local Hyprland Smoke

Runs on the developer machine, gated by env vars.

```bash
PEEKABOO_INCLUDE_LINUX_DESKTOP_TESTS=true swift test ...
```

Smoke coverage:

- `hyprctl` version/monitors/clients
- `grim` capture non-empty PNG
- `wl-copy`/`wl-paste` text round trip
- AT-SPI test app detection
- input backend click/type only after explicit opt-in

### Tier 3: Future Self-Hosted Runner

Use a self-hosted Hyprland runner only after the manual smoke tests stabilize.
Desktop automation CI can be flaky and invasive; keep it separate from normal PR
checks.

## Local Toolchain Plan

Swift:

- Use official Swift.org install instructions for Linux.
- Target Swift 6.2 because the repo already uses Swift 6.2 language mode.
- Confirm with `swift --version`.
- Current Arch bootstrap details and test results are tracked in
  [`docs/linux-bootstrap.md`](linux-bootstrap.md).

Submodules:

```bash
git submodule update --init --recursive
```

Hyprland tooling:

```bash
hyprctl -j version
hyprctl -j monitors
hyprctl -j clients
grim - | file -
wl-copy --version
wl-paste --version
```

Input backend prerequisites are intentionally deferred until M6 because they have
security implications.

## Dependency Choices

### Short-Term

Prefer subprocess adapters for command-line tools that are already stable and
well-known:

- `hyprctl`
- `grim`
- `wl-copy`
- `wl-paste`

This keeps the first MVP small and testable.

### Medium-Term

Replace subprocesses where it matters:

- Hyprland socket client instead of `hyprctl` subprocesses.
- Native or helper-based AT-SPI client after D-Bus approach is chosen.
- Long-lived input session for libei if available.

### Avoid Initially

- Native PipeWire frame capture before screenshot MVP works.
- Full Wayland protocol client implementation before grim MVP works.
- Repository-wide rename.
- Rewriting the agent runtime.

## Security Model

Linux desktop automation needs explicit trust boundaries.

Rules:

- no silent input backend selection when it can type/click globally
- no automatic `/dev/uinput` permission changes
- show active input backend in `permissions status`
- log target window before typing
- prefer semantic AT-SPI actions over raw input when possible
- keep shell tool risk documented separately

## First Issues To Create

1. `docs: define peekaboo-linux fork plan`
2. `build: install Swift 6.2 and initialize submodules`
3. `build(linux): add portable package CI scaffold`
4. `refactor(types): add portable geometry types`
5. `refactor(automation): isolate macOS-only AXorcist dependency`
6. `feat(linux): add LinuxPeekabooServices with unsupported capabilities`
7. `feat(hyprland): parse hyprctl monitor and client JSON`
8. `feat(capture): add grim full-screen capture`
9. `feat(capture): add grim area and visible-window capture`
10. `feat(atspi): prototype AT-SPI tree crawl`
11. `feat(clipboard): add wl-copy/wl-paste service`
12. `feat(input): prototype explicit uinput backend`
13. `feat(mcp): start reduced Linux MCP server`
14. `test(linux): add GTK accessibility fixture app`

## First Development Slice

The first slice should avoid risky input and prove the runtime can see the
desktop:

```text
LinuxPeekabooServices
  -> HyprlandCompositorClient
  -> GrimCaptureService
  -> WlClipboardService
  -> UnsupportedInputService
  -> UnsupportedMenu/Dock/Dialog services
```

Target commands:

```bash
peekaboo-linux list screens
peekaboo-linux list windows
peekaboo-linux image --mode screen --path /tmp/peekaboo-linux.png
peekaboo-linux clipboard set --text "hello"
peekaboo-linux clipboard get
```

Once those work, add AT-SPI-backed `see`.
