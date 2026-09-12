export XDG_CURRENT_DESKTOP=sway
export GTK_THEME=WhiteSur-Dark
export QT_QPA_PLATFORMTHEME=qt5ct

if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec sway
fi
