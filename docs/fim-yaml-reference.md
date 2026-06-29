# fim.yaml Reference

`fim.yaml` lives in your benchmark directory and configures how FIM runs it.
Every field is optional except where noted. CLI flags to `run.sh` override the
matching `fim.yaml` value.

## Observable outputs (SDC detection)

How FIM decides whether a fault produced wrong output.

```yaml
observable_outputs:
  comparison: "exact"        # "exact" | "tolerance"
  variables:
    - name: "result"         # variable name - type auto-detected from the ELF
    - name: "total"
    - name: "position"
      tolerance: 0.001       # per-variable, only used with comparison: tolerance
```

- `comparison: exact` - bit-exact match against the golden values.
- `comparison: tolerance` - numeric match within `tolerance` (use for floats,
  where bit-exact is too strict). Set `tolerance` per variable.

Observables must be file-scope `volatile` variables in your `main.c`. Without
an `observable_outputs` block, FIM falls back to comparing raw UART output,
which is less precise.

## Fault target

Which kind of state to corrupt. Default is `register`.

```yaml
fault: register            # or: memory (or a gem5-only target)
```

One campaign injects one fault type. Keys belong to fault families
(register / memory / cache), and FIM rejects a config that mixes keys from
different families - e.g. `fault: register` with a `memory_start` set is an
error. To sweep several fault types, use a
[batch campaign](batch-campaigns.md) with one entry per type.

### Register target

```yaml
fault: register
target_registers:          # a list of register names (or set auto_registers)
  - a0
  - fa0
  - pc                     # pc is allowed explicitly (not a GPR; never autodetected)
bit_width: 64              # 8 | 16 | 32 | 64 (default 32)
```

Or autodetect the registers the ELF actually uses:

```yaml
fault: register
auto_registers: true       # autodetect the GPR pool from the ELF
include_int: true          # default true  - integer GPRs (applies only to autodetect)
include_floats: false      # default false - float registers (applies only to autodetect)
target_registers:          # optional: extras unioned onto the autodetected pool
  - pc
```

`target_registers` is required unless `auto_registers: true` is set. The legacy
`target_registers: auto` string still works but is deprecated in favor of
`auto_registers: true`.

Full register list, the autodetect truth table, `pc` behavior, and the
float-register gotcha: [Register Injection](register-injection.md).

### Memory target

Easiest: name a whole ELF section with `section:` and FIM resolves the
address range from your ELF automatically.

```yaml
fault: memory
section: .bss              # .bss, .data, .rodata, .stack, ...
memory_access_size: 4      # 1 | 2 | 4 | 8 bytes (default 4)
bit_width: 8               # 8 | 16 | 32 | 64 (default 32)
```

`section: .stack` is special-cased for bare-metal C906 ELFs (resolved from the
linker's `__stack_bottom`/`__stack_top` symbols). See
[Memory Injection](memory-injection.md).

Or name a single global/`static` variable - address and size both come from
the ELF symbol table, so you never set the size:

```yaml
fault: memory
target_variable: "target_position"  # global or function-static; size from st_size
memory_access_size: 4
```

Or give an explicit address range (use one targeting mode, not several -
`target_variable` takes precedence over `section`/`memory_start`):

```yaml
fault: memory
memory_start: "0x80001000"  # section name, hex string, or int
memory_end:   "0x80002000"  # must be greater than memory_start
```

Details and the targeting-mode matrix: [Memory Injection](memory-injection.md).

### gem5-only targets

Cache, DRAM, and microarchitecture targets use the same `fault:` key and
run with `--simulator gem5`, e.g. `fault: cache_l1d`. See
[gem5 Targets](gem5-targets.md).

## Fault model

```yaml
fault_model: single_bit_flip   # single_bit_flip | stuck_at_0 | stuck_at_1
```

- `single_bit_flip` - one bit toggles (models a Single Event Upset).
- `stuck_at_0` / `stuck_at_1` - a bit is forced to a fixed value.

## Timing

```yaml
timeout: 120               # fixed max seconds per injection
timeout_factor: 1.5        # used only when timeout is "auto"
checkpoint_locations:      # function name for the simulator snapshot
  - "fim_init"             # (default: main)
```

- A numeric `timeout` is a fixed wall - best for benchmarks with a variable
  runtime (e.g. feeder-driven ones).
- `timeout: auto` derives the wall from the golden run:
  `timeout_factor * golden_execution_time`, floored at 30s. Use only when the
  golden run is deterministic and recorded a golden time.

## Injection timing + window

```yaml
injection_mode: breakpoint   # breakpoint | timer | icount | stepi (default: timer)
```

For random campaigns the fault's location is drawn from the
`[fim_init, fim_exit)` instruction window - the SDK markers you already place
around the code under test. There is no separate window field: instrument the
benchmark, and the window follows.

- `breakpoint` (recommended, feeder-robust): a GDB breakpoint at the drawn PC.
  The CPU stops exactly when it executes that instruction. Reliable for
  serial-feeder benchmarks where instruction counts drift with feeder wall-time.
- `timer` (default): continue for a scaled duration, then interrupt. Fast but
  imprecise about which instruction is hit.
- `icount`: a TCG plugin pauses at the Nth committed instruction. Deterministic,
  but fragile for feeder benchmarks (the count moves with feeder timing).
- `stepi`: single-step to the target. Deterministic but slow over the network.

### Hit-instance (loop-iteration spread)

When the code under test is a loop inside the window, a plain breakpoint fires
on the FIRST time the PC executes - always iteration 1. To spread injections
across the loop's iterations, breakpoint mode draws a random **hit-instance**
`K` per injection from `[0, window_hit_count)` and arms the breakpoint with a
GDB ignore-count of `K`, so it fires on the `(K+1)`th hit.

- `window_hit_count` is the loop trip count, harvested from the golden run's
  `trace.json`. You do not set it.
- When the golden run did not measure it (`window_hit_count` absent or `0`),
  `K` degrades to `0` (first hit) - i.e. exactly the legacy behaviour. No error.
- `K` is recorded per injection in the faultlist / `injections.csv`
  (`hit_instance` column) so a campaign replays deterministically. Old
  faultlists with no such column load as `K=0`.

## Serial feeder (external simulator)

```yaml
serial_pty: true
serial_feeder_cmd: "python3 {benchmark_dir}/feeder.py --pty {pty} --trajectory-log {injection_outdir}/trajectory.csv"
```

Placeholders and per-fault output files: [Serial Feeder](serial-feeder.md).

## Result saving

```yaml
results:
  save_per_injection: true     # write a per-injection dir (needed for feeder artefacts)
  save_uart_output: true       # capture UART per injection
  save_observable_state: true  # dump observable values per injection
  save_register_dump: false    # dump all registers per injection
  cleanup_injections: false    # delete injections/ after the campaign
```

## Quick reference: valid values

| Field | Allowed values |
| --- | --- |
| `comparison` | `exact`, `tolerance` |
| `fault_model` | `single_bit_flip`, `stuck_at_0`, `stuck_at_1` |
| `bit_width` | `8`, `16`, `32`, `64` |
| `injection_mode` | `breakpoint`, `timer`, `icount`, `stepi` |
| `memory_access_size` | `1`, `2`, `4`, `8` |
| `target_variable` | any global/`static` data symbol name (memory faults only) |
| `fault` | `register`, `memory`, `cache_l1d`, `cache_l1i`, `cache_l2`, `dram`, ... (gem5 targets in [gem5 Targets](gem5-targets.md)) |

## See also

- [Writing Benchmarks](writing-benchmarks.md)
- [Register Injection](register-injection.md)
- [Memory Injection](memory-injection.md)
- [Serial Feeder](serial-feeder.md)
