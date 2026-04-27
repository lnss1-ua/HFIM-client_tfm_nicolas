#!/usr/bin/env bash
# Download campaign results from the FIM server
#
# Usage:
#   ./download-results.sh                     # list available results
#   ./download-results.sh mmult_riscv64_*     # download specific result
#   ./download-results.sh --all               # download all results
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse config.yaml
USER=$(python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['user'])" 2>/dev/null \
    || grep '^user:' "$SCRIPT_DIR/config.yaml" | awk '{print $2}')
SERVER=$(python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['server'])" 2>/dev/null \
    || grep '^server:' "$SCRIPT_DIR/config.yaml" | awk '{print $2}')
SSH_KEY=$(python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['ssh_key'])" 2>/dev/null \
    || grep '^ssh_key:' "$SCRIPT_DIR/config.yaml" | awk '{print $2}')
SSH_KEY="${SSH_KEY/#\~/$HOME}"

REMOTE="fim-${USER}@${SERVER}"
REMOTE_RESULTS="/srv/fim/users/${USER}/results"
LOCAL_RESULTS="$SCRIPT_DIR/results"

SSH_OPTS="-o StrictHostKeyChecking=no"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

mkdir -p "$LOCAL_RESULTS"

if [ $# -eq 0 ]; then
    echo "Available results for ${USER}:"
    echo ""
    ssh $SSH_OPTS "$REMOTE" "ls ${REMOTE_RESULTS}/ 2>/dev/null" || echo "  (none)"
    echo ""
    echo "Usage: $0 <result_name>    Download specific result"
    echo "       $0 --all            Download all results"
    exit 0
fi

if [ "$1" = "--all" ]; then
    echo "Downloading all results..."
    scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/" "$LOCAL_RESULTS/"
else
    echo "Downloading $1..."
    scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/$1" "$LOCAL_RESULTS/"
fi

echo "Results saved to: $LOCAL_RESULTS/"
