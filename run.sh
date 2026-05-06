#!/usr/bin/env bash
# Run a fault injection campaign on the FIM server
#
# Usage:
#   ./run.sh benchmarks/mmult                           # upload + build + golden + 20 injections
#   ./run.sh benchmarks/mmult -n 100                    # 100 injections
#   ./run.sh benchmarks/mmult --fault memory            # memory faults
#   ./run.sh benchmarks/mmult --workers 4               # 4 parallel QEMU instances
#   ./run.sh benchmarks/mmult --arch aarch64             # build for aarch64
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse config
read_config() {
    python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['$1'])" 2>/dev/null \
        || grep "^$1:" "$SCRIPT_DIR/config.yaml" | awk '{print $2}'
}

USER=$(read_config user)
SERVER=$(read_config server)
SSH_KEY=$(read_config ssh_key)
SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [ -z "$USER" ] || [ -z "$SERVER" ]; then
    echo "Error: fill in config.yaml first"
    exit 1
fi

REMOTE="fim-${USER}@${SERVER}"
SSH_OPTS="-o StrictHostKeyChecking=no"
[ -f "$SSH_KEY" ] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

# Parse arguments — extract benchmark dir, pass the rest through
BENCHMARK_DIR=""
PASS_ARGS=()

for arg in "$@"; do
    if [ -z "$BENCHMARK_DIR" ] && [ -d "$arg" ]; then
        BENCHMARK_DIR="$arg"
    elif [ -z "$BENCHMARK_DIR" ] && [ -d "$SCRIPT_DIR/$arg" ]; then
        BENCHMARK_DIR="$SCRIPT_DIR/$arg"
    else
        PASS_ARGS+=("$arg")
    fi
done

if [ -z "$BENCHMARK_DIR" ]; then
    echo "Usage: $0 <benchmark_dir> [options]"
    echo ""
    echo "Options:"
    echo "  -n, --injections N    Number of fault injections (default: 20)"
    echo "  --fault TYPE          register or memory (default: register)"
    echo "  --workers N           Parallel QEMU instances (default: 1)"
    echo "  --arch ARCH           riscv64 or aarch64 (default: riscv64)"
    echo "  --seed N              PRNG seed (default: 42)"
    echo ""
    echo "Available benchmarks:"
    for d in "$SCRIPT_DIR"/benchmarks/*/; do
        [ -f "$d/main.c" ] && echo "  benchmarks/$(basename "$d")"
    done
    exit 1
fi

NAME="$(basename "$BENCHMARK_DIR")"

# ── Upload benchmark to server ────────────────────────────────────
echo "Uploading ${NAME}..."
scp $SSH_OPTS -r "$BENCHMARK_DIR" "${REMOTE}:/srv/fim/users/${USER}/benchmarks/"
echo ""

# ── Run on server (build + golden + campaign) ─────────────────────
ssh $SSH_OPTS "$REMOTE" "fim-run run ${NAME} ${PASS_ARGS[*]:-}" 2>&1 | \
    sed -e 's|/srv/fim/users/[^/]*/||g' -e 's|/home/[^/]*/[^ ]*FIM/||g' -e 's|\x1b\[[0-9;]*m||g'

# ── Pull results back to local machine ────────────────────────────
REMOTE_RESULTS="/srv/fim/users/${USER}/results"
LOCAL_RESULTS="$SCRIPT_DIR/results"
mkdir -p "$LOCAL_RESULTS"

echo ""
echo "Downloading results..."
# Find the latest result directory for this benchmark
LATEST=$(ssh $SSH_OPTS "$REMOTE" "ls -1d ${REMOTE_RESULTS}/${NAME}_* 2>/dev/null | sort | tail -1")
if [ -n "$LATEST" ]; then
    RESULT_NAME=$(basename "$LATEST")
    scp $SSH_OPTS -r "${REMOTE}:${LATEST}" "$LOCAL_RESULTS/"
    echo "  Saved to: results/${RESULT_NAME}/"

    # Clean up results on server
    ssh $SSH_OPTS "$REMOTE" "rm -rf ${LATEST}"
    echo "  Cleaned server copy"

    # Also pull logs
    REMOTE_LOGS="/srv/fim/users/${USER}/logs"
    mkdir -p "$LOCAL_RESULTS/${RESULT_NAME}"
    scp $SSH_OPTS "${REMOTE}:${REMOTE_LOGS}/fim.log" "$LOCAL_RESULTS/${RESULT_NAME}/server.log" 2>/dev/null && \
        echo "  Server log saved to: results/${RESULT_NAME}/server.log"
else
    echo "  No results found to download"
fi

echo ""
echo "Done."
