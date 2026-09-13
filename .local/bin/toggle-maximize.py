#!/usr/bin/env python3
import json
import subprocess
import os

try:
    tree = json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree"]).decode("utf-8"))
except Exception:
    exit(1)

def find_focused(node):
    if node.get("focused"):
        return node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        res = find_focused(child)
        if res:
            return res
    return None

focused = find_focused(tree)
if not focused:
    exit(0)

# If it is currently fullscreen, exit fullscreen
if focused.get("fullscreen_mode") != 0:
    subprocess.run(["swaymsg", "fullscreen", "disable"])
    exit(0)

# If it is a floating window, toggle floating to make it tile to the full workspace under the bar,
# or if it is tiled, toggle floating back to its windowed size.
if focused.get("type") == "floating_con":
    subprocess.run(["swaymsg", "floating", "disable"])
else:
    subprocess.run(["swaymsg", "floating", "enable"])
