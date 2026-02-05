#!/usr/bin/env bash

# mjolnir install script
# Sets up symlinks for yabai/skhd configs and yspace scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
BIN_DIR="$SCRIPT_DIR/bin"

echo "Installing mjolnir from: $SCRIPT_DIR"
echo ""

# Create ~/bin if it doesn't exist
mkdir -p "$HOME/bin"

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$(basename "$target")"

    if [ -L "$target" ]; then
        # Already a symlink, remove and recreate
        rm "$target"
        echo "  Updating symlink: $name"
    elif [ -e "$target" ]; then
        # Regular file exists, backup and replace
        mv "$target" "${target}.backup"
        echo "  Backed up existing: $name -> ${name}.backup"
    else
        echo "  Creating symlink: $name"
    fi

    ln -s "$source" "$target"
}

echo "Setting up config symlinks..."
create_symlink "$CONFIG_DIR/yabairc" "$HOME/.yabairc"
create_symlink "$CONFIG_DIR/skhdrc" "$HOME/.skhdrc"

echo ""
echo "Setting up bin symlinks..."
for script in "$BIN_DIR"/yspace* "$BIN_DIR"/mjolnir-*; do
    [ -e "$script" ] || continue
    script_name="$(basename "$script")"
    create_symlink "$script" "$HOME/bin/$script_name"
done

echo ""
echo "Making scripts executable..."
chmod +x "$BIN_DIR"/*

echo ""
echo "Done! Installed:"
echo "  Config: ~/.yabairc -> mjolnir/config/yabairc"
echo "  Config: ~/.skhdrc -> mjolnir/config/skhdrc"
echo "  Scripts: ~/bin/yspace* -> mjolnir/bin/yspace*"
echo "  Hook: ~/bin/mjolnir-claude-hook -> mjolnir/bin/mjolnir-claude-hook"
echo ""
echo "Make sure ~/bin is in your PATH. Add this to ~/.zshrc if needed:"
echo '  export PATH="$HOME/bin:$PATH"'
echo ""
echo "Restart skhd and yabai to apply changes:"
echo "  skhd --restart"
echo "  yabai --restart"
