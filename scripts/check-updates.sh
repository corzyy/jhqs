#!/bin/bash
set -u

emit() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

if command -v checkupdates >/dev/null 2>&1; then
    while IFS=' ' read -r package old_version arrow new_version; do
        [[ -n ${package:-} ]] && emit system "$package" "${old_version:-?} -> ${new_version:-?}"
    done < <(timeout 120 checkupdates --nocolor 2>/dev/null || true)
fi

if command -v yay >/dev/null 2>&1; then
    while IFS=' ' read -r package old_version arrow new_version; do
        [[ -n ${package:-} ]] && emit aur "$package" "${old_version:-?} -> ${new_version:-?}"
    done < <(timeout 60 yay -Qua 2>/dev/null || true)
elif command -v paru >/dev/null 2>&1; then
    while IFS=' ' read -r package old_version arrow new_version; do
        [[ -n ${package:-} ]] && emit aur "$package" "${old_version:-?} -> ${new_version:-?}"
    done < <(timeout 180 paru -Qua 2>/dev/null || true)
fi

if command -v flatpak >/dev/null 2>&1; then
    while IFS=$'\t' read -r app version size; do
        [[ -n ${app:-} ]] && emit flatpak "$app" "${version:-Update available}${size:+ · $size}"
    done < <(flatpak remote-ls --updates --columns=application,version,download-size 2>/dev/null || true)
fi
