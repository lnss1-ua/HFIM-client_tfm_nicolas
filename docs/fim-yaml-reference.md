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
target_types:
  - register               # or: memory (or a gem5-only target)
```

### Register target

```yaml
target_registers:          # REQUIRED when target is register
  - a0
  - fa0
bit_width: 64              # 8 | 16 | 32 | 64 (default 32)
```

Full register list and the float-register gotcha:
[Register Injection](register-injection.md).

### Memory target

```yaml
target_types:
  - memory
memory_start: ".bss"       # REQUIRED - section name, hex string, or int
memory_end: ".bss"         # REQUIRED
memory_access_size: 4      # 1 | 2 | 4 | 8 bytes (default 4)
bit_width: 8               # 8 | 16 | 32 | 64 (default 32)
```

Details and section targeting: [Memory Injection](memory-injection.md).

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
| `memory_access_size` | `1`, `2`, `4`, `8` |
| `target_types` | `register`, `memory` (+ gem5-only targets) |

## See also

- [Writing Benchmarks](writing-benchmarks.md)
- [Register Injection](register-injection.md)
- [Memory Injection](memory-injection.md)
- [Serial Feeder](serial-feeder.md)
