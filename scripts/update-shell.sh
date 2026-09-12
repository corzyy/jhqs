#!/bin/bash
# Update the jhqs quickshell from GitHub:
#   git clone (shallow) -> rsync over the live install, preserving user config.
set -u

REPO="${JHQS_REPO:-https://github.com/corzyy/jhqs}"
DEST="${JHQS_DEST:-$HOME/.config/quickshell/jhqs}"

for arg in "$@"; do
    case "$arg" in
        -y|--yes|--unattended) ;; # no prompts, accepted for consistency with update.sh
        --no-reload) ;; # handled below; skips the automatic shell restart
        -h|--help)
            echo "Usage: update-shell.sh [-y|--yes|--unattended] [--no-reload]"
            echo ""
            echo "Clones $REPO and installs it over $DEST,"
            echo "preserving config/ and themes/snapshots/, then restarts the shell."
            echo "Override with JHQS_REPO / JHQS_DEST env vars."
            echo "Set JHQS_NO_RELOAD=1 or pass --no-reload to skip the restart."
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Usage: update-shell.sh [-y|--yes|--unattended] [--no-reload]" >&2
            exit 2
            ;;
    esac
done

if ! command -v git >/dev/null 2>&1; then
    echo "git is not installed — cannot update the shell." >&2
    exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/jhqs-update.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

echo "Cloning $REPO ..."
if ! git clone --depth 1 "$REPO" "$TMP/repo"; then
    echo "git clone failed." >&2
    exit 1
fi

if [[ ! -f "$TMP/repo/shell.qml" ]]; then
    echo "Clone looks invalid (shell.qml missing) — aborting, nothing was changed." >&2
    exit 1
fi

mkdir -p "$DEST"

if [[ -d "$DEST/.git" ]] && [[ -z "${JHQS_DEST:-}" ]]; then
    if [[ -n "$(git -C "$DEST" status --porcelain 2>/dev/null)" ]]; then
        echo "Note: you have local changes in $DEST — they will be overwritten."
        echo ""
    fi
fi

echo "Installing to $DEST (keeping config/ and themes/snapshots/) ..."
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
        --exclude='.git/' \
        --exclude='.github/' \
        --exclude='config/' \
        --exclude='themes/snapshots/' \
        "$TMP/repo/" "$DEST/"
else
    # Fallback without rsync: copy over (does not prune deleted files).
    echo "(rsync not found — copying without pruning deleted files)"
    (cd "$TMP/repo" && tar cf - --exclude='./.git' --exclude='./.github' --exclude='./config' --exclude='./themes/snapshots' .) \
        | (cd "$DEST" && tar xf -)
fi

# Install any brand-new default configs without overwriting user settings.
if [[ -d "$TMP/repo/config" ]]; then
    mkdir -p "$DEST/config"
    for src in "$TMP/repo/config/"*; do
        base="$(basename "$src")"
        if [[ ! -e "$DEST/config/$base" ]]; then
            echo "New default config: $base"
            cp -a "$src" "$DEST/config/$base"
        fi
    done
fi

chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true

# Restart the shell so the new files take effect immediately.
# Skipped for test installs (JHQS_DEST) unless explicitly allowed.
if [[ -n "${JHQS_NO_RELOAD:-}" ]] || [[ " $* " == *" --no-reload "* ]]; then
    echo ""
    echo "Done. Restart skipped (--no-reload); restart quickshell manually to apply the update."
elif [[ -n "${JHQS_DEST:-}" ]]; then
    echo ""
    echo "Done. (Test install — live shell not restarted.)"
elif command -v quickshell >/dev/null 2>&1; then
    echo ""
    echo "Restarting shell ..."
    if quickshell ipc -c jhqs call jhqs reload >/dev/null 2>&1; then
        echo "Done."
    else
        echo "Update installed, but the automatic restart failed."
        echo "Restart quickshell manually (e.g. qs kill; qs run, or reboot the session)."
    fi
else
    echo ""
    echo "Done. (quickshell binary not found — restart the shell manually to apply the update.)"
fi
