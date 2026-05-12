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

# Check for --batch mode
BATCH_FILE=""
BATCH_BG=""
PREV_WAS_BATCH=false
for arg in "$@"; do
    if [ "$PREV_WAS_BATCH" = true ]; then BATCH_FILE="$arg"; PREV_WAS_BATCH=false; continue; fi
    if [ "$arg" = "--batch" ]; then PREV_WAS_BATCH=true; continue; fi
    if [ "$arg" = "--background" ]; then BATCH_BG="--background"; fi
done

if [ -n "$BATCH_FILE" ]; then
    # Batch mode: upload all benchmarks referenced in YAML, then run batch
    if [ ! -f "$BATCH_FILE" ]; then
        echo "Error: batch file not found: $BATCH_FILE"
        exit 1
    fi

    echo "Batch campaign: $BATCH_FILE"
    echo ""

    # Extract benchmark names from YAML and upload each
    BENCHMARKS=$(python3 -c "
import yaml
with open('$BATCH_FILE') as f:
    b = yaml.safe_load(f)
seen = set()
for c in b.get('campaigns', []):
    name = c.get('benchmark', b.get('defaults', {}).get('benchmark', ''))
    if name and name not in seen:
        print(name)
        seen.add(name)
" 2>/dev/null)

    for bench in $BENCHMARKS; do
        BENCH_DIR="$SCRIPT_DIR/benchmarks/$bench"
        if [ -d "$BENCH_DIR" ]; then
            echo "Uploading ${bench}..."
            scp $SSH_OPTS -r "$BENCH_DIR" "${REMOTE}:/srv/fim/users/${USER}/benchmarks/"
        else
            echo "Warning: benchmark ${bench} not found locally, skipping upload"
        fi
    done

    # Upload the batch YAML
    BATCH_NAME=$(basename "$BATCH_FILE")
    scp $SSH_OPTS "$BATCH_FILE" "${REMOTE}:/srv/fim/users/${USER}/${BATCH_NAME}"
    echo ""

    # Run batch on server
    ssh $SSH_OPTS "$REMOTE" "fim-run batch ${BATCH_NAME} $BATCH_BG" 2>&1 | \
        sed -e 's|/srv/fim/users/[^/]*/||g' -e 's|/home/[^/]*/[^ ]*/||g' -e 's|\x1b\[[0-9;]*m||g'

    if [ -n "$BATCH_BG" ]; then
        echo ""
        echo "Check status:     ./status.sh"
        echo "Download results: ./status.sh --download"
    else
        # Download all results
        REMOTE_RESULTS="/srv/fim/users/${USER}/results"
        LOCAL_RESULTS="$SCRIPT_DIR/results"
        mkdir -p "$LOCAL_RESULTS"
        echo ""
        echo "Downloading results..."
        for dir in $(ssh $SSH_OPTS "$REMOTE" "ls -d ${REMOTE_RESULTS}/*/ 2>/dev/null" | xargs -n1 basename 2>/dev/null); do
            scp $SSH_OPTS -r "${REMOTE}:${REMOTE_RESULTS}/${dir}" "$LOCAL_RESULTS/"
            ssh $SSH_OPTS "$REMOTE" "rm -rf ${REMOTE_RESULTS}/${dir}"
            echo "  $dir"
        done
        echo "Done."
    fi
    exit 0
fi

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
    echo "       $0 --batch <campaign.yaml> [--background]"
    echo ""
    echo "Options:"
    echo "  -n, --injections N    Number of fault injections (default: 20)"
    echo "  --fault TYPE          register or memory (default: register)"
    echo "  --workers N           Parallel QEMU instances (default: 1)"
    echo "  --arch ARCH           riscv64 or aarch64 (default: riscv64)"
    echo "  --seed N              PRNG seed (default: 42)"
    echo "  --background          Run in background"
    echo "  --batch FILE          Run multiple campaigns from YAML config"
    echo ""
    echo "Available benchmarks:"
    for d in "$SCRIPT_DIR"/benchmarks/*/; do
        [ -f "$d/main.c" ] || [ -f "$d/Cargo.toml" ] && echo "  benchmarks/$(basename "$d")"
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
    sed -e 's|/srv/fim/users/[^/]*/||g' -e 's|/home/[^/]*/[^ ]*/||g' -e 's|\x1b\[[0-9;]*m||g'

# If --background, skip download (results not ready yet)
for arg in "${PASS_ARGS[@]}"; do
    if [ "$arg" = "--background" ]; then
        echo ""
        echo "Check status:     ./status.sh"
        echo "Download results: ./status.sh --download"
        exit 0
    fi
done

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

    # Append local git info to provenance (if in a git repo)
    PROV_FILE="$LOCAL_RESULTS/${RESULT_NAME}/provenance.json"
    if [ -f "$PROV_FILE" ] && git -C "$SCRIPT_DIR" rev-parse HEAD &>/dev/null; then
        GIT_COMMIT=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null)
        GIT_DIRTY=$(git -C "$SCRIPT_DIR" diff --quiet 2>/dev/null && echo "false" || echo "true")
        GIT_BRANCH=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
        # Merge git info into provenance.json
        python3 -c "
import json
with open('$PROV_FILE') as f: p = json.load(f)
p['git_commit'] = '$GIT_COMMIT'
p['git_branch'] = '$GIT_BRANCH'
p['git_dirty'] = $GIT_DIRTY
with open('$PROV_FILE', 'w') as f: json.dump(p, f, indent=4)
" 2>/dev/null
    fi
else
    echo "  No results found to download"
fi

echo ""
echo "Done."
