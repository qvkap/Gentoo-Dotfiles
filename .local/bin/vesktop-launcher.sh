#!/bin/bash
export XDG_CURRENT_DESKTOP=sway
export WAYLAND_DISPLAY=wayland-1
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

# Modern RAM-Saving & Low-Memory Flags for Electron/Chromium (Vesktop)
exec /opt/vesktop/vesktop \
    --ozone-platform=wayland \
    --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,ParallelMarking,ParallelScavenge \
    --disable-features=MediaSessionService,ScreenAIOCREnabled \
    --js-flags="--max-old-space-size=256 --optimize-for-size --expose-gc" \
    --enable-low-end-device-mode \
    --disable-renderer-backgrounding \
    --process-per-site \
    --disable-breakpad \
    --disable-crash-reporter \
    --no-crash-upload \
    "$@"
