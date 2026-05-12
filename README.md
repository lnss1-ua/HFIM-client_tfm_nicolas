# FIM Client - Fault Injection Benchmarks

Write bare-metal benchmarks and run fault injection campaigns on the FIM server.

## Setup

1. Get from your supervisor:
   - SSH private key file
   - Server IP address
   - Your username

2. Save the key:
   ```bash
   cp <your-key> ~/.ssh/fim-key
   chmod 600 ~/.ssh/fim-key
   ```

3. Edit `config.yaml` (see `config.yaml.example`):
   ```yaml
   user: <your_username>
   server: <server_ip>
   ssh_key: ~/.ssh/fim-key
   ```

4. Test connection:
   ```bash
   ssh -i ~/.ssh/fim-key fim-<your_username>@<server_ip> 'fim-run list'
   ```

## Running a Campaign

One command does everything -- upload, build, golden run, fault injection, download results:

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
--background          Run in background (check with ./status.sh)
```

Results are saved to `results/` on your machine. Server is cleaned automatically.

## Background Mode

For long campaigns, run in background and check later:

```bash
./run.sh benchmarks/mmult -n 1000 --background
```

Check status:
```bash
./status.sh                 # list all jobs and their status
./status.sh --download      # download results for completed jobs
```

## Batch Campaigns

Run multiple campaigns at once from a YAML file:

```bash
./run.sh --batch campaign.yaml
./run.sh --batch campaign.yaml --background
```

The batch file defines multiple campaigns that share defaults. See `campaign.yaml.example` for all options.

## Telegram Notifications (optional)

Get notified when background campaigns finish.

**1. Create a bot:**
- Open Telegram and search for `@BotFather`
- Send `/newbot`
- Choose a name (e.g., "FIM Bot") and username (e.g., `my_fim_bot`)
- BotFather gives you a token like `123456:ABC-xyz` -- save it

**2. Get your chat ID:**
- Open your new bot in Telegram and send `/start`
- Then run this in your terminal (replace the token):
  ```
  curl -s https://api.telegram.org/bot123456:ABC-xyz/getUpdates | python3 -m json.tool | grep '"id"' | head -1
  ```
- The number is your chat ID

**3. Add to config.yaml:**
```yaml
telegram_bot_token: "123456:ABC-xyz"
telegram_chat_id: "987654321"
```

That's it. Background campaigns will send you a summary + CSV when they finish.

## Writing a Benchmark

Copy the template:

```bash
cp -r benchmarks/template benchmarks/my_algo
```

Edit `benchmarks/my_algo/main.c`:

```c
#include "hfim.h"

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

## Results

Each campaign produces a results directory like `results/mmult_riscv64_20250511_143022/` containing:

- `summary.json` -- outcome counts (masked, sdc, detected, crash, timeout)
- `injections.csv` -- per-injection details (register, bit, instruction, outcome)
- `provenance.json` -- full reproducibility metadata: server version, QEMU commit, toolchain, seed, timing, and your local git commit
- `source/` -- exact copy of the benchmark source files used for this campaign, so results are always traceable to the code that produced them
- `server.log` -- server-side execution log

### provenance.json

Every campaign result includes a `provenance.json` that records everything needed to reproduce the run:

```json
{
    "benchmark": "mmult",
    "arch": "riscv64",
    "injections": 100,
    "seed": 42,
    "fault_type": "register",
    "qemu_version": "8.2.0",
    "toolchain": "riscv64-unknown-linux-gnu-gcc 13.2.0",
    "fim_version": "1.0.0",
    "git_commit": "abc1234",
    "git_branch": "main",
    "git_dirty": false
}
```

Same seed + same source = same results, every time.

## Other Commands

```bash
./upload.sh benchmarks/my_algo          # upload only (no build/run)
./download-results.sh                   # list past results on server
./download-results.sh --all             # download all results
./build.sh benchmarks/my_algo           # local cross-compile (optional)
```

## Project Structure

```
FIM-client/
  config.yaml                  # your server connection
  config.yaml.example          # example config with comments
  campaign.yaml.example        # example batch campaign
  run.sh                       # upload + build + run + download
  status.sh                    # check background jobs, download results
  upload.sh                    # upload benchmark to server
  download-results.sh          # pull results from server
  build.sh                     # local cross-compile (optional)
  sdk/                         # FIM SDK (don't modify)
    include/hfim.h             # fim_init() / fim_exit() header
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
| **SDC** | Silent Data Corruption -- wrong result, undetected |
| **DETECTED** | Benchmark's own error detection caught the fault |
| **CRASH** | Program crashed |
| **TIMEOUT** | Execution exceeded time limit |
