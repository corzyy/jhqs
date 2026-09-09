#!/usr/bin/env bash
set -euo pipefail

echo "=== jhqs Polkit test ==="
echo "Agent status:"
STATUS=$(quickshell ipc -c jhqs call polkit status 2>&1 || echo "  (quickshell not running? start with: qs -c jhqs)")
echo "  $STATUS"
echo ""
if echo "$STATUS" | grep -qi "not registered"; then
    echo "[test] ✗ Kein Agent registriert — Dialog kann nicht erscheinen."
    echo "      1) Shell neu starten (Agent meldet sich beim Start + per Watchdog alle 8s an)."
    echo "      2) Falls dauerhaft (polkitd hält einen toten Eintrag):"
    echo "         sudo systemctl restart polkit   # EINMALIG, dann Shell neu starten"
    exit 3
fi

if command -v pkexec >/dev/null 2>&1; then
    echo "-> Triggering: pkexec --disable-internal-agent bash -c 'echo SUCCESS; id; sleep 1'"
    echo "   -> Dialog should appear centered on DP-1 (Theme.bg, radius 24, Themed)."
    echo "   -> Enter your user password. Cancel with Esc or Abbrechen."
    echo ""
    set +e
    pkexec --disable-internal-agent bash -c 'echo ""; echo "[polkit] ✓ SUCCESS — authenticated"; echo "user=$(whoami) uid=$(id -u)"; id; echo ""; sleep 1'
    rc=$?
    set -e
    echo ""
    if [ $rc -eq 0 ]; then
        echo "[test] ✓ polkit authentication succeeded (rc 0)"
    elif [ $rc -eq 126 ] || [ $rc -eq 127 ]; then
        echo "[test] ✗ cancelled / dismissed (rc $rc) — dialog Cancel/Esc works"
    else
        echo "[test] exit rc=$rc (0=success, 126/127=cancel, other=error)"
        echo "      check: quickshell ipc -c jhqs call polkit status"
        echo "      logs:  journalctl --user -u quickshell  or  qs log  (verbose: qs -c jhqs --verbose)"
    fi
else
    echo "pkexec not found — cannot test"
    exit 1
fi

echo ""
echo "Tip: also try  pkexec --disable-internal-agent env DISPLAY=\$DISPLAY XAUTHORITY=\$XAUTHORITY cat /etc/shadow | head"
echo "     and     pkaction --action-id org.freedesktop.policykit.exec --verbose"
