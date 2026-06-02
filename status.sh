#!/usr/bin/env bash
# Show campaign status on the FIM server. Status only -- to fetch results use
# ./download.sh.
#
# Usage:
#   ./status.sh              # list campaigns once and exit
#   ./status.sh --watch      # poll every 5s until all campaigns are terminal
#   ./status.sh --watch 10   # poll every 10s
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

read_config() {
    python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['$1'])" 2>/dev/null \
        || grep "^$1:" "$SCRIPT_DIR/config.yaml" | awk '{print $2}'
}

USER=$(read_config user)
SERVER=$(read_config server)
SSH_KEY=$(read_config ssh_key)
SSH_KEY="${SSH_KEY/#\~/$HOME}"

REMOTE="fim-${USER}@${SERVER}"
SSH_OPTS="-o StrictHostKeyChecking=no"
[ -f "$SSH_KEY" ] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

WATCH=false
INTERVAL=5
if [ "${1:-}" = "--watch" ]; then
    WATCH=true
    [ -n "${2:-}" ] && INTERVAL="$2"
fi

if [ "$WATCH" != true ]; then
    ssh $SSH_OPTS "$REMOTE" "fim-run jobs"
    exit 0
fi

# --watch: redraw the list every INTERVAL seconds. Stop once no campaign is in a
# non-terminal state (running/queued/cancelling). The server owns the campaign
# lifecycle, so this is a pure read loop -- closing it never affects the run.
while true; do
    OUT=$(ssh $SSH_OPTS "$REMOTE" "fim-run jobs")
    clear
    echo "$OUT"
    echo ""
    echo "(watching every ${INTERVAL}s -- Ctrl-C to stop)"
    if ! printf '%s\n' "$OUT" | grep -qE '\[(run |que |canc)\]|\[running\]|\[queued\]|\[cancelling\]'; then
        echo ""
        echo "All campaigns terminal."
        exit 0
    fi
    sleep "$INTERVAL"
done
