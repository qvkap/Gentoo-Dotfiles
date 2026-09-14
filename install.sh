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
            # 1. Check and enable GURU overlay (required for SwayFX)
            if ! [ -d "/var/db/repos/guru" ] && ! grep -qs "\[guru\]" /etc/portage/repos.conf/* 2>/dev/null; then
                echo "==> GURU repository not found. Adding GURU overlay..."
                if command -v eselect >/dev/null 2>&1 && eselect repository list >/dev/null 2>&1; then
                    $SUDO_CMD eselect repository enable guru
                    $SUDO_CMD emaint sync -r guru
                else
                    $SUDO_CMD mkdir -p /etc/portage/repos.conf
                    cat << 'EOF_GURU' | $SUDO_CMD tee /etc/portage/repos.conf/guru.conf >/dev/null
[guru]
location = /var/db/repos/guru
sync-type = git
sync-uri = https://github.com/gentoo-mirror/guru.git
masters = gentoo
auto-sync = yes
EOF_GURU
                    $SUDO_CMD emaint sync -r guru
                fi
            fi

            # 2. Ensure keyword unmask for swayfx (~amd64)
            $SUDO_CMD mkdir -p /etc/portage/package.accept_keywords
            if ! grep -qs "gui-wm/swayfx" /etc/portage/package.accept_keywords/* 2>/dev/null; then
                echo "gui-wm/swayfx ~amd64" | $SUDO_CMD tee -a /etc/portage/package.accept_keywords/swayfx >/dev/null
            fi

            # 3. Ensure tray USE flag is enabled for swayfx
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
# 2. Dotfiles Deployment (Selective or All)
# ====================================================================
mkdir -p "$TARGET_HOME/.config"
mkdir -p "$TARGET_HOME/.local/bin"
mkdir -p "$TARGET_HOME/.local/src/nowplaying"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

deploy_item() {
    src="$1"
    dst="$2"
    name="$3"
    printf "Install %s? [Y/n]: " "$name"
    read -r ans
    case "$ans" in
        [nN][oO]|[nN])
            echo "  -> Skipped $name"
            ;;
        *)
            if [ -d "$src" ]; then
                mkdir -p "$dst"
                cp -r "$src/"* "$dst/"
            elif [ -f "$src" ]; then
                mkdir -p "$(dirname "$dst")"
                cp "$src" "$dst"
            fi
            echo "  -> Installed $name"
            ;;
    esac
}

printf "\nInstall all dotfiles and configurations? [Y/n]: "
read -r install_all_choice
case "$install_all_choice" in
    [nN][oO]|[nN])
        echo "==> Selective installation mode (choose what to install):"
        # Individual configs
        deploy_item "$SCRIPT_DIR/.config/sway" "$TARGET_HOME/.config/sway" "Sway & Swaybar configuration"
        deploy_item "$SCRIPT_DIR/.config/foot" "$TARGET_HOME/.config/foot" "Foot terminal configuration"
        deploy_item "$SCRIPT_DIR/.config/fuzzel" "$TARGET_HOME/.config/fuzzel" "Fuzzel app launcher"
        deploy_item "$SCRIPT_DIR/.config/mako" "$TARGET_HOME/.config/mako" "Mako notification daemon"
        deploy_item "$SCRIPT_DIR/.config/nvim" "$TARGET_HOME/.config/nvim" "Neovim config & plugins"
        deploy_item "$SCRIPT_DIR/.config/pipewire" "$TARGET_HOME/.config/pipewire" "PipeWire Bit-Perfect audio config"
        deploy_item "$SCRIPT_DIR/.config/wireplumber" "$TARGET_HOME/.config/wireplumber" "WirePlumber configuration"
        deploy_item "$SCRIPT_DIR/.config/cava" "$TARGET_HOME/.config/cava" "Cava audio visualizer"
        deploy_item "$SCRIPT_DIR/.config/swaylock" "$TARGET_HOME/.config/swaylock" "Swaylock screen locker"
        deploy_item "$SCRIPT_DIR/.config/gamemode.ini" "$TARGET_HOME/.config/gamemode.ini" "GameMode performance settings"
        deploy_item "$SCRIPT_DIR/.config/gtk-3.0" "$TARGET_HOME/.config/gtk-3.0" "GTK-3.0 theme settings"
        deploy_item "$SCRIPT_DIR/.config/gtk-4.0" "$TARGET_HOME/.config/gtk-4.0" "GTK-4.0 theme settings"
        deploy_item "$SCRIPT_DIR/.config/xsettingsd" "$TARGET_HOME/.config/xsettingsd" "XSettingsd daemon config"
        deploy_item "$SCRIPT_DIR/.config/environment.d" "$TARGET_HOME/.config/environment.d" "Environment variables"
        deploy_item "$SCRIPT_DIR/.config/xdg-desktop-portal" "$TARGET_HOME/.config/xdg-desktop-portal" "XDG desktop portal configs"
        deploy_item "$SCRIPT_DIR/.config/xdg-desktop-portal-wlr" "$TARGET_HOME/.config/xdg-desktop-portal-wlr" "XDG portal wlr"
        
        # Shell & Scripts
        deploy_item "$SCRIPT_DIR/.zshrc" "$TARGET_HOME/.zshrc" "Zsh configuration (.zshrc)"
        deploy_item "$SCRIPT_DIR/.zprofile" "$TARGET_HOME/.zprofile" "Zsh login profile (.zprofile)"
        deploy_item "$SCRIPT_DIR/.gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0" "GTK-2.0 theme (.gtkrc-2.0)"
        deploy_item "$SCRIPT_DIR/.local/bin" "$TARGET_HOME/.local/bin" "Helper scripts (.local/bin)"
        deploy_item "$SCRIPT_DIR/Pictures" "$TARGET_HOME/Pictures" "Wallpapers"
        ;;
    *)
        echo "==> Deploying ALL configuration files to $TARGET_HOME..."
        cp -r "$SCRIPT_DIR/.config/"* "$TARGET_HOME/.config/"
        cp -r "$SCRIPT_DIR/.local/bin/"* "$TARGET_HOME/.local/bin/"
        cp -r "$SCRIPT_DIR/.local/src/"* "$TARGET_HOME/.local/src/"
        cp -r "$SCRIPT_DIR/Pictures/"* "$TARGET_HOME/Pictures/"
        cp "$SCRIPT_DIR/.zshrc" "$TARGET_HOME/.zshrc"
        cp "$SCRIPT_DIR/.zprofile" "$TARGET_HOME/.zprofile"
        cp "$SCRIPT_DIR/.gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0"
        ;;
esac

# Permissions
chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true
chmod +x "$TARGET_HOME/.config/sway/status.sh" 2>/dev/null || true

# ====================================================================
# 3. Build nowplaying helper
# ====================================================================
if command -v gcc >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1; then
    if [ -f "$SCRIPT_DIR/.local/src/nowplaying/main.c" ]; then
        echo "==> Compiling nowplaying utility..."
        gcc -O2 "$SCRIPT_DIR/.local/src/nowplaying/main.c" $(pkg-config --cflags --libs gio-2.0) -o "$TARGET_HOME/.local/bin/nowplaying" 2>/dev/null || true
        chmod +x "$TARGET_HOME/.local/bin/nowplaying" 2>/dev/null || true
    fi
fi

echo "\n==> Installation complete! Restart Sway or run 'swaymsg reload'."
