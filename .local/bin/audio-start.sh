#!/bin/sh

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

if ! pgrep -x dbus-daemon >/dev/null 2>&1 || [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
    setsid -f dbus-daemon --session --fork --address="$DBUS_SESSION_BUS_ADDRESS" \
        </dev/null >/dev/null 2>&1
fi

if ! pgrep -x pipewire >/dev/null 2>&1 || [ ! -S "$XDG_RUNTIME_DIR/pipewire-0" ]; then
    killall -q -9 pipewire pipewire-pulse wireplumber 2>/dev/null
    sleep 0.2
    for daemon in pipewire pipewire-pulse wireplumber; do
        setsid -f "$daemon" </dev/null >/dev/null 2>&1
    done
fi
