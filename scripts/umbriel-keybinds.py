#!/usr/bin/env python3
"""umbriel-keybinds.py — list all Umbriel keybinds as TSV for the jhqs menu.

Reads ~/.config/umbriel/config.toml plus every [include] / [include.optional]
file and collects each [keybinds] entry. Output rows:

    kind \t combo \t action \t source \t description

kind:        key | mouse | scroll
combo:       display chord (Mod mapped to the configured mod_key, e.g. SUPER)
action:      raw action string ("window-focus-left", "spawn:kitty", ...)
source:      basename of the file the bind came from
description: human text from `umbriel msg --help` (empty for spawn actions)

Later files override earlier ones for the same chord, matching how Umbriel
resolves duplicate binds.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys

try:
    import tomllib
except ImportError:
    sys.exit("python3 tomllib unavailable (need Python 3.11+)")

HOME = os.path.expanduser("~")
UMBRIEL_DIR = os.path.join(HOME, ".config", "umbriel")
CONFIG_TOML = os.path.join(UMBRIEL_DIR, "config.toml")


def load(path):
    try:
        with open(path, "rb") as fh:
            return tomllib.load(fh)
    except Exception:
        return {}


def include_paths(main_cfg):
    inc = main_cfg.get("include", {}) or {}
    names = list(inc.get("files", []) or [])
    names += list((inc.get("optional", {}) or {}).get("files", []) or [])
    out = []
    for name in names:
        if not isinstance(name, str):
            continue
        path = os.path.expanduser(name) if name.startswith("~") else name
        if not os.path.isabs(path):
            path = os.path.join(UMBRIEL_DIR, path)
        out.append(path)
    return out


def action_descriptions():
    """action token -> help text, parsed from `umbriel msg --help`."""
    try:
        out = subprocess.run(["umbriel", "msg", "--help"], capture_output=True,
                             text=True, timeout=5).stdout
    except Exception:
        return {}
    desc = {}
    for line in out.splitlines():
        m = re.match(r"^  (\S+)\s{2,}(.+)$", line)
        if not m:
            continue
        token, text = m.group(1), m.group(2).strip()
        desc.setdefault(token.split(":", 1)[0], text)
    return desc


def display_combo(chord, mod_key):
    parts = [p.strip() for p in chord.split("+") if p.strip()]
    out = []
    for part in parts:
        if part == "Mod":
            out.append(mod_key.upper())
        elif part.startswith("Wheel"):
            out.append("Scroll " + part[5:])
        elif part.startswith("Mouse"):
            out.append("Mouse " + part[5:])
        else:
            out.append(part)
    return " + ".join(out)


def kind_for(chord):
    if "Wheel" in chord:
        return "scroll"
    if "Mouse" in chord:
        return "mouse"
    return "key"


def main():
    main_cfg = load(CONFIG_TOML)
    mod_key = str((main_cfg.get("general", {}) or {}).get("mod_key", "Super"))
    desc = action_descriptions()

    binds = {}
    order = []
    files = include_paths(main_cfg)
    files.append(CONFIG_TOML)
    for path in files:
        table = load(path).get("keybinds", {}) or {}
        if not isinstance(table, dict):
            continue
        src = os.path.basename(path)
        for chord, value in table.items():
            if isinstance(value, dict):
                action = value.get("action", "")
            else:
                action = value
            action = str(action or "").strip()
            if not action:
                continue
            if chord not in binds:
                order.append(chord)
            binds[chord] = (action, src)

    for chord in order:
        action, src = binds[chord]
        base = action.split(":", 1)[0]
        text = "" if base == "spawn" else desc.get(base, "")
        print("\t".join([kind_for(chord), display_combo(chord, mod_key),
                         action, src, text]))


if __name__ == "__main__":
    main()
