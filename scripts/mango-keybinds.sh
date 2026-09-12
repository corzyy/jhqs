#!/usr/bin/env bash
# mango-keybinds.sh — list ALL MangoWM binds (bind/bindl/mousebind/axisbind)
# from the active user config (~/.config/mango/config.conf + all `source=`
# includes, 2 levels deep, plus every configs/*.conf as a safety net).
# Output: TSV lines  kind \t combo \t action \t source \t directive
#   kind: key | mouse | scroll
set -u

MANGODIR="${HOME}/.config/mango"
MAIN="${MANGODIR}/config.conf"

files=""
addfile() {
    [ -n "${1:-}" ] && [ -f "$1" ] || return 0
    case " $files " in *" $1 "*) ;; *) files="$files $1";; esac
}

expandpath() {
    local s="$1"
    s="$(printf '%s' "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    case "$s" in "~"*) s="${HOME}${s#\~}";; esac
    case "$s" in "/"*) ;; *) s="${MANGODIR}/$s";; esac
    printf '%s' "$s"
}

collect_sources() {
    grep -E '^[[:space:]]*source[[:space:]]*=' "$1" 2>/dev/null \
        | sed 's/^[^=]*=//' \
        | while IFS= read -r s; do expandpath "$s"; echo; done
}

addfile "$MAIN"
lvl1="$(collect_sources "$MAIN")"
for f in $lvl1; do addfile "$f"; done
for f in $lvl1; do
    # shellcheck disable=SC2046
    for g in $(collect_sources "$f"); do addfile "$g"; done
done
for f in "${MANGODIR}"/configs/*.conf; do addfile "$f"; done

for f in $files; do
    src="$(basename "$f")"
    grep -n -E '^[[:space:]]*(bindl?|mousebind|axisbind)[[:space:]]*=' "$f" 2>/dev/null \
    | while IFS= read -r mline; do
        rest="${mline#*:}"
        directive="$(printf '%s' "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*=.*//')"
        body="$(printf '%s' "$rest" | sed 's/^[^=]*=//')"
        mods="$(printf '%s' "$body" | cut -d, -f1 | tr -d ' \t')"
        key="$(printf '%s' "$body" | cut -d, -f2 | tr -d ' \t')"
        action="$(printf '%s' "$body" | cut -d, -f3- | tr '\t' ' ' | sed 's/,/ /g;s/  */ /g;s/^ //;s/ $//')"
        [ -z "$key" ] && continue
        [ -z "$action" ] && action="$key"
        umods="$(printf '%s' "$mods" | tr 'a-z' 'A-Z')"
        if [ "$umods" = "NONE" ] || [ -z "$umods" ]; then
            mcombo=""
        else
            mcombo="$(printf '%s' "$umods" | sed 's/+/\ +\ /g')"
        fi
        case "$directive" in
            mousebind)
                kind="mouse"
                if [ -n "$mcombo" ]; then combo="$mcombo + $key"; else combo="$key"; fi
                ;;
            axisbind)
                kind="scroll"
                if [ -n "$mcombo" ]; then combo="$mcombo + Scroll $key"; else combo="Scroll $key"; fi
                ;;
            *)
                kind="key"
                if [ -n "$mcombo" ]; then combo="$mcombo + $key"; else combo="$key"; fi
                ;;
        esac
        printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$combo" "$action" "$src" "$directive"
    done
done
