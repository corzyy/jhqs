#!/usr/bin/env python3
"""settings-apply.py — persistent writers for the jhqs Settings panel.

Usage: settings-apply.py <domain> <key=value>...
Domains: kitty | fish | hypridle | brightness | anim-speed | preset

All writers are atomic (tmp + replace) and idempotent. Called from QML
Process so the UI never blocks; live Hyprland keywords stay in QML.
"""
import json
import pathlib
import re
import subprocess
import sys

HOME = pathlib.Path.home()
HYPR = HOME / ".config/hypr/configs"
JHQS_CFG = HOME / ".config/quickshell/jhqs/config"
KITTY = HOME / ".config/kitty/kitty.conf"
FISH_PROMPT = HOME / ".config/fish/functions/fish_prompt.fish"
HYPRIDLE = HOME / ".config/hypr/hypridle.conf"
SETTINGS_JSON = JHQS_CFG / "settings.json"

def atomic_write(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)

def sed_int_key(path: pathlib.Path, key: str, value: int) -> None:
    t = path.read_text() if path.exists() else ""
    pat = r"^(\s*" + re.escape(key) + r"\s+).*$"
    t2, n = re.subn(pat, r"\g<1>" + str(value), t, flags=re.M)
    if n == 0:
        t2 = t.rstrip() + "\n" + key + " " + str(value) + "\n"
    atomic_write(path, t2)

def fmt_num(value: float) -> str:
    s = "%g" % float(value)
    return s

def sed_float_key(path: pathlib.Path, key: str, value: float) -> None:
    t = path.read_text() if path.exists() else ""
    pat = r"^(\s*" + re.escape(key) + r"\s+).*$"
    t2, n = re.subn(pat, r"\g<1>" + fmt_num(value), t, flags=re.M)
    if n == 0:
        t2 = t.rstrip() + "\n" + key + " " + fmt_num(value) + "\n"
    atomic_write(path, t2)

def kitty(pairs: dict) -> None:
    for k, v in pairs.items():
        if k == "padding":
            sed_int_key(KITTY, "window_padding_width", max(0, min(40, int(float(v)))))
        elif k == "font_size":
            sed_float_key(KITTY, "font_size", max(6.0, min(32.0, float(v))))
        elif k == "opacity":
            sed_float_key(KITTY, "background_opacity", max(0.3, min(1.0, float(v))))
        elif k in ("family", "font_family"):
            fam = re.sub(r"[\r\n\t]", "", (v + "").strip())
            if not fam:
                continue
            t = KITTY.read_text() if KITTY.exists() else ""
            t2, n = re.subn(r"^(\s*font_family\s+).*$", r"\g<1>" + fam, t, flags=re.M)
            if n == 0:
                t2 = t.rstrip() + "\nfont_family " + fam + "\n"
            atomic_write(KITTY, t2)
    subprocess.run(["bash", "-c", "pkill -USR1 kitty 2>/dev/null || true"], check=False)

def fish(pairs: dict) -> None:
    style = re.sub(r"[^a-z0-9_-]", "", pairs.get("prompt", "minimal").lower()) or "minimal"
    src = HOME / f".config/fish/prompts/{style}.fish"
    if src.exists():
        FISH_PROMPT.parent.mkdir(parents=True, exist_ok=True)
        if FISH_PROMPT.is_symlink() or FISH_PROMPT.exists():
            FISH_PROMPT.unlink()
        FISH_PROMPT.symlink_to(src)
    else:
        subprocess.run(
            ["bash", "-c", f"fish -c 'set -U jhqs_prompt {style}' 2>/dev/null || true"],
            check=False,
        )

def hypridle(pairs: dict) -> None:
    if not HYPRIDLE.exists():
        return
    t = HYPRIDLE.read_text()
    timeouts = list(re.finditer(r"(timeout\s*=\s*)(\d+)", t))
    if "lock" in pairs and len(timeouts) >= 1:
        v = max(30, min(3600, int(float(pairs["lock"]))))
        m = timeouts[0]
        t = t[: m.start(2)] + str(v) + t[m.end(2):]
        timeouts = list(re.finditer(r"(timeout\s*=\s*)(\d+)", t))
    if "suspend" in pairs and len(timeouts) >= 2:
        v = max(60, min(7200, int(float(pairs["suspend"]))))
        m = timeouts[1]
        t = t[: m.start(2)] + str(v) + t[m.end(2):]
    atomic_write(HYPRIDLE, t)

def brightness(pairs: dict) -> None:
    v = max(5, min(100, int(float(pairs.get("level", 100)))))
    subprocess.run(
        ["bash", "-c", f"brightnessctl set {v}% >/dev/null 2>&1 || brightnessctl -q set {v}% >/dev/null 2>&1 || true"],
        check=False,
    )

def fmt_blur_val(v: str) -> str:
    s = (v + "").strip().lower()
    if s in ("true", "false"):
        return s
    try:
        return "%g" % float(s)
    except ValueError:
        return "0"

def hypr_blur(pairs: dict) -> None:
    """Upsert keys inside the `blur = {...}` block of looknfeel.lua."""
    path = HYPR / "looknfeel.lua"
    if not path.exists():
        return
    t = path.read_text()
    m = re.search(r"(blur\s*=\s*\{)(.*?)(\n[ \t]*\},)", t, re.S)
    if not m:
        return
    body = m.group(2)
    for k, v in pairs.items():
        if not re.fullmatch(r"[a-z_]+", k or ""):
            continue
        fv = fmt_blur_val(v)
        nb, n = re.subn(
            r"^([ \t]*" + re.escape(k) + r"\s*=\s*)([^\n,]+)(,?)",
            r"\g<1>" + fv + r"\g<3>",
            body,
            flags=re.M,
        )
        if n == 0:
            nb = body.rstrip() + "\n      " + k + " = " + fv + ",\n    "
        body = nb
    atomic_write(path, t[: m.start(2)] + body + t[m.end(2):])

BASE_SPEEDS = {"windows": 3.0, "border": 10.0, "fade": 2.5, "workspaces": 3.5, "specialWorkspace": 3.0}

def anim_speed(pairs: dict) -> None:
    scale = max(0.2, min(3.0, float(pairs.get("scale", 1.0))))
    path = HYPR / "animations.lua"
    if not path.exists():
        return
    t = path.read_text()

    def repl(m: re.Match) -> str:
        leaf = m.group(1)
        base = BASE_SPEEDS.get(leaf, 3.0)
        return f"{{ leaf = \"{leaf}\", enabled = true, speed = {round(base * scale, 2)}"

    t = re.sub(r"\{\s*leaf\s*=\s*\"([^\"]+)\"\s*,\s*enabled\s*=\s*\w+\s*,\s*speed\s*=\s*[\d.]+", repl, t)
    atomic_write(path, t)

def _hypr(cmd: str) -> None:
    subprocess.run(["bash", "-c", cmd + " >/dev/null 2>&1 || true"], check=False)

def _cfg(tables: str) -> str:
    return "hyprctl eval 'hl.config({" + tables + "})'"

def _sed_lua(path: pathlib.Path, expr: str) -> None:
    _hypr(f"sed -i -E '{expr}' {path} 2>/dev/null")

def _json_patch(patch: dict) -> None:
    try:
        data = json.loads(SETTINGS_JSON.read_text()) if SETTINGS_JSON.exists() else {}
    except Exception:
        data = {}
    data.update(patch)
    atomic_write(SETTINGS_JSON, json.dumps(data, indent=4, sort_keys=True) + "\n")

PRESETS = {
    "coding": {"gapsIn": 4, "gapsOut": 8, "border": 2, "rounding": 8, "layout": "dwindle",
               "shadow": True, "blur": True, "animEnabled": True},
    "gaming": {"gapsIn": 0, "gapsOut": 0, "border": 1, "rounding": 0, "layout": "dwindle",
               "shadow": False, "blur": False, "animEnabled": False, "tearing": True},
    "present": {"gapsIn": 8, "gapsOut": 16, "border": 2, "rounding": 10, "layout": "dwindle",
                "shadow": True, "blur": False, "animEnabled": True},
    "chill": {"gapsIn": 12, "gapsOut": 24, "border": 3, "rounding": 16, "layout": "scrolling",
              "shadow": True, "blur": True, "animEnabled": True},
}

def preset(pairs: dict) -> None:
    name = re.sub(r"[^a-z]", "", pairs.get("name", "").lower())
    if name not in PRESETS:
        return
    p = PRESETS[name]
    look = HYPR / "looknfeel.lua"
    _hypr(_cfg(f"general={{gaps_in={p['gapsIn']}}}"))
    _hypr(_cfg(f"general={{gaps_out={p['gapsOut']}}}"))
    _hypr(_cfg(f"general={{border_size={p['border']}}}"))
    _hypr(_cfg(f"decoration={{rounding={p['rounding']}}}"))
    _hypr(_cfg(f"general={{layout=\"{p['layout']}\"}}"))
    _hypr(_cfg(f"decoration={{shadow={{enabled={'true' if p['shadow'] else 'false'}}}}}"))
    _hypr(_cfg(f"decoration={{blur={{enabled={'true' if p['blur'] else 'false'}}}}}"))
    _hypr(_cfg(f"animations={{enabled={'true' if p['animEnabled'] else 'false'}}}"))
    _sed_lua(look, f"s/(gaps_in\\s*=\\s*)[0-9]+/\\1{p['gapsIn']}/")
    _sed_lua(look, f"s/(gaps_out\\s*=\\s*)[0-9]+/\\1{p['gapsOut']}/")
    _sed_lua(look, f"s/(border_size\\s*=\\s*)[0-9]+/\\1{p['border']}/")
    _sed_lua(look, f"s/(rounding\\s*=\\s*)[0-9]+/\\1{p['rounding']}/")
    _sed_lua(look, f"s/(layout\\s*=\\s*\")[^\"]+\"/\\1{p['layout']}\"/")
    if p.get("tearing") is not None:
        _hypr(_cfg(f"general={{allow_tearing={'true' if p['tearing'] else 'false'}}}"))
    _json_patch({
        "gapsIn": p["gapsIn"], "gapsOut": p["gapsOut"], "border": p["border"],
        "rounding": p["rounding"], "layout": p["layout"], "shadow": p["shadow"],
        "blur": p["blur"], "animEnabled": p["animEnabled"],
        **({"tearing": p["tearing"]} if p.get("tearing") is not None else {}),
    })
    _hypr("notify-send -u low 'Settings' 'Preset " + name + " applied' 2>/dev/null")

DOMAINS = {"kitty": kitty, "fish": fish, "hypridle": hypridle,
           "brightness": brightness, "anim-speed": anim_speed, "preset": preset,
           "hypr-blur": hypr_blur}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in DOMAINS:
        print(f"usage: {sys.argv[0]} {{{'|'.join(DOMAINS)}}} key=value...", file=sys.stderr)
        sys.exit(1)
    domain = sys.argv[1]
    pairs = dict(a.split("=", 1) for a in sys.argv[2:] if "=" in a)
    DOMAINS[domain](pairs)
