#!/usr/bin/env bash
# Disable sleep/suspend on geekom (geekom-linux) — this runs as an always-on
# SSH dev machine (and later, a web server), reachable via Tailscale from
# anywhere. It must never suspend on idle. See ../geekom/always_on_setup.md
# for full rationale (including the LUKS-on-reboot caveat, which this
# script does NOT address).
#
# Layers, from most to least authoritative:
#   1. Mask the systemd sleep targets — blocks suspend/hibernate no matter
#      what triggers it (GNOME, logind, ACPI, a stray `systemctl suspend`).
#   2. Explicit logind.conf override (IdleAction=ignore) — belt and
#      suspenders; this was already the systemd default, but stated
#      explicitly rather than left implicit.
#   3. GNOME dconf override (sleep-inactive-ac/battery-type=nothing) — so
#      the Settings UI reflects reality and doesn't fight the above.
#
# Idempotent: safe to re-run.
# Usage: sudo ./disable_sleep.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root: sudo $0" >&2
  exit 1
fi

echo "== 1) Masking systemd sleep targets =="
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
systemctl status sleep.target suspend.target hibernate.target hybrid-sleep.target --no-pager 2>&1 | grep -E "●|Loaded" || true

echo
echo "== 2) logind.conf: explicit IdleAction=ignore =="
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/00-no-idle-suspend.conf <<'EOF'
# Managed by geekom/disable_sleep.sh — do not hand-edit.
[Login]
IdleAction=ignore
EOF
systemctl restart systemd-logind
echo "   Wrote /etc/systemd/logind.conf.d/00-no-idle-suspend.conf, restarted systemd-logind"

echo
echo "== 3) GNOME dconf: sleep-inactive-*-type=nothing, system-wide =="
mkdir -p /etc/dconf/db/local.d /etc/dconf/db/local.d/locks
cat > /etc/dconf/db/local.d/00-no-sleep <<'EOF'
# Managed by geekom/disable_sleep.sh — do not hand-edit.
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
EOF
cat > /etc/dconf/db/local.d/locks/00-no-sleep <<'EOF'
/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type
/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type
EOF
dconf update
echo "   Wrote dconf override + lock, ran dconf update"

echo
echo "== Confirming =="
FAIL=0
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  state="$(systemctl is-enabled "$t" 2>&1 || true)"
  echo "$t: $state"
  [[ "$state" == "masked" ]] || FAIL=1
done
grep -q "IdleAction=ignore" /etc/systemd/logind.conf.d/00-no-idle-suspend.conf && echo "logind IdleAction=ignore: OK" || FAIL=1

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "CONFIRMED: sleep targets masked, logind override in place, dconf lock applied."
else
  echo "WARNING: one or more checks failed — review above." >&2
  exit 1
fi
