#!/usr/bin/env bash
# sshd hardening: key-only auth (no passwords, no keyboard-interactive),
# Tailscale SSH left off (see tailscale_setup.md).
#
# Writes a drop-in file rather than editing /etc/ssh/sshd_config directly:
# Ubuntu's default sshd_config has `Include /etc/ssh/sshd_config.d/*.conf`
# as its first line, and OpenSSH uses the FIRST value seen per keyword —
# so this drop-in wins over anything later in the main file, and rollback
# is just deleting/renaming this one file.
#
# Steps: a) locate sshd_config  b) show current effective values
#        c) show target values  d) timestamped backup  e) apply
#        f) validate + restart + confirm
#
# Idempotent — safe to re-run after editing DROPIN_CONTENT below.
#
# Usage: sudo ./sshd_hardening.sh

set -euo pipefail

MAIN_CONFIG="/etc/ssh/sshd_config"
DROPIN="/etc/ssh/sshd_config.d/00-tailnet-hardening.conf"
BACKUP_DIR="/etc/ssh/sshd_config.d.backups"
TS="$(date +%Y%m%d-%H%M%S)"

# Note: ChallengeResponseAuthentication is set in the drop-in for older-sshd
# compatibility, but modern OpenSSH treats it as a pure alias for
# KbdInteractiveAuthentication and `sshd -T` never reports it as a separate
# keyword — so it's intentionally left out of this verification list to
# avoid a false-negative match.
DIRECTIVES=(
  PubkeyAuthentication
  PasswordAuthentication
  KbdInteractiveAuthentication
  AuthenticationMethods
  PermitRootLogin
)

read -r -d '' DROPIN_CONTENT <<'EOF' || true
# Managed by sshd_hardening.sh in homelab/geekom — do not hand-edit.
# Key-only SSH auth. Tailscale SSH stays off (see tailscale_setup.md);
# network exposure is restricted to the Tailnet via ufw (see ufw_rules.sh).
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
AuthenticationMethods publickey
PermitRootLogin no
EOF

if [[ $EUID -ne 0 ]]; then
  echo "Must run as root: sudo $0" >&2
  exit 1
fi

# a) locate sshd_config
if [[ ! -f "$MAIN_CONFIG" ]]; then
  echo "ERROR: $MAIN_CONFIG not found — is openssh-server installed?" >&2
  exit 1
fi
echo "== a) Found $MAIN_CONFIG =="

# b) show current effective values (sshd -T resolves includes/defaults)
echo
echo "== b) Current effective values =="
for d in "${DIRECTIVES[@]}"; do
  sshd -T 2>/dev/null | grep -i "^${d} " || echo "${d} <not set / default>"
done

# c) show target values
echo
echo "== c) Target values (from $DROPIN) =="
echo "$DROPIN_CONTENT"

# d) timestamped backups
mkdir -p "$BACKUP_DIR"
cp -a "$MAIN_CONFIG" "$BACKUP_DIR/sshd_config.${TS}.bak"
echo
echo "== d) Backed up $MAIN_CONFIG -> $BACKUP_DIR/sshd_config.${TS}.bak =="
if [[ -f "$DROPIN" ]]; then
  cp -a "$DROPIN" "$BACKUP_DIR/$(basename "$DROPIN").${TS}.bak"
  echo "   Backed up existing $DROPIN -> $BACKUP_DIR/$(basename "$DROPIN").${TS}.bak"
fi

# e) apply
mkdir -p "$(dirname "$DROPIN")"
echo "$DROPIN_CONTENT" > "$DROPIN"
chmod 644 "$DROPIN"
echo
echo "== e) Wrote $DROPIN =="

# f) validate, restart, confirm
if ! sshd -t; then
  echo "ERROR: sshd -t failed validation — restoring backup, NOT restarting ssh." >&2
  cp -a "$BACKUP_DIR/sshd_config.${TS}.bak" "$MAIN_CONFIG"
  rm -f "$DROPIN"
  exit 1
fi
echo "== f) sshd -t: config OK =="

systemctl restart ssh
echo "   ssh service restarted"

echo
echo "== f) Confirming applied values =="
FAIL=0
for d in "${DIRECTIVES[@]}"; do
  actual="$(sshd -T 2>/dev/null | grep -i "^${d} " || true)"
  echo "$actual"
  case "$d" in
    PubkeyAuthentication) [[ "$actual" =~ yes$ ]] || FAIL=1 ;;
    PasswordAuthentication) [[ "$actual" =~ no$ ]] || FAIL=1 ;;
    KbdInteractiveAuthentication) [[ "$actual" =~ no$ ]] || FAIL=1 ;;
    ChallengeResponseAuthentication) [[ "$actual" =~ no$ ]] || FAIL=1 ;;
    AuthenticationMethods) [[ "$actual" =~ publickey$ ]] || FAIL=1 ;;
    PermitRootLogin) [[ "$actual" =~ no$ ]] || FAIL=1 ;;
  esac
done

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "CONFIRMED: all directives match target values."
else
  echo "WARNING: one or more directives did not match target — review above." >&2
  exit 1
fi
