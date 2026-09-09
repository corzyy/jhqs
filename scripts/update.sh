#!/bin/bash
set -u

TARGET="all"
UNATTENDED=0

for arg in "$@"; do
    case "$arg" in
        system|aur|flatpak|all) TARGET="$arg" ;;
        -y|--yes|--unattended) UNATTENDED=1 ;;
        -h|--help)
            echo "Usage: update.sh [system|aur|flatpak|all] [-y|--yes|--unattended]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: update.sh [system|aur|flatpak|all] [-y|--yes|--unattended]" >&2
            exit 2
            ;;
    esac
done

KEEPALIVE_PID=""

stop_keepalive() {
    if [[ -n $KEEPALIVE_PID ]]; then
        kill "$KEEPALIVE_PID" 2>/dev/null || true
        KEEPALIVE_PID=""
    fi
}
trap stop_keepalive EXIT INT TERM

ensure_sudo() {
    if ! sudo -v; then
        echo "Elevation cancelled — nothing was changed." >&2
        exit 1
    fi
    while true; do sudo -n true 2>/dev/null || true; sleep 50; done &
    KEEPALIVE_PID=$!
}

update_system() {
    echo "Update system packages"
    echo ""
    sudo pacman -Syu --noconfirm
}

update_aur() {
    local helper=""
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    else
        echo "No AUR helper (yay/paru) installed — skipping AUR updates."
        return 0
    fi
    echo "Update AUR packages ($helper)"
    echo ""
    if [[ $helper == "yay" ]]; then
        yay -Sua --noconfirm --cleanafter --sudoflags "-n"
    else
        paru -Sua --needed --noconfirm --skipreview --cleanafter --sudoflags "-n"
    fi
}

update_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "flatpak not installed — skipping Flatpak updates."
        return 0
    fi
    echo "Update Flatpak apps and runtimes"
    echo ""
    flatpak update -y --noninteractive
}

prune_orphans() {
    local orphans=()
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
    ((${#orphans[@]})) || return 0

    echo "Orphan packages (no longer required by anything):"
    printf '  %s\n' "${orphans[@]}"
    echo ""

    if ((UNATTENDED)) || [[ ! -t 0 || ! -t 1 ]]; then
        echo "${#orphans[@]} orphaned package(s) kept. Re-run without -y in a terminal to review them."
        echo ""
        return 0
    fi

    local answer=""
    read -r -p "Remove ${#orphans[@]} orphaned package(s)? [y/N] " answer || true
    case "$answer" in
        [yY]|[yY][eE][sS])
            echo "Removing orphan packages"
            sudo pacman -Rns "${orphans[@]}"
            echo ""
            ;;
        *)
            echo "Keeping orphaned packages."
            echo ""
            ;;
    esac
}

case "$TARGET" in
    system)
        ensure_sudo
        update_system
        ;;
    aur)
        ensure_sudo
        update_aur
        ;;
    flatpak)
        update_flatpak
        ;;
    all)
        ensure_sudo
        update_system
        echo ""
        update_aur
        echo ""
        update_flatpak
        echo ""
        prune_orphans
        ;;
esac

echo "Done."
