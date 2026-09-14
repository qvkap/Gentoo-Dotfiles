#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_HOME="${HOME:-/home/$USER}"

SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v doas >/dev/null 2>&1; then
        SUDO_CMD="doas"
    elif command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
    fi
fi

# ====================================================================
# 1. Package Installation (Gentoo / Portage)
# ====================================================================
REQUIRED_PKGS="
gui-wm/swayfx
gui-apps/swaybg
gui-apps/swaylock-effects
gui-apps/fuzzel
gui-apps/mako
gui-apps/grim
gui-apps/slurp
gui-apps/wl-clipboard
x11-misc/gammastep
x11-misc/xsettingsd
gui-apps/foot
app-shells/zsh
app-editors/neovim
media-video/pipewire
media-video/wireplumber
media-sound/cava
games-util/gamemode
dev-util/pkgconf
media-gfx/chafa
"

install_packages() {
    if command -v emerge >/dev/null 2>&1; then
        echo "==> Gentoo detected. Checking and installing required packages..."
        if [ -n "$SUDO_CMD" ]; then
            # Ensure tray is enabled for swayfx
            $SUDO_CMD mkdir -p /etc/portage/package.use
            if ! grep -qs "gui-wm/swayfx.*tray" /etc/portage/package.use/* 2>/dev/null; then
                echo "gui-wm/swayfx tray" | $SUDO_CMD tee -a /etc/portage/package.use/swayfx >/dev/null
            fi
            echo "==> Running emerge for dotfiles dependencies..."
            $SUDO_CMD emerge -uNDq --keep-going $REQUIRED_PKGS || true
        else
            echo "[!] Please run as root/sudo to emerge missing packages."
        fi
    else
        echo "[!] Non-Gentoo system detected. Ensure the following packages are installed:"
        echo "$REQUIRED_PKGS"
    fi
}

echo "=========================================="
echo "      Gentoo Dotfiles Installer           "
echo "=========================================="

printf "Do you want to install required system packages? [y/N]: "
read -r resp
case "$resp" in
    [yY][eE][sS]|[yY])
        install_packages
        ;;
    *)
        echo "Skipping package installation step."
        ;;
esac

# ====================================================================
# 2. Dotfiles Deployment
# ====================================================================
echo "==> Deploying configuration files to $TARGET_HOME..."

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

# ====================================================================
# 3. Build nowplaying helper
# ====================================================================
if command -v gcc >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1; then
    echo "==> Compiling nowplaying utility..."
    gcc -O2 "$SCRIPT_DIR/.local/src/nowplaying/main.c" $(pkg-config --cflags --libs gio-2.0) -o "$TARGET_HOME/.local/bin/nowplaying" 2>/dev/null || true
    chmod +x "$TARGET_HOME/.local/bin/nowplaying" 2>/dev/null || true
fi

echo "==> Installation complete! Restart Sway or run 'swaymsg reload'."
