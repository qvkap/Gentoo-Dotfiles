#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_HOME="${HOME:-/home/$USER}"

echo "Installing Gentoo Dotfiles..."

mkdir -p "$TARGET_HOME/.config"
mkdir -p "$TARGET_HOME/.local/bin"
mkdir -p "$TARGET_HOME/.local/src/nowplaying"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

cp -r "$SCRIPT_DIR/.config/"* "$TARGET_HOME/.config/"
cp -r "$SCRIPT_DIR/.local/bin/"* "$TARGET_HOME/.local/bin/"
cp -r "$SCRIPT_DIR/.local/src/"* "$TARGET_HOME/.local/src/"
cp -r "$SCRIPT_DIR/Pictures/"* "$TARGET_HOME/Pictures/"

cp "$SCRIPT_DIR/.zshrc" "$TARGET_HOME/.zshrc"
cp "$SCRIPT_DIR/.zprofile" "$TARGET_HOME/.zprofile"
cp "$SCRIPT_DIR/.gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0"

chmod +x "$TARGET_HOME/.local/bin/"*
chmod +x "$TARGET_HOME/.config/sway/status.sh"

if command -v gcc >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1; then
    echo "Compiling nowplaying utility..."
    gcc -O2 "$SCRIPT_DIR/.local/src/nowplaying/main.c" $(pkg-config --cflags --libs gio-2.0) -o "$TARGET_HOME/.local/bin/nowplaying"
    chmod +x "$TARGET_HOME/.local/bin/nowplaying"
fi

echo "Installation complete."
