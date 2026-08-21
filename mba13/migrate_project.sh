#!/usr/bin/env bash
# Interactively migrate project folders (and their Claude Code session
# history) from mba13-linux's ~/code/<project> to geekom-linux's ~/code/<project>, over
# the mba13-linux -> geekom-linux Tailscale SSH set up by generate_inter_host_key.sh.
#
# Run this ON mba13-linux.
#
# Why absolute paths matter: Claude Code keys sessions to a project's
# absolute path (~/.claude/projects/<path-with-/-replaced-by-->/), so both
# machines must land the code at the identical path for `/resume` to find
# migrated sessions. Both machines use the `am` user today, so `~/code`
# lines up on both ends without translation — see
# ../knowledge/claude_code_session_migration.md for the full picture.
# NOTE: this assumption (same username on both ends) breaks if a future
# migration target uses a different user.
#
# Behavior:
#   - Copies only. Never deletes/moves anything remotely, and only moves
#     things locally if you explicitly opt into cleanup per project.
#   - Dry-runs every rsync and asks for confirmation before the real copy.
#   - A project with no Claude session data still migrates fine (code only).
#   - Loops: pick a project, migrate, optionally declutter, repeat.
#   - Writes a succinct log (project names + status only, nothing
#     sensitive) to ../logs/migrations/, and offers to commit+push it.
#
# Usage: ./migrate_project.sh

set -uo pipefail

CODE_DIR="$HOME/code"
GEEKOM_LINUX_USER="am"
GEEKOM_LINUX_IP="100.78.110.5"
GEEKOM_LINUX_KEY="$HOME/.ssh/mba13-linux_to_tailnet_ed25519"

if [[ ! -f "$GEEKOM_LINUX_KEY" ]]; then
  echo "ERROR: $GEEKOM_LINUX_KEY not found." >&2
  echo "Run ./generate_inter_host_key.sh first and get it authorized on geekom-linux." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/mba13/logs/migrations"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/migration_$(date +%Y-%m-%d_%H%M%S).log"

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

rsync_ssh() {
  local extra="$1" src="$2" dst="$3"
  local opts=(-avz)
  [[ -n "$extra" ]] && opts+=("$extra")
  rsync "${opts[@]}" -e "ssh -i $GEEKOM_LINUX_KEY" "$src" "$dst"
}

log "# Migration run: $(date -Iseconds)"
log ""

MIGRATED_THIS_RUN=()

while true; do
  echo
  echo "== Candidate projects in $CODE_DIR =="
  mapfile -t CANDIDATES < <(
    find "$CODE_DIR" -mindepth 1 -maxdepth 1 -type d \
      ! -name ".*" ! -name "migrated_to_geekom-linux" -printf '%f\n' | sort
  )

  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo "No project directories left under $CODE_DIR."
    break
  fi

  for i in "${!CANDIDATES[@]}"; do
    name="${CANDIDATES[$i]}"
    marker=""
    for m in "${MIGRATED_THIS_RUN[@]}"; do
      [[ "$m" == "$name" ]] && marker=" [migrated this run]"
    done
    echo "  $((i + 1))) $name$marker"
  done
  echo "  0) Done — exit"

  read -rp "Pick a project to migrate (number): " choice
  [[ "$choice" == "0" ]] && break
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CANDIDATES[@]} )); then
    echo "Invalid choice."
    continue
  fi

  PROJECT="${CANDIDATES[$((choice - 1))]}"
  SRC_CODE="$CODE_DIR/$PROJECT/"
  DST_CODE="$GEEKOM_LINUX_USER@$GEEKOM_LINUX_IP:$CODE_DIR/$PROJECT/"
  MANGLED="$(echo "$CODE_DIR/$PROJECT" | sed 's/\//-/g')"
  SRC_SESSION="$HOME/.claude/projects/$MANGLED/"
  DST_SESSION="$GEEKOM_LINUX_USER@$GEEKOM_LINUX_IP:$HOME/.claude/projects/$MANGLED/"

  echo
  echo "== Dry run: code folder ($PROJECT) =="
  rsync_ssh -n "$SRC_CODE" "$DST_CODE"

  HAS_SESSION=0
  if [[ -d "$SRC_SESSION" ]]; then
    HAS_SESSION=1
    echo
    echo "== Dry run: Claude session data =="
    rsync_ssh -n "$SRC_SESSION" "$DST_SESSION"
  else
    echo
    echo "No Claude session data found for $PROJECT — will migrate code only."
  fi

  read -rp "Proceed with migration of '$PROJECT'? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log "SKIPPED $PROJECT (declined after dry run)"
    continue
  fi

  echo "Migrating code..."
  if rsync_ssh "" "$SRC_CODE" "$DST_CODE"; then
    CODE_STATUS="ok"
  else
    CODE_STATUS="FAILED"
  fi

  SESSION_STATUS="skipped (no session data)"
  if [[ "$HAS_SESSION" -eq 1 ]]; then
    echo "Migrating Claude session data..."
    if rsync_ssh "" "$SRC_SESSION" "$DST_SESSION"; then
      SESSION_STATUS="ok"
    else
      SESSION_STATUS="FAILED"
    fi
  fi

  log "PROJECT=$PROJECT code=$CODE_STATUS session=$SESSION_STATUS time=$(date -Iseconds)"

  if [[ "$CODE_STATUS" == "ok" ]]; then
    MIGRATED_THIS_RUN+=("$PROJECT")

    read -rp "Move local '$PROJECT' into $CODE_DIR/migrated_to_geekom-linux/ to declutter (kept as backup, nothing deleted)? (y/N): " cleanup
    if [[ "$cleanup" == "y" || "$cleanup" == "Y" ]]; then
      mkdir -p "$CODE_DIR/migrated_to_geekom-linux"
      mv "$CODE_DIR/$PROJECT" "$CODE_DIR/migrated_to_geekom-linux/$PROJECT"
      log "CLEANUP $PROJECT moved to $CODE_DIR/migrated_to_geekom-linux/"
      echo "Moved to $CODE_DIR/migrated_to_geekom-linux/$PROJECT"
    fi
  else
    echo "Code migration failed — see rsync output above. Not offering cleanup."
  fi
done

echo
echo "== Migration run complete. Log: $LOG_FILE =="
cat "$LOG_FILE"

echo
read -rp "Commit and push this log to the homelab repo now? (y/N): " push_confirm
if [[ "$push_confirm" == "y" || "$push_confirm" == "Y" ]]; then
  (
    cd "$REPO_ROOT" &&
    git add "$LOG_FILE" &&
    git commit -m "Log project migration run ($(date +%Y-%m-%d))" &&
    git push origin main
  )
else
  echo "Not pushed — log saved locally at $LOG_FILE, push whenever ready."
fi
