# FIM Client - Fault Injection Benchmarks

Write bare-metal benchmarks and run fault injection campaigns on the FIM server.

## Setup

1. Get from your supervisor:
   - SSH private key file (e.g., `fim-enrique`)
   - Server IP (e.g., `10.25.224.143`)
   - Your username (e.g., `enrique`)

2. Save the key:
   ```bash
   cp fim-enrique ~/.ssh/fim-enrique
   chmod 600 ~/.ssh/fim-enrique
   ```

3. Edit `config.yaml`:
   ```yaml
   user: enrique
   server: 10.25.224.143
   ssh_key: ~/.ssh/fim-enrique
   port: 8765
   ```

4. Test connection:
   ```bash
   ssh -i ~/.ssh/fim-enrique fim-enrique@10.25.224.143 'fim-run list'
   ```

## Running a Campaign

One command does everything — upload, build, golden run, fault injection, download results:

```bash
./run.sh benchmarks/mmult -n 20
```

Options:
```
-n, --injections N    Number of fault injections (default: 20)
--fault TYPE          register or memory (default: register)
--workers N           Parallel QEMU instances (default: 1)
--arch ARCH           riscv64 or aarch64 (default: riscv64)
--seed N              PRNG seed for reproducibility (default: 42)
```

Results are saved to `results/` on your machine. Server is cleaned automatically.

## Writing a Benchmark

Copy the template:

```bash
cp -r benchmarks/template benchmarks/my_algo
```

Edit `benchmarks/my_algo/main.c`:

```c
#include "fim_exit.h"

#define N 64

volatile int result[N];

int main(void) {
    int input[N];
    for (int i = 0; i < N; i++) input[i] = i;

    fim_init();  /* fault injection window starts */

    for (int i = 0; i < N; i++) {
        result[i] = input[i] * input[i] + 1;
    }

    fim_exit(0); /* fault injection window ends */
}
```

Edit `benchmarks/my_algo/fim.yaml`:

```yaml
observable_outputs:
  comparison: "exact"
  variables:
    - name: "result"
```

Run:

```bash
./run.sh benchmarks/my_algo -n 50
```

## Key Rules

1. **`fim_init()` / `fim_exit(0)`** bracket the code under test. Faults are only injected between these markers.

2. **Global `volatile` variables** are how FIM detects SDC. Declare outputs as `volatile int result[N]` at file scope.

3. **`fim.yaml`** lists observable variables. Types are auto-detected from the ELF. Just list names.

4. **No stdlib.** This runs bare-metal on QEMU. You get `<stdint.h>` and that's it. No `printf`, no `malloc`.

5. **Initialize before `fim_init()`.** Setup arrays and constants before the injection window.

## Benchmarks with External Feeders

For benchmarks that communicate via serial (e.g., robot arm with PyBullet):

1. Add a `requirements.txt` with Python dependencies
2. Add `serial_pty` and `serial_feeder_cmd` to `fim.yaml`:

```yaml
timeout: 120
observable_outputs:
  variables:
    - name: "tau"
    - name: "posicion"

serial_pty: true
serial_feeder_cmd: "python3 {benchmark_dir}/feeder.py --pty {pty}"
```

The server auto-installs requirements and runs the feeder alongside QEMU.

## Other Commands

```bash
./upload.sh benchmarks/my_algo          # upload only
./download-results.sh                   # list past results
./download-results.sh --all             # download all results
```

## Project Structure

```
FIM-client/
  config.yaml                  # your server connection
  run.sh                       # upload + build + run + download
  upload.sh                    # upload benchmark to server
  download-results.sh          # pull results
  build.sh                     # local cross-compile (optional)
  sdk/                         # FIM SDK (don't modify)
    include/fim_exit.h
    src/fim_instrumentation.c
    riscv64/                   # startup + linker
    aarch64/
  benchmarks/
    template/                  # copy this to start
    mmult/                     # 16x16 matrix multiply
    fibonacci/                 # Fibonacci sequence
    bitcount/                  # Hamming weight
    checksum/                  # XOR reduction
    robot_arm/                 # PID controller with PyBullet feeder
  results/                     # campaign results (local)
```

## Fault Injection Outcomes

| Outcome | Meaning |
|---------|---------|
| **MASKED** | Fault had no effect on the result |
| **SDC** | Silent Data Corruption — wrong result, undetected |
| **DETECTED** | Benchmark's own error detection caught the fault |
| **CRASH** | Program crashed |
| **TIMEOUT** | Execution exceeded time limit |
