#!/usr/bin/env bash
set -u

MODE="${1:-}"
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then
  MODE="$(jq -r '.mode // "dark"' "$HOME/.config/quickshell/jhqs/themes/matugen_settings.json" 2>/dev/null || echo dark)"
fi
if [ "$MODE" != "dark" ] && [ "$MODE" != "light" ]; then MODE="dark"; fi

if [ "$MODE" = "dark" ]; then
  GTK_THEME="adw-gtk3-dark"
  PREF_DARK="1"
  COLOR_SCHEME="prefer-dark"
else
  GTK_THEME="adw-gtk3"
  PREF_DARK="0"
  COLOR_SCHEME="prefer-light"
fi

GTK3_DIR="$HOME/.config/gtk-3.0"
GTK4_DIR="$HOME/.config/gtk-4.0"
mkdir -p "$GTK3_DIR" "$GTK4_DIR" 2>/dev/null || true

GTK3_CSS="$GTK3_DIR/gtk.css"
if [ -L "$GTK3_CSS" ]; then rm -f "$GTK3_CSS"; fi
if [ -f "$GTK3_CSS" ]; then
  if ! grep -q "colors.css" "$GTK3_CSS" 2>/dev/null; then
    { printf '@import url("colors.css");\n'; cat "$GTK3_CSS"; } > /tmp/jhqs-gtk3.css 2>/dev/null && mv /tmp/jhqs-gtk3.css "$GTK3_CSS"
  fi
else
  printf '/* jhqs matugen GTK3 (managed by Style, do not hand-edit) */\n@import url("colors.css");\n' > "$GTK3_CSS"
fi

GTK4_BODY='/* jhqs matugen GTK4/libadwaita (managed by Style, do not hand-edit) */\n@import url("colors.css");\n'
for f in "$GTK4_DIR/gtk.css" "$GTK4_DIR/gtk-dark.css"; do
  if [ -L "$f" ]; then rm -f "$f"; fi
  if [ -f "$f" ]; then
    if ! grep -q "colors.css" "$f" 2>/dev/null; then
      { printf '%b' "$GTK4_BODY"; cat "$f"; } > /tmp/jhqs-gtk4.css 2>/dev/null && mv /tmp/jhqs-gtk4.css "$f"
    fi
  else
    printf '%b' "$GTK4_BODY" > "$f"
  fi
done

for f in "$GTK3_DIR/settings.ini" "$GTK4_DIR/settings.ini"; do
  [ -e "$f" ] || continue
  GTK_THEME="$GTK_THEME" PREF_DARK="$PREF_DARK" FILE="$f" python3 - "$f" <<'EOF' 2>/dev/null || true
import os, sys
p = sys.argv[1]
theme = os.environ.get("GTK_THEME", "adw-gtk3-dark")
pref = os.environ.get("PREF_DARK", "1")
try:
    with open(p) as fh: lines = fh.read().splitlines()
except OSError:
    sys.exit(1)
out, seen_theme, seen_pref = [], False, False
for l in lines:
    if l.startswith("gtk-theme-name="):
        out.append("gtk-theme-name=" + theme); seen_theme = True
    elif l.startswith("gtk-application-prefer-dark-theme="):
        out.append("gtk-application-prefer-dark-theme=" + pref); seen_pref = True
    else:
        out.append(l)
if "[Settings]" not in out and not any(l.strip() == "[Settings]" for l in out):
    out.insert(0, "[Settings]")
if not seen_theme:
    out.append("gtk-theme-name=" + theme)
if not seen_pref:
    out.append("gtk-application-prefer-dark-theme=" + pref)
with open(p, "w") as fh: fh.write("\n".join(out) + "\n")
EOF
done

gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
HOOK="$HOME/.config/matugen/post-hook-scripts/gtk-themes-reload.sh"
if [ -x "$HOOK" ]; then
  bash "$HOOK" 2>/dev/null || true
else
  cur="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")"
  if [ "$cur" = "'prefer-dark'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
  else
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
  fi
  gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null || true
fi

echo "gtk applied: $MODE ($GTK_THEME)"
