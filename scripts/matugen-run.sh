#!/usr/bin/env bash
# matugen-run.sh — matugen wrapper that respects jhqs Application Theming toggles.
# Ported from DMS `dms matugen queue` template-skip logic (runUserTemplates /
# runDmsTemplates + per-template bools), adapted to plain matugen:
#   1. builds a filtered copy of ~/.config/matugen/config.toml in /tmp
#      (drops disabled template blocks; drops unknown user blocks when
#      runUserTemplates=false; never drops quickshell/hyprland core blocks)
#   2. runs `matugen "$@" -c <filtered>`
#   3. if terminalsAlwaysDark is on and mode is light, re-renders terminal
#      outputs (kitty) with the dark variant — mirrors DMS substituting
#      .default with .dark for terminal configs.
set -u

SRC_CFG="$HOME/.config/matugen/config.toml"
THEMING_JSON="$HOME/.config/quickshell/jhqs/config/theming_settings.json"
TMP_CFG="/tmp/jhqs-matugen-filtered.toml"
TMP_TERM="/tmp/jhqs-matugen-terminals.toml"

FILTERED="$(python3 - "$SRC_CFG" "$THEMING_JSON" "$TMP_CFG" <<'EOF'
import json, re, sys
src, theming_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cfg = open(src).read()
except OSError:
    sys.exit(2)
try:
    t = json.loads(open(theming_path).read())
except Exception:
    t = {}

def off(key):
    return t.get(key) is False

drop = set()
if off("templateGtk3"): drop.add("gtk3")
if off("templateGtk4"): drop.add("gtk4")
if off("templateQt5ct"): drop.add("qt5ct")
if off("templateQt6ct"): drop.add("qt6ct")
if off("templateQtColorscheme"): drop.add("qt-colorscheme")
if off("templateKitty"): drop.add("kitty")
if off("templateGhostty"): drop.add("ghostty")
if off("templateFcitx5"): drop.add("fcitx5")
if off("templateFirefox"): drop.add("firefox")
if off("templateVscode"): drop.update(["vscode-raw", "vscode-json"])
if off("templateNeovim"): drop.add("neovim")
if off("templateBtop"): drop.add("btop")
if off("templateVesktop"): drop.update(["vesktop-midnight", "vesktop-system24"])
if off("templateObs"): drop.update(["obs", "obs-native"])
if off("templateOpencode"): drop.add("opencode")
if off("templatePapirus"): drop.add("papirus")
if off("templatePrismlauncher"): drop.add("prismlauncher")

known = {"quickshell", "hyprland", "gtk3", "gtk4", "qt5ct", "qt6ct",
         "qt-colorscheme", "kitty", "ghostty", "fcitx5", "firefox",
         "vscode-raw", "vscode-json", "neovim", "btop", "vesktop-midnight",
         "vesktop-system24", "obs", "obs-native", "opencode", "papirus",
         "prismlauncher"}
run_user = t.get("runUserTemplates", True) is not False

out_lines, cur_id, cur = [], None, []
def flush():
    if cur and cur_id is not None:
        if cur_id in drop:
            return
        if cur_id not in known and not run_user:
            return
        out_lines.append("".join(cur))

for line in cfg.splitlines(keepends=True):
    m = re.match(r"\[templates\.([^\]]+)\]", line.strip())
    if m:
        flush()
        cur_id, cur = m.group(1), [line]
    elif cur_id is not None:
        if line.startswith("[") and not line.startswith("[templates."):
            flush()
            cur_id, cur = None, []
            out_lines.append(line)
        else:
            cur.append(line)
    else:
        out_lines.append(line)
flush()
open(out, "w").write("".join(out_lines))
print("drop=" + ",".join(sorted(drop)) if drop else "drop=")
EOF
)"
echo "[matugen-run] $FILTERED (filtered: $TMP_CFG)" | logger -t matugen-run 2>/dev/null || true

MATUGEN_BIN="matugen"
[ -x "$HOME/.cargo/bin/matugen" ] && MATUGEN_BIN="$HOME/.cargo/bin/matugen"

"$MATUGEN_BIN" "$@" -c "$TMP_CFG"
CODE=$?

# Terminals-always-dark second pass (DMS parity): light shell, dark terminals.
MODE_IS_LIGHT=false
WANT_DARK=false
for a in "$@"; do
  [ "$a" = "light" ] && MODE_IS_LIGHT=true
done
if python3 -c "import json; exit(0 if json.load(open('$THEMING_JSON')).get('terminalsAlwaysDark') else 1)" 2>/dev/null; then
  WANT_DARK=true
fi
if $MODE_IS_LIGHT && $WANT_DARK && python3 -c "import json; exit(0 if json.load(open('$THEMING_JSON')).get('templateKitty', True) is not False else 1)" 2>/dev/null; then
  python3 - "$TMP_CFG" "$TMP_TERM" <<'EOF'
import re, sys
src, out = sys.argv[1], sys.argv[2]
cfg = open(src).read()
blocks, cur_id, cur = [], None, []
def flush():
    if cur_id == "kitty" and cur:
        blocks.append("".join(cur))
for line in cfg.splitlines(keepends=True):
    m = re.match(r"\[templates\.([^\]]+)\]", line.strip())
    if m:
        flush()
        cur_id, cur = m.group(1), [line]
    elif cur_id is not None:
        if line.startswith("[") and not line.startswith("[templates."):
            flush()
            cur_id, cur = None, []
        else:
            cur.append(line)
flush()
head = cfg.split("[templates.")[0]
open(out, "w").write(head + "".join(blocks))
EOF
  if grep -q '\[templates\.kitty\]' "$TMP_TERM" 2>/dev/null; then
    DARK_ARGS=()
    SKIP_NEXT=false
    for a in "$@"; do
      if $SKIP_NEXT; then SKIP_NEXT=false; continue; fi
      case "$a" in
        -m|--mode) DARK_ARGS+=("$a" "dark"); SKIP_NEXT=false;;
        light|dark|smart) DARK_ARGS+=("dark");;
        -c|--config) SKIP_NEXT=true;;
        *) DARK_ARGS+=("$a");;
      esac
    done
    "$MATUGEN_BIN" "${DARK_ARGS[@]}" -c "$TMP_TERM" 2>&1 | logger -t matugen-terminals 2>/dev/null || true
  fi
fi

exit $CODE
