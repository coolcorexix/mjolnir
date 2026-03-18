# Mjolnir

**Summon any open window anywhen (on macOS).**

## The Problem

If you're a developer working on a single monitor, you know the pain:

- **Multiple IDE instances** — Cmd+Tab has unpredictable outcomes. You're at VS Code instance 1 on Space X, then switch to Slack on Space Y. When you Cmd+Tab to go back, you end up at VS Code instance 2 on Space Y instead of where you were.

- **Multiple tabs in terminal emulator** — Tab management quickly goes wild. Developers end up browsing through tabs one by one. Cmd+Tab doesn't help here at all.

- **Windows scattered across Spaces** — Your windows are everywhere and you can't remember where.

- **Built-in solutions fall short** — Neither macOS native navigation nor popular apps like Raycast solve this problem deep enough.

You end up playing a frustrating game of window hunting instead of actually coding.

## The Solution

**Mjolnir** removes the pain in your workflow: instead of *finding* windows, you *request* exactly which one you want.

Press `Alt+S` and a floating picker appears:

```
Code: saleshood
Code: totomo-webapp
Code: my-side-project
iTerm2: dev-server
iTerm2: claude-code
Chrome: GitHub - Pull Request #42
Slack
Telegram
```

Type a few characters, hit Enter, and you're there. Instantly.

- **VS Code/Cursor** — Shows the actual repo/workspace name, not just "Code"
- **iTerm2** — Shows your custom tab names (set with Cmd+Shift+I)
- **Google Chrome** — Shows individual tab titles
- **Everything else** — Just works

No more hunting. No more guessing. Just type what you want.

### Claude Code Integration

When using [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Mjolnir shows status indicators:

- **⏳** — Claude is waiting for your approval (permission request)
- **✅** — Claude finished and is ready for your review

These appear in both the picker and the optional menu bar app.

## Requirements

- macOS (tested on Sequoia 15.x)
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools (for building menu bar app)

## Installation

### 1. Install dependencies

```bash
brew install koekeishiya/formulae/yabai
brew install koekeishiya/formulae/skhd
brew install choose-gui
brew install jq
```

### 2. Clone and install

```bash
git clone https://github.com/coolcorexix/mjolnir.git
cd mjolnir
./install.sh
```

### 3. Add ~/bin to your PATH

Add this line to your `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/bin:$PATH"
```

Then reload your shell:

```bash
source ~/.zshrc
```

### 4. Grant permissions

Both yabai and skhd need Accessibility permissions:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click **+** and add `/opt/homebrew/bin/yabai`
3. Click **+** and add `/opt/homebrew/bin/skhd`
4. Make sure both are enabled

### 5. Enable "Displays have separate Spaces"

1. Open **System Settings** → **Desktop & Dock** → **Mission Control**
2. Enable **"Displays have separate Spaces"**
3. **Log out and log back in** (required for this setting)

### 6. Start services

```bash
yabai --start-service
skhd --start-service
```

### 7. Try it!

Press **Alt+S** to open the picker. Start typing to filter, Enter to switch.

## Optional: Claude Code Integration

If you use Claude Code, you can enable status indicators that show when Claude needs your attention.

### Setup Claude Code Hook

Add the hooks section to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          { "type": "command", "command": "~/bin/mjolnir-claude-hook" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "~/bin/mjolnir-claude-hook" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/bin/mjolnir-claude-hook" }
        ]
      }
    ]
  }
}
```

If you already have a `settings.json`, merge the `hooks` section into it.

### Optional: Menu Bar App

For a persistent status indicator in your menu bar:

```bash
cd menubar
./build.sh --install --launch
```

The menu bar app shows:
- Number of Claude Code sessions waiting for approval
- Number of sessions that have completed

## Usage

### Keyboard shortcut

| Shortcut | Action |
|----------|--------|
| `Alt+S` | Open the floating picker |
| Type | Filter the list |
| `Enter` | Switch to selected window |
| `Esc` | Cancel |

### CLI commands

```bash
# List all spaces/windows
yspace list

# Jump directly by name
yspace saleshood
yspace Slack
```

### Naming your iTerm2 tabs

For iTerm2 tabs to show meaningful names:

1. Press **Cmd+Shift+I** in iTerm2
2. Enter a name like "dev-server" or "ssh-prod"
3. That name will now appear in the picker

## How it works

- **yabai** — Queries window information (IDs, titles, apps). No SIP disable needed.
- **skhd** — Registers the `Alt+S` global hotkey
- **choose** — Renders the floating Spotlight-like picker
- **Native activation** — Switches spaces instantly using macOS APIs

The key insight: we use yabai only for *querying* window info, not for space management. This means no SIP modifications required.

## Configuration

The install script creates symlinks for configuration files:

- `~/.yabairc` → yabai configuration (includes BSP tiling layout)
- `~/.skhdrc` → skhd hotkey configuration

If you only want the window switcher without BSP tiling, edit `~/.yabairc` and change:
```bash
layout                       float
```

## Troubleshooting

### "yabai-msg: failed to connect to socket"

yabai isn't running:
```bash
yabai --start-service
```

### "could not access accessibility features"

Grant Accessibility permissions in System Settings → Privacy & Security → Accessibility.

### Alt+S doesn't work

skhd isn't running or needs permissions:
```bash
skhd --restart-service
```

### Wrong iTerm2 tab name showing

Make sure you've set a custom tab title with **Cmd+Shift+I**. Without a custom title, it shows the running process name.

### yspace commands not found

Make sure `~/bin` is in your PATH:
```bash
echo $PATH | grep -q "$HOME/bin" || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Uninstall

```bash
# Stop services
yabai --stop-service
skhd --stop-service

# Remove symlinks
rm -f ~/.yabairc ~/.skhdrc
rm -f ~/bin/yspace*
rm -f ~/bin/mjolnir-*

# Optional: remove menu bar app
rm -rf ~/Applications/MjolnirBar.app

# Optional: remove dependencies
brew uninstall yabai skhd choose-gui jq
```

## Changelog

### 2025-03-18

- **Fix**: macOS compatibility for `yspace-cache` — replaced Linux `flock` with `mkdir`-based locking
- **Fix**: AppleScript heredoc syntax to avoid quote escaping issues
- **Add**: Background cache updater (`yspace-cache`) for instant picker response
- **Add**: `mjolnir-restart` script for robust service management (handles stale PID files)
- **Add**: Health checks in MjolnirBar — auto-restarts unhealthy yabai/skhd
- **Add**: "Open App Switcher" menu item in MjolnirBar

### 2025-03-17

- **Add**: Done status (✅) for completed Claude Code sessions
- **Add**: VSCode/Cursor window detection for Claude Code waiting indicators
- **Add**: MjolnirBar menu bar app with Claude Code integration

## License

MIT
