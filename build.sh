#!/usr/bin/env bash
# Build a FIM benchmark for a target architecture
#
# Usage:
#   ./build.sh benchmarks/mmult                    # default: riscv64
#   ./build.sh benchmarks/mmult --arch aarch64
#
# Requires: RISC-V or AArch64 cross-compiler (see README.md)
#
# Output: benchmarks/<name>/build/<name>_<arch>.elf
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_DIR="$SCRIPT_DIR/sdk"

ARCH="riscv64"
BENCHMARK_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch) ARCH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 <benchmark_dir> [--arch riscv64|aarch64]"
            exit 0 ;;
        *) BENCHMARK_DIR="$1"; shift ;;
    esac
done

if [ -z "$BENCHMARK_DIR" ]; then
    echo "Usage: $0 <benchmark_dir> [--arch riscv64|aarch64]"
    echo ""
    echo "Examples:"
    echo "  $0 benchmarks/mmult"
    echo "  $0 benchmarks/template --arch aarch64"
    exit 1
fi

BENCHMARK_DIR="$(cd "$BENCHMARK_DIR" && pwd)"
NAME="$(basename "$BENCHMARK_DIR")"
BUILD_DIR="${BENCHMARK_DIR}/build"
mkdir -p "$BUILD_DIR"

# Find cross-compiler
case "$ARCH" in
    riscv64)
        CC=""
        for candidate in \
            "${RISCV_CC:-}" \
            "riscv64-unknown-elf-gcc" \
            "riscv64-unknown-linux-gnu-gcc" \
            "riscv64-linux-gnu-gcc"; do
            [ -n "$candidate" ] && command -v "$candidate" &>/dev/null && CC="$candidate" && break
        done
        if [ -z "$CC" ]; then
            echo "Error: no RISC-V cross-compiler found"
            echo ""
            echo "Install one of:"
            echo "  macOS:  brew install riscv64-elf-gcc"
            echo "  Ubuntu: sudo apt install gcc-riscv64-unknown-elf"
            echo "  Or set RISCV_CC=/path/to/riscv64-gcc"
            exit 1
        fi
        CFLAGS="-O1 -g -mcmodel=medany -nostdlib -static -ffreestanding"
        ;;
    aarch64)
        CC="${AARCH64_CC:-aarch64-linux-gnu-gcc}"
        if ! command -v "$CC" &>/dev/null; then
            echo "Error: $CC not found"
            echo "Install: sudo apt install gcc-aarch64-linux-gnu"
            exit 1
        fi
        CFLAGS="-O1 -g -nostdlib -static -ffreestanding"
        ;;
    *)
        echo "Error: unsupported arch '$ARCH' (use riscv64 or aarch64)"
        exit 1
        ;;
esac

ELF_OUT="${BUILD_DIR}/${NAME}_${ARCH}.elf"

# Find source files
if [ -f "${BENCHMARK_DIR}/main.c" ]; then
    C_FILES="${BENCHMARK_DIR}/main.c"
else
    C_FILES=$(find "$BENCHMARK_DIR" -maxdepth 1 -name "*.c" | head -1)
    if [ -z "$C_FILES" ]; then
        echo "Error: no .c files found in ${BENCHMARK_DIR}"
        exit 1
    fi
fi

echo "Building ${NAME} for ${ARCH}"
echo "  Compiler: $CC"
echo "  Sources:  $(basename $C_FILES)"
echo ""

$CC $CFLAGS \
    -I"${SDK_DIR}/include" \
    -T "${SDK_DIR}/${ARCH}/link.ld" \
    "${SDK_DIR}/${ARCH}/start.S" \
    "${SDK_DIR}/src/fim_instrumentation.c" \
    $C_FILES \
    -o "$ELF_OUT" 2>&1

echo "Built: ${ELF_OUT}"
echo "Size:  $(wc -c < "$ELF_OUT") bytes"
echo ""
echo "Next: upload to FIM server"
echo "  scp ${ELF_OUT} fim-sim@<SERVER_IP>:/srv/fim-uploads/"
