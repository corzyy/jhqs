#!/usr/bin/env python3
"""mango-apply.py — persistent writer for MangoWM look settings.

Usage: mango-apply.py <key=value>...

Writes into ~/.config/mango/configs/looknfeel.conf (sourced by
~/.config/mango/config.conf). All writers are atomic (tmp + replace) and
idempotent. Live preview stays in QML via `mmsg dispatch setoption,k,v`;
this script only persists so values survive `reload_config`/restart.

Keys are bare mango option names (gappih, borderpx, focuscolor, ...).
Values for colors accept #RRGGBB (converted to 0xRRGGBBff) or raw 0x....
A special __layout=<name> key rewrites tagrule layout_name lines in
workspaces.conf instead of looknfeel.conf.
"""
import pathlib
import re
import sys

HOME = pathlib.Path.home()
LOOK = HOME / ".config/mango/configs/looknfeel.conf"
WORKSPACES = HOME / ".config/mango/configs/workspaces.conf"


def atomic_write(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


def normalize(key: str, value: str) -> str:
    v = (value or "").strip()
    if key in ("rootcolor", "bordercolor", "focuscolor", "urgentcolor",
               "shadowscolor", "dropcolor", "splitcolor",
               "maximizescreencolor", "scratchpadcolor", "globalcolor",
               "overlaycolor"):
        m = re.fullmatch(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?", v)
        if m:
            alpha = (m.group(2) or "ff").lower()
            return "0x" + m.group(1).lower() + alpha
        m = re.fullmatch(r"0x[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", v)
        if m:
            return v.lower() + ("" if len(v) == 10 else "ff")
        m = re.fullmatch(r"#([0-9a-fA-F]{3})", v)
        if m:
            h = m.group(1).lower()
            return "0x" + h[0] * 2 + h[1] * 2 + h[2] * 2 + "ff"
    return v


def upsert(path: pathlib.Path, key: str, value: str) -> None:
    t = path.read_text() if path.exists() else ""
    if not t.endswith("\n") and t:
        t += "\n"
    pat = r"^(\s*" + re.escape(key) + r"\s*=\s*).*$"
    repl = r"\g<1>" + value
    t2, n = re.subn(pat, repl, t, flags=re.M)
    if n == 0:
        t2 = t + f"{key}={value}\n"
    if t2 != t:
        atomic_write(path, t2)


def apply_layout(name: str) -> None:
    lay = re.sub(r"[^a-z_]", "", (name or "").lower()) or "scroller"
    if not WORKSPACES.exists():
        return
    t = WORKSPACES.read_text()
    t2 = re.sub(r"(layout_name:)[a-z_]+", r"\g<1>" + lay, t)
    if t2 != t:
        atomic_write(WORKSPACES, t2)


def main(argv: list) -> int:
    for arg in argv:
        if "=" not in arg:
            continue
        k, v = arg.split("=", 1)
        k = re.sub(r"[^a-z_]", "", k.strip().lower())
        if not k:
            continue
        if k == "__layout":
            apply_layout(v)
            continue
        if not re.fullmatch(r"[a-z_]+", k):
            continue
        upsert(LOOK, k, normalize(k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
