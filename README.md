# dotfiles

Minimalist, dark-themed Wayland configuration for Gentoo Linux with SwayFX.

## Components
- **WM**: SwayFX (rounded corners, subtle blur, shadows disabled)
- **Bar**: Swaybar with custom real-time status (`.config/sway/status.sh`)
- **Terminal**: Foot (`SF Mono` font)
- **Editor**: Neovim with Lazy.nvim and Treesitter
- **Launcher**: Fuzzel
- **Notifications**: Mako (`SF Pro Text`, dark theme, mouse controls)
- **Lockscreen**: Swaylock-effects (frosted blur, clock, ring indicator)
- **Audio**: PipeWire & WirePlumber with Bit-Perfect Hi-Res audio (up to 192kHz/32-bit)
- **Theme**: Universal Dark (WhiteSur-Dark, Breeze-Dark icons, SF Pro)
- **Tools**: `nowplaying` (custom C tool for terminal album art via Chafa)

## Install
```bash
# Symlink or copy to home directory
cp -r .config .local .zshrc .zprofile .gtkrc-2.0 Pictures ~
```
