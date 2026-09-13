#!/bin/bash
set -u

TARGET="all"
UNATTENDED=0

for arg in "$@"; do
    case "$arg" in
        system|flatpak|all) TARGET="$arg" ;;
        -y|--yes|--unattended) UNATTENDED=1 ;;
        -h|--help)
            echo "Usage: update.sh [system|flatpak|all] [-y|--yes|--unattended]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: update.sh [system|flatpak|all] [-y|--yes|--unattended]" >&2
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
    echo "Update system packages (DNF)"
    echo ""
    sudo dnf upgrade -y
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
    echo "Autoremove unneeded packages (DNF)"
    echo ""

    if ((UNATTENDED)) || [[ ! -t 0 || ! -t 1 ]]; then
        echo "Re-run without -y in a terminal to review them, or run: sudo dnf autoremove"
        echo ""
        return 0
    fi

    local answer=""
    read -r -p "Run 'sudo dnf autoremove'? [y/N] " answer || true
    case "$answer" in
        [yY]|[yY][eE][sS])
            sudo dnf autoremove
            echo ""
            ;;
        *)
            echo "Keeping unneeded packages."
            echo ""
            ;;
    esac
}

case "$TARGET" in
    system)
        ensure_sudo
        update_system
        ;;
    flatpak)
        update_flatpak
        ;;
    all)
        ensure_sudo
        update_system
        echo ""
        update_flatpak
        echo ""
        prune_orphans
        ;;
esac

echo "Done."
