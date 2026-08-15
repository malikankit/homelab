# Tailscale Setup — Tailnet-only, key-only SSH

Goal: this machine is reachable over SSH **only via its Tailscale (Tailnet)
IP** — no LAN or public-IP SSH — and authentication is **SSH key only**
(nothing in `authorized_keys` co-exists with password/keyboard-interactive
auth). Tailscale SSH (the `--ssh` flag) is deliberately **not** used, so
that OpenSSH's own `authorized_keys` stays the single source of truth for
who can log in, rather than Tailscale ACLs.

## Why not Tailscale SSH?

Tailscale SSH (`tailscale up --ssh`) replaces `sshd` authentication with
Tailscale's own identity/ACL system — no host keys, access controlled from
the admin console. That's a different trust model than "only these
`authorized_keys` entries can log in." Since the requirement is strictly
SSH-key auth via `authorized_keys`, Tailscale SSH is simply never enabled
— everything below is plain OpenSSH, and Tailscale's only job is to be the
one network path SSH is reachable on.

## a) Install Tailscale

```
curl -fsSL https://tailscale.com/install.sh | sh
```

Adds Tailscale's apt repo and installs the `tailscale` package/daemon.

Verify:
```
tailscale version
systemctl status tailscaled
```

## b) Login via the UI

```
sudo tailscale up
```

No `--ssh` flag — that's what keeps Tailscale SSH off. This prints a
`https://login.tailscale.com/...` URL; open it in a browser and
authenticate against the tailnet.

Verify:
```
tailscale status
```
Device should show `online` with an assigned `100.x.y.z` address, and
appear in the Tailscale admin console.

## c) Restrict SSH to Tailnet IPs only

Two layers — network (firewall) and application (sshd bind is *not* used
here since Tailscale IPs can change if a node is re-registered; the
firewall rule is interface-based so it doesn't care):

1. Install/confirm `openssh-server`:
   ```
   sudo apt install openssh-server
   sudo systemctl enable --now ssh
   ```

2. Firewall: allow port 22 only on the `tailscale0` interface, default-deny
   everything else incoming:
   ```
   sudo ufw allow in on tailscale0 to any port 22 proto tcp
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw enable
   ```
   **Ordering matters**: add the `tailscale0` allow rule *before*
   `ufw enable` takes effect, so there's no window where SSH is reachable
   from LAN and no window where it's unreachable from anywhere. Test the
   Tailscale path works before treating LAN SSH as gone.

3. Verify no other path to port 22:
   ```
   sudo ufw status verbose
   ```
   Should show the port-22 rule scoped to `tailscale0` only — nothing on
   `eno1`/`wlp2s0`/`any`.

## d) Key-only auth (no passwords, Tailscale SSH stays off)

1. Put the **client machine's** public key (the laptop/device that will
   SSH *into* this box — not the GitHub key from journal step 1, that's a
   separate keypair for git) into `~/.ssh/authorized_keys`:
   ```
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   echo "<client public key>" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

2. Edit `/etc/ssh/sshd_config` (or add a file under
   `/etc/ssh/sshd_config.d/`) to make pubkey the *only* auth method:
   ```
   PubkeyAuthentication yes
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   ChallengeResponseAuthentication no
   AuthenticationMethods publickey
   PermitRootLogin no
   ```

3. Validate and restart:
   ```
   sudo sshd -t
   sudo systemctl restart ssh
   ```

4. Confirm Tailscale SSH is off:
   ```
   tailscale debug prefs
   ```
   Should show `"RunSSH": false`.

## Verification

- From another tailnet device: `ssh <user>@100.x.y.z` — succeeds via key.
- LAN IP refuses/times out on 22, e.g. from another LAN host:
  `nc -zv -w3 <lan-ip> 22`.
- Password auth is rejected outright (no password prompt at all):
  ```
  ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password <user>@100.x.y.z
  ```
