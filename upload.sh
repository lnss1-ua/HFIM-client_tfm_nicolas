#!/usr/bin/env bash
# Upload a benchmark to the FIM server
#
# Usage:
#   ./upload.sh benchmarks/mmult              # upload source + ELF + fim.yaml
#   ./upload.sh benchmarks/mmult --build      # build first, then upload
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

if [ -z "$USER" ] || [ -z "$SERVER" ]; then
    echo "Error: fill in config.yaml first (user, server, ssh_key)"
    exit 1
fi

REMOTE="fim-${USER}@${SERVER}"
REMOTE_BASE="/srv/fim/users/${USER}/benchmarks"
BUILD_FIRST=false
BENCHMARK_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build) BUILD_FIRST=true; shift ;;
        -h|--help)
            echo "Usage: $0 <benchmark_dir> [--build]"
            echo ""
            echo "  --build    Build before uploading"
            exit 0 ;;
        *) BENCHMARK_DIR="$1"; shift ;;
    esac
done

if [ -z "$BENCHMARK_DIR" ]; then
    echo "Usage: $0 <benchmark_dir> [--build]"
    echo ""
    echo "Available benchmarks:"
    for d in "$SCRIPT_DIR"/benchmarks/*/; do
        [ -f "$d/main.c" ] && echo "  benchmarks/$(basename "$d")"
    done
    exit 1
fi

BENCHMARK_DIR="$(cd "$BENCHMARK_DIR" && pwd)"
NAME="$(basename "$BENCHMARK_DIR")"

# Build first if requested
if [ "$BUILD_FIRST" = true ]; then
    "$SCRIPT_DIR/build.sh" "$BENCHMARK_DIR"
fi

echo "Uploading ${NAME} to ${REMOTE}:${REMOTE_BASE}/${NAME}/"
echo ""

# Upload the benchmark folder (source + build + config)
SSH_OPTS="-o StrictHostKeyChecking=no"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

scp $SSH_OPTS -r "$BENCHMARK_DIR" "${REMOTE}:${REMOTE_BASE}/"

echo ""
echo "Uploaded: ${NAME}"
echo "  Remote: ${REMOTE_BASE}/${NAME}/"

# List what was uploaded
echo "  Files:"
find "$BENCHMARK_DIR" -type f | while read f; do
    echo "    $(basename "$f")"
done
