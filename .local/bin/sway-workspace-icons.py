#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

# Иконки из Nerd Font (Symbols Nerd Font)
APP_ICONS = {
    "firefox": "󰈹",
    "firefox-bin": "󰈹",
    "foot": "",
    "com.ayugram.desktop": "󰭹",
    "ayugram": "󰭹",
    "telegram": "󰭹",
    "telegramdesktop": "󰭹",
    "org.telegram.desktop": "󰭹",
    "vesktop": "󰙯",
    "discord": "󰙯",
    "Throne": "󰖂",
    "org.vinegarhq.Sober": "󰊴",
    "sober": "󰊴",
    "steam": "󰓓",
    "com.valvesoftware.Steam": "󰓓",
    "obs": "󰑋",
    "com.obsproject.Studio": "󰑋",
    "mpv": "󰕼",
    "io.github.elyprismlauncher.ElyPrismLauncher": "󰍳",
    "prismlauncher": "󰍳",
    "minecraft": "󰍳",
}

DEFAULT_ICON = "󰘔"

def get_icon(app_id):
    if not app_id:
        return DEFAULT_ICON
    for key, icon in APP_ICONS.items():
        if key.lower() in app_id.lower():
            return icon
    return DEFAULT_ICON

def update_workspaces():
    try:
        raw_tree = subprocess.check_output(["swaymsg", "-t", "get_tree"], timeout=2)
        raw_ws = subprocess.check_output(["swaymsg", "-t", "get_workspaces"], timeout=2)
        tree = json.loads(raw_tree)
        workspaces = json.loads(raw_ws)
    except Exception:
        return

    ws_apps = {}

    def walk(node, current_ws=None):
        if not isinstance(node, dict):
            return
        if node.get("type") == "workspace":
            current_ws = node.get("num")
            if current_ws is not None and current_ws not in ws_apps:
                ws_apps[current_ws] = []

        app = node.get("app_id") or (node.get("window_properties", {}).get("class"))
        if app and current_ws is not None:
            if "fuzzel" not in app.lower() and "portal" not in app.lower():
                ws_apps[current_ws].append(app)

        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            walk(child, current_ws)

    walk(tree)

    for w in workspaces:
        num = w.get("num")
        old_name = w.get("name")
        if num is None or not old_name:
            continue

        apps = ws_apps.get(num, [])
        icons = []
        seen = set()
        for a in apps:
            ic = get_icon(a)
            if ic not in seen:
                seen.add(ic)
                icons.append(ic)

        if icons:
            new_name = f"{num} {' '.join(icons)}"
        else:
            new_name = f"{num}"

        if old_name != new_name:
            try:
                subprocess.run(["swaymsg", f"rename workspace \"{old_name}\" to \"{new_name}\""], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

def main():
    # Слушаем события swaymsg -t subscribe
    try:
        proc = subprocess.Popen(
            ["swaymsg", "-t", "subscribe", "-m", '["window","workspace"]'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
    except Exception:
        sys.exit(1)

    # Первичное обновление
    update_workspaces()

    for line in proc.stdout:
        update_workspaces()

if __name__ == "__main__":
    main()
