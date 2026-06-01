#!/usr/bin/env bash
# Download campaign results from the FIM server
#
# Usage:
#   ./download-results.sh                          # list available results
#   ./download-results.sh mmult_riscv64_*          # download specific result
#   ./download-results.sh --all                    # download all results
#   ./download-results.sh --golden <bench>         # download a specific golden dir
#   ./download-results.sh --list-golden            # list golden dirs on server
#   ./download-results.sh --golden-all             # download every golden dir
#   ./download-results.sh <result> --with-golden   # download a result + its golden
#
# golden/ dirs are pulled into ./golden/<bench>/ alongside the existing
# ./results/ tree.
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
REMOTE_GOLDEN="/srv/fim/users/${USER}/golden"
LOCAL_RESULTS="$SCRIPT_DIR/results"
LOCAL_GOLDEN="$SCRIPT_DIR/golden"

SSH_OPTS="-o StrictHostKeyChecking=no"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

mkdir -p "$LOCAL_RESULTS" "$LOCAL_GOLDEN"

# Helper: derive the golden dir name from a campaign result name.
# Campaign names look like:  <bench>_<arch>_<timestamp>           (qemu)
#                       or:  <bench>_<arch>_<timestamp>_gem5      (gem5)
# Golden dir names look like: <bench>_<arch>_qemu   or   <bench>_<arch>_gem5
golden_for() {
    local result="$1"
    # Strip the trailing _<timestamp>(_simulator)? leaving <bench>_<arch>
    local sim="qemu"
    if [[ "$result" == *_gem5 ]]; then sim="gem5"; fi
    # Remove trailing _gem5 (if present) then the timestamp _NNNNNNNN_NNNNNN
    local trimmed="${result%_gem5}"
    trimmed=$(echo "$trimmed" | sed -E 's/_[0-9]{8}_[0-9]{6}_[0-9]+$//')
    echo "${trimmed}_${sim}"
}

if [ $# -eq 0 ]; then
    echo "Available results for ${USER}:"
    echo ""
    ssh $SSH_OPTS "$REMOTE" "ls ${REMOTE_RESULTS}/ 2>/dev/null" || echo "  (none)"
    echo ""
    echo "Usage: $0 <result_name>              Download specific result"
    echo "       $0 --all                      Download all results"
    echo "       $0 --list-golden              List golden runs on server"
    echo "       $0 --golden <bench>           Download a specific golden dir"
    echo "       $0 --golden-all               Download every golden dir"
    echo "       $0 <result> --with-golden     Download result + its golden"
    exit 0
fi

case "$1" in
    --list-golden)
        echo "Available golden dirs for ${USER}:"
        ssh $SSH_OPTS "$REMOTE" "ls ${REMOTE_GOLDEN}/ 2>/dev/null" || echo "  (none)"
        exit 0
        ;;
    --golden)
        if [ $# -lt 2 ]; then
            echo "Error: --golden requires a golden dir name (see --list-golden)"
            exit 1
        fi
        echo "Downloading golden/$2..."
        scp $SSH_OPTS -r "${REMOTE}:${REMOTE_GOLDEN}/$2" "$LOCAL_GOLDEN/"
        echo "Golden saved to: $LOCAL_GOLDEN/$2"
        exit 0
        ;;
    --golden-all)
        echo "Downloading every golden dir..."
        scp $SSH_OPTS -r "${REMOTE}:${REMOTE_GOLDEN}/" "$LOCAL_GOLDEN/"
        echo "Golden saved to: $LOCAL_GOLDEN/"
        exit 0
        ;;
    --all)
        echo "Downloading all results..."
        scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/" "$LOCAL_RESULTS/"
        echo "Results saved to: $LOCAL_RESULTS/"
        exit 0
        ;;
esac

RESULT="$1"
WITH_GOLDEN=false
shift || true
for arg in "$@"; do
    if [ "$arg" = "--with-golden" ]; then WITH_GOLDEN=true; fi
done

echo "Downloading $RESULT..."
scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/$RESULT" "$LOCAL_RESULTS/"
echo "Results saved to: $LOCAL_RESULTS/$RESULT"

if $WITH_GOLDEN; then
    # First-choice golden name (new naming: includes _qemu/_gem5 sim suffix).
    # If that's missing, fall back to the legacy unsuffixed name -- older
    # benchmarks pre-date the sim-suffix convention.
    GOLDEN=$(golden_for "$RESULT")
    LEGACY="${GOLDEN%_qemu}"
    LEGACY="${LEGACY%_gem5}"

    echo ""
    echo "Downloading paired golden..."
    if scp $SSH_OPTS -r "${REMOTE}:${REMOTE_GOLDEN}/$GOLDEN" "$LOCAL_GOLDEN/" 2>/dev/null; then
        echo "Golden saved to: $LOCAL_GOLDEN/$GOLDEN"
    elif [ "$LEGACY" != "$GOLDEN" ] && scp $SSH_OPTS -r "${REMOTE}:${REMOTE_GOLDEN}/$LEGACY" "$LOCAL_GOLDEN/" 2>/dev/null; then
        echo "Golden saved to: $LOCAL_GOLDEN/$LEGACY  (legacy unsuffixed naming)"
    else
        echo "Warning: golden dir not found on server"
        echo "         tried: $GOLDEN, $LEGACY"
        echo "         (use --list-golden to see what's available)"
    fi
fi
