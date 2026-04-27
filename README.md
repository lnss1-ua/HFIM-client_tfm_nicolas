# FIM Client - Fault Injection Benchmarks

Write bare-metal benchmarks, build them locally, and run fault injection campaigns on the FIM server.

## Quick Start

```bash
# 1. Clone this repo
git clone <repo-url>
cd FIM-client

# 2. Install cross-compiler
#    macOS:
brew install riscv64-elf-gcc
#    Ubuntu:
sudo apt install gcc-riscv64-unknown-elf

# 3. Build a benchmark
./build.sh benchmarks/mmult

# 4. Upload to FIM server
scp benchmarks/mmult/build/mmult_riscv64.elf fim-sim@<SERVER_IP>:/srv/fim-uploads/

# 5. Connect to server and run campaign (via SSH tunnel + TUI)
#    Ask your supervisor for the SSH key and server IP
```

## Writing a Benchmark

Copy the template and modify:

```bash
cp -r benchmarks/template benchmarks/my_algo
```

Edit `benchmarks/my_algo/main.c`:

```c
#include "fim_exit.h"

#define N 64

/* Global volatile — FIM reads this to detect SDC */
volatile int result[N];

int main(void) {
    /* Initialize inputs BEFORE fim_init() */
    int input[N];
    for (int i = 0; i < N; i++) input[i] = i;

    fim_init();  /* === fault injection window starts === */

    /* Your computation */
    for (int i = 0; i < N; i++) {
        result[i] = input[i] * input[i] + 1;
    }

    fim_exit(0); /* === fault injection window ends === */
}
```

Edit `benchmarks/my_algo/fim.yaml`:

```yaml
observable_outputs:
  comparison: "exact"
  variables:
    - name: "result"
```

Build and upload:

```bash
./build.sh benchmarks/my_algo
scp benchmarks/my_algo/build/my_algo_riscv64.elf fim-sim@<SERVER_IP>:/srv/fim-uploads/
```

## Key Rules

1. **`fim_init()` / `fim_exit(0)`** bracket the code you want to test. Faults are only injected between these markers.

2. **Global `volatile` variables** are how FIM detects Silent Data Corruption. Declare your output as `volatile int result[N]` at file scope.

3. **`fim.yaml`** lists which variables to compare against the golden run. Types are auto-detected from the ELF (compiled with `-g`). Just list names.

4. **No UART, no OS, no stdlib.** This runs bare-metal on QEMU. You get `<stdint.h>` and that's it. No `printf`, no `malloc`, no `#include <stdio.h>`.

5. **Input setup before `fim_init()`**. Initialize arrays, set constants, etc. before the injection window. Otherwise faults in initialization corrupt the test.

## Project Structure

```
FIM-client/
  build.sh                    # Build script
  sdk/
    include/fim_exit.h        # fim_init() / fim_exit() API
    src/fim_instrumentation.c # Implementation (linked automatically)
    riscv64/                  # RISC-V startup + linker script
    aarch64/                  # AArch64 startup + linker script
  benchmarks/
    template/                 # Copy this to start
      main.c
      fim.yaml
    mmult/                    # 16x16 matrix multiply
    fibonacci/                # Fibonacci sequence
    bitcount/                 # Hamming weight / popcount
    checksum/                 # XOR reduction
```

## FIM Server Connection

Your supervisor will provide:
- **Server IP** (e.g., `10.25.224.143`)
- **SSH key** for the `fim-sim` user
- **Port**: `8765` (TCP, tunneled over SSH)

To connect:

```bash
# Open SSH tunnel
ssh -i ~/.ssh/fim-sim -N -L 8765:localhost:8765 fim-sim@<SERVER_IP> &

# Then use the TUI or API to run campaigns
```

## Fault Injection Outcomes

After a campaign, each injection is classified:

| Outcome | Meaning |
|---------|---------|
| **MASKED** | Fault had no effect on the result |
| **SDC** | Silent Data Corruption — wrong result, undetected |
| **DETECTED** | Benchmark's own error detection caught the fault |
| **CRASH** | QEMU crashed or hung |
| **TIMEOUT** | Execution exceeded time limit |

The goal is typically to minimize SDC rate through redundancy techniques (DMR, checksums, etc.).

## Architectures

| Arch | Compiler | QEMU Machine |
|------|----------|--------------|
| `riscv64` | `riscv64-unknown-elf-gcc` | `virt` (rv64) |
| `aarch64` | `aarch64-linux-gnu-gcc` | `virt` (cortex-a57) |

Build for a specific arch:

```bash
./build.sh benchmarks/mmult --arch aarch64
```
