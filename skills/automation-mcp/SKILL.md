---
name: automation-mcp
description: Control your Mac with mouse, keyboard, screen capture, and window management via an MCP server.
homepage: https://github.com/ashwwwin/automation-mcp
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
        "os": ["darwin"],
        "requires": { "bins": ["mcporter", "bun"] },
        "install":
          [
            {
              "id": "bun",
              "kind": "shell",
              "command": "curl -fsSL https://bun.sh/install | bash",
              "bins": ["bun"],
              "label": "Install Bun runtime",
            },
            {
              "id": "node",
              "kind": "node",
              "package": "mcporter",
              "bins": ["mcporter"],
              "label": "Install mcporter (node)",
            },
          ],
      },
  }
---

# automation-mcp

Desktop automation MCP server for macOS. Provides mouse, keyboard, screenshot,
and window management tools. Use these to operate the computer like a real user.

## Setup

1. Clone and install:

```bash
git clone https://github.com/ashwwwin/automation-mcp.git ~/.local/share/automation-mcp
cd ~/.local/share/automation-mcp && bun install
```

2. Add to mcporter:

```bash
mcporter config add automation --transport stdio --command "bun run ~/.local/share/automation-mcp/index.ts --stdio"
```

3. Grant macOS permissions when prompted:
   - **Accessibility** (System Settings > Privacy & Security > Accessibility)
   - **Screen Recording** (System Settings > Privacy & Security > Screen Recording)

4. Verify:

```bash
mcporter list automation --schema
```

## How to act like a human user

You are not a bot that screenshots, analyzes, clicks, screenshots again.
You are operating this computer as if you were sitting in front of it.
Follow these rules:

### Act continuously, not in screenshot-action loops

A human does not take a screenshot before every click. A human knows where
things are and acts fluidly. You should:

- Take ONE screenshot (or use `getWindows`) at the start to orient yourself.
- Then chain multiple actions without re-screenshotting: move, click, type,
  tab, click again, scroll, type more. Issue many actions in sequence.
- Only screenshot again when something unexpected happens, you navigate to
  a new page/screen, or you need to verify a result.

Bad (robotic):

```
screenshot -> analyze -> click button -> screenshot -> analyze -> type text -> screenshot -> analyze -> click submit
```

Good (human-like):

```
screenshot -> orient yourself -> click field, type email, press tab, type password, press enter -> screenshot to verify success
```

### Use keyboard shortcuts like a power user

Humans rarely click menus. Prefer shortcuts:

- Cmd+T (new tab), Cmd+W (close tab), Cmd+L (focus URL bar)
- Cmd+C/V/X (copy/paste/cut), Cmd+Z (undo), Cmd+S (save)
- Cmd+Space (Spotlight), Cmd+Tab (switch apps)
- Tab/Shift+Tab to move between form fields
- Enter to submit, Escape to cancel
- Cmd+A (select all), Cmd+F (find)

Use `systemCommand` for common ones, `type` with key combos for others.

### Maintain spatial awareness

After orienting with one screenshot, remember where things are. Standard
UI patterns are predictable:

- URL bars are at the top of browsers.
- Close/minimize/maximize buttons are top-left on macOS.
- Tabs are below the title bar.
- Sidebars are on the left, content on the right.
- Buttons like "Submit", "Save", "OK" are bottom-right of dialogs.
- Form fields flow top to bottom.

Use this knowledge to act without re-screenshotting. If you know a text
field is at roughly (x=400, y=300), click there and type. Do not screenshot
just to confirm the field exists.

### Move the mouse naturally

When you need to move and click, use `mouseMovePath` for smooth human-like
cursor movement instead of teleporting. Chain movements logically -- move
to the general area, then click precisely.

### Handle waiting without polling screenshots

Use `waitForImage` to wait for specific UI states (a button appearing, a
page loading) instead of taking repeated screenshots to check. When waiting
for content to load, use a brief `sleep` (via exec) rather than screenshot-
polling.

### Batch your actions

When filling a form, do it all at once:

```bash
mcporter call automation.mouseClick x=400 y=200
mcporter call automation.type text="John Doe"
mcporter call automation.type text="Tab"  # move to next field
mcporter call automation.type text="john@example.com"
mcporter call automation.type text="Tab"
mcporter call automation.type text="MyP@ssw0rd"
mcporter call automation.type text="Return"  # submit
```

Do NOT screenshot between each field.

### Recover gracefully

If an action does not produce the expected result, take a screenshot to
reassess, adjust, and continue. Do not restart the whole sequence.

## Tools

### Mouse

- `mouseClick` -- Click at coordinates (left/right/middle button)
- `mouseDoubleClick` -- Double-click at coordinates
- `mouseMove` -- Move cursor to position
- `mouseGetPosition` -- Get current cursor location
- `mouseScroll` -- Scroll in any direction
- `mouseDrag` -- Drag from current position to target
- `mouseButtonControl` -- Press/release mouse buttons
- `mouseMovePath` -- Follow a smooth path with multiple points

### Keyboard

- `type` -- Type text or press key combinations
- `keyControl` -- Advanced key press/release control
- `systemCommand` -- Common shortcuts (copy, paste, undo, save, selectAll, cut, find, screenshot, ...)

### Screen

- `screenshot` -- Capture full screen, a region, or a specific window
- `screenInfo` -- Get screen dimensions and info
- `screenHighlight` -- Highlight screen regions visually
- `colorAt` -- Get color of any pixel
- `waitForImage` -- Wait for an image to appear on screen (template matching)

### Windows

- `getWindows` -- List all open windows
- `getActiveWindow` -- Get the current active window
- `windowControl` -- Focus, move, resize, or minimize windows

## Usage via mcporter

```bash
mcporter call automation.mouseClick x=500 y=300 button=left
mcporter call automation.type text="Hello world"
mcporter call automation.screenshot
mcporter call automation.systemCommand command=copy
mcporter call automation.getWindows
mcporter call automation.windowControl action=focus title="Safari"
mcporter call automation.mouseScroll x=500 y=300 direction=down amount=3
mcporter call automation.screenInfo
mcporter call automation.colorAt x=100 y=100
```

## Learning and adaptation

After every desktop automation task, record what you learned in
`memory/automation.md` so future tasks are faster:

- **App layouts**: window positions, button coordinates, menu paths for apps
  you interact with frequently. Once you know Safari's URL bar is at y=52,
  never screenshot just to find it again.
- **Working workflows**: end-to-end sequences that succeeded. Store them as
  reusable recipes (e.g., "open Safari, Cmd+L, type URL, Enter, wait 2s").
- **Shortcuts discovered**: keyboard shortcuts that are faster than mouse
  clicks for specific apps.
- **Failures and fixes**: what went wrong and how you recovered (e.g., "dialog
  appeared at y=400 blocking the button; pressed Escape to dismiss first").
- **Screen coordinates**: resolution, scaling factor, and common anchor points.
  After learning the screen layout once, use these coordinates directly.
- **Timing patterns**: how long to wait after actions. Once you know an app
  loads in ~1s, use that delay instead of screenshot-polling.

Before starting an automation task, always run `memory_search` with a query
describing the task. If you have done it before, replay the known workflow
directly without screenshotting first. Only screenshot if the workflow fails
or the context has changed.

Over time you should need fewer and fewer screenshots as you build up a
mental model of the user's screen, apps, and workflows.

## Notes

- Requires macOS with Accessibility and Screen Recording permissions.
- The MCP server runs via Bun in stdio mode through mcporter.
- If Peekaboo is also available, prefer it for complex UI automation workflows
  (annotated element targeting, menu interaction, app lifecycle management).
