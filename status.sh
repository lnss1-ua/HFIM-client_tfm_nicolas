#!/usr/bin/env bash
# Check background job status on the FIM server
#
# Usage:
#   ./status.sh              # list all jobs
#   ./status.sh --download   # download results for completed jobs
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

ssh $SSH_OPTS "$REMOTE" "fim-run jobs"

if [ "${1:-}" = "--download" ]; then
    echo ""
    echo "Downloading completed results..."
    REMOTE_RESULTS="/srv/fim/users/${USER}/results"
    LOCAL_RESULTS="$SCRIPT_DIR/results"
    mkdir -p "$LOCAL_RESULTS"

    for dir in $(ssh $SSH_OPTS "$REMOTE" "ls -d ${REMOTE_RESULTS}/*/ 2>/dev/null" | xargs -n1 basename 2>/dev/null); do
        if [ ! -d "$LOCAL_RESULTS/$dir" ]; then
            scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/${dir}" "$LOCAL_RESULTS/"
            ssh $SSH_OPTS "$REMOTE" "rm -rf ${REMOTE_RESULTS}/${dir}"
            echo "  Downloaded: $dir"
        fi
    done
    echo "Done."
fi
