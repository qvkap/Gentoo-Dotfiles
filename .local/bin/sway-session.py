#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

SESSION_FILE = os.path.expanduser("~/.config/sway/session.json")

# Сопоставление app_id / class с командами запуска
LAUNCH_COMMANDS = {
    "firefox-bin": "firefox-bin",
    "firefox": "firefox-bin",
    "foot": "foot",
    "com.ayugram.desktop": "AyuGram",
    "vesktop": "/home/rorka/.local/bin/vesktop-launcher.sh",
    "org.vinegarhq.Sober": "gamemoderun flatpak run org.vinegarhq.Sober",
    "Throne": "/opt/Throne/Throne",
    "steam": "gamemoderun steam",
    "com.valvesoftware.Steam": "gamemoderun steam",
    "com.obsproject.Studio": "obs",
    "obs": "obs",
    "mpv": "mpv",
}

def get_tree():
    try:
        out = subprocess.check_output(["swaymsg", "-t", "get_tree"])
        return json.loads(out)
    except Exception:
        return None

def save_session():
    tree = get_tree()
    if not tree:
        return

    windows = []
    def traverse(node, current_ws=None):
        if node.get("type") == "workspace":
            current_ws = node.get("num", node.get("name"))
        app_id = node.get("app_id") or (node.get("window_properties", {}).get("class"))
        if app_id and current_ws is not None:
            # Игнорируем диалоговые окна xdg-desktop-portal
            if "portal" not in app_id.lower() and "fuzzel" not in app_id.lower():
                windows.append({
                    "ws": current_ws,
                    "app": app_id,
                    "floating": (node.get("type") == "floating_con" or node.get("layout") == "floating")
                })
        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            traverse(child, current_ws)

    traverse(tree)
    os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
    with open(SESSION_FILE, "w") as f:
        json.dump(windows, f, indent=2)

def restore_session():
    if not os.path.exists(SESSION_FILE):
        return
    try:
        with open(SESSION_FILE, "r") as f:
            windows = json.load(f)
    except Exception:
        return

    # Запускаем каждое приложение на его рабочем месте
    # Группируем по приложениям, чтобы не спавнить дубликаты одного и того же окна без нужды
    seen_unique = set()
    for win in windows:
        app = win["app"]
        ws = win["ws"]
        cmd = LAUNCH_COMMANDS.get(app, app)
        key = (app, ws)
        if app != "foot" and key in seen_unique:
            continue
        seen_unique.add(key)

        # Выполняем в sway: перейти на workspace X, запустить exec CMD
        sway_cmd = f"[workspace={ws}] workspace {ws}; exec {cmd}"
        try:
            subprocess.run(["swaymsg", f"workspace number {ws}; exec {cmd}"], check=False)
            time.sleep(0.15)
        except Exception:
            pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "restore":
        restore_session()
    else:
        save_session()
