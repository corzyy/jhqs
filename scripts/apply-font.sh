#!/usr/bin/env bash
set -u
FAM="${1:-}"
SIZE="${2:-11}"
FAM="$(printf '%s' "$FAM" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$FAM" ]; then echo "apply-font.sh: empty family" >&2; exit 1; fi
case "$FAM" in
  *$'\n'*|*$'\r'*|*$'\t'*) echo "apply-font.sh: invalid family" >&2; exit 1 ;;
esac
case "$SIZE" in
  ''|*[!0-9]*) SIZE=11 ;;
esac
[ "$SIZE" -lt 8 ] && SIZE=8
[ "$SIZE" -gt 16 ] && SIZE=16
IFACE="${FAM} ${SIZE}"
DOC="${FAM} $((SIZE + 1))"
TITLE="${FAM} Bold ${SIZE}"

gsettings set org.gnome.desktop.interface font-name "$IFACE" 2>/dev/null || true
gsettings set org.gnome.desktop.interface document-font-name "$DOC" 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences titlebar-font "$TITLE" 2>/dev/null || true

for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  [ -e "$f" ] || continue
  if grep -q '^gtk-font-name=' "$f" 2>/dev/null; then
    IFACE="$IFACE" FILE="$f" python3 - "$f" <<'EOF' 2>/dev/null || true
import os, sys
p = sys.argv[1]
v = os.environ.get("IFACE", "")
try:
    with open(p) as fh: lines = fh.read().splitlines()
except OSError:
    sys.exit(1)
out = [("gtk-font-name=" + v) if l.startswith("gtk-font-name=") else l for l in lines]
with open(p, "w") as fh: fh.write("\n".join(out) + "\n")
EOF
  else
    grep -q '^\[Settings\]' "$f" 2>/dev/null || printf '[Settings]\n' >> "$f"
    printf 'gtk-font-name=%s\n' "$IFACE" >> "$f"
  fi
done

for f in "$HOME/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"; do
  [ -f "$f" ] || continue
  FAM_QT="$FAM" FILE_QT="$f" python3 - "$f" <<'EOF' 2>/dev/null || true
import os, re, sys
p = sys.argv[1]
fam = os.environ.get("FAM_QT", "")
try:
    with open(p) as fh: txt = fh.read()
except OSError:
    sys.exit(1)
txt2 = re.sub(r'^general="[^,"]*', 'general="' + fam.replace('\\', '\\\\').replace('"', ''), txt, count=1, flags=re.M)
if txt2 != txt:
    with open(p, "w") as fh: fh.write(txt2)
EOF
done

mkdir -p "$HOME/.config/fontconfig" 2>/dev/null || true
FAM="$FAM" python3 <<'EOF' 2>/dev/null || true
import os
from xml.sax.saxutils import escape
fam = escape(os.environ.get("FAM", ""))
xml = """<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <!-- jhqs system font (managed by Style → Font, do not hand-edit) -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>{F}</family>
    </prefer>
  </alias>
  <alias>
    <family>sans</family>
    <prefer>
      <family>{F}</family>
    </prefer>
  </alias>
</fontconfig>
""".format(F=fam)
with open(os.path.expanduser("~/.config/fontconfig/fonts.conf"), "w") as fh:
    fh.write(xml)
EOF
fc-cache -f "$HOME/.local/share/fonts" "$HOME/.fonts" 2>/dev/null || fc-cache 2>/dev/null || true

XSET="$HOME/.config/xsettingsd/xsettingsd.conf"
if [ -f "$XSET" ]; then
  grep -v '^Gtk/FontName' "$XSET" > /tmp/jhqs-xsettingsd.conf 2>/dev/null && mv /tmp/jhqs-xsettingsd.conf "$XSET"
  printf 'Gtk/FontName "%s"\n' "$IFACE" >> "$XSET"
  pkill -HUP -x xsettingsd 2>/dev/null || true
fi
KITTY_CONF="$HOME/.config/kitty/kitty.conf"
if [ -f "$KITTY_CONF" ]; then
  FAM_KITTY="$FAM" FILE_KITTY="$KITTY_CONF" python3 - "$KITTY_CONF" <<'EOF' 2>/dev/null || true
import os, re, sys
p = sys.argv[1]
fam = os.environ.get("FAM_KITTY", "").strip()
if not fam:
    sys.exit(1)
fam = re.sub(r'[\r\n\t]', '', fam)
try:
    with open(p) as fh: txt = fh.read()
except OSError:
    sys.exit(1)
pat = r'^(?P<indent>\s*font_family\s+).*$'
txt2, n = re.subn(pat, r'\g<indent>' + fam, txt, flags=re.M)
if n == 0:
    txt2 = txt.rstrip() + "\nfont_family " + fam + "\n"
if txt2 != txt:
    with open(p, "w") as fh: fh.write(txt2)
EOF
  pkill -USR1 kitty 2>/dev/null || true
fi
echo "font applied: $FAM"
