#!/usr/bin/env bash
# Test script for the Tailnet-only, key-only SSH setup on "am6"
# (see tailscale_setup.md, ufw_rules.sh, sshd_hardening.sh).
#
# RUN THIS FROM THE CLIENT MACHINE — not on am6 itself. Loopback traffic
# always bypasses ufw's default-deny, so testing from am6 against its own
# IPs would not actually exercise the Tailnet-only restriction.
#
# Edit the variables below for your setup, then: ./test_ssh_setup.sh

set -uo pipefail

# --- Variables — edit these ---
REMOTE_USER="am"                  # SSH user on am6
REMOTE_TS_HOST="100.78.110.5"     # am6's Tailscale IP (`tailscale ip -4` on am6)
REMOTE_LAN_HOST=""                # am6's LAN IP, e.g. 192.168.2.38 — leave
                                   # blank to skip test 4 (only meaningful
                                   # if THIS client is on the same LAN and
                                   # NOT reaching am6 via Tailscale)
SSH_KEY=""                        # path to private key, or "" for default identity
CONNECT_TIMEOUT=8
# --- End variables ---

KEY_OPT=()
[[ -n "$SSH_KEY" ]] && KEY_OPT=(-i "$SSH_KEY")

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== Test 1: key auth over Tailnet should succeed ==="
if out=$(ssh -o BatchMode=yes -o ConnectTimeout="$CONNECT_TIMEOUT" \
    -o StrictHostKeyChecking=accept-new "${KEY_OPT[@]}" \
    "${REMOTE_USER}@${REMOTE_TS_HOST}" 'echo ssh_ok' 2>&1); then
  if [[ "$out" == *"ssh_ok"* ]]; then
    pass "logged in via key over Tailscale IP ($REMOTE_TS_HOST)"
  else
    fail "connected but unexpected output: $out"
  fi
else
  fail "could not log in via key over Tailscale IP — output: $out"
fi
echo

echo "=== Test 2: password auth should be refused (no prompt) ==="
out=$(ssh -o BatchMode=yes -o ConnectTimeout="$CONNECT_TIMEOUT" \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    "${REMOTE_USER}@${REMOTE_TS_HOST}" 'echo should_not_run' 2>&1)
rc=$?
if [[ $rc -ne 0 && "$out" == *"Permission denied"* && "$out" != *"should_not_run"* ]]; then
  pass "password auth rejected (server never offered it)"
else
  fail "unexpected result (rc=$rc): $out"
fi
echo

echo "=== Test 3: keyboard-interactive auth should be refused (no prompt) ==="
out=$(ssh -o BatchMode=yes -o ConnectTimeout="$CONNECT_TIMEOUT" \
    -o PreferredAuthentications=keyboard-interactive -o PubkeyAuthentication=no \
    "${REMOTE_USER}@${REMOTE_TS_HOST}" 'echo should_not_run' 2>&1)
rc=$?
if [[ $rc -ne 0 && "$out" == *"Permission denied"* && "$out" != *"should_not_run"* ]]; then
  pass "keyboard-interactive auth rejected (server never offered it)"
else
  fail "unexpected result (rc=$rc): $out"
fi
echo

echo "=== Test 4: LAN/non-Tailnet path should be unreachable ==="
if [[ -z "$REMOTE_LAN_HOST" ]]; then
  echo "SKIPPED: REMOTE_LAN_HOST not set"
elif ! command -v nc >/dev/null 2>&1; then
  echo "SKIPPED: 'nc' not available on this client"
else
  if timeout $((CONNECT_TIMEOUT + 2)) nc -zv -w "$CONNECT_TIMEOUT" "$REMOTE_LAN_HOST" 22 2>&1; then
    fail "LAN IP ($REMOTE_LAN_HOST:22) responded — it should be unreachable"
  else
    pass "LAN IP ($REMOTE_LAN_HOST:22) unreachable (timed out / dropped, as expected)"
  fi
fi
echo

echo "=== Summary: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
