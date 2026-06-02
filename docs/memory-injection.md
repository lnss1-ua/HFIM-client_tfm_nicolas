# Memory Injection

Memory injection flips a bit in a byte of program memory during the fault
window, instead of in a register. Select it with `fault: memory` in `fim.yaml`
(or `--fault memory` on the command line).

## By section (easiest)

Point `section:` at a named ELF section and FIM injects anywhere inside it,
resolving the address range from your ELF automatically:

```yaml
fault: memory
section: .bss      # your volatile outputs usually live in .bss or .data
```

`section:` accepts any ELF section name (`.bss`, `.data`, `.rodata`, ...). One
section per campaign; to sweep several, use a
[batch campaign](background-jobs.md) with one entry per section.

## By explicit address range

When you want a specific span rather than a whole section, give the two ends.
Each accepts an ELF section name, a hex string, or an integer:

```yaml
fault: memory
memory_start: "0x80001000"
memory_end:   "0x80002000"
```

`memory_end` must be greater than `memory_start`. Use either `section:` or the
`memory_start`/`memory_end` pair, not both.

## Access size

How many bytes the injector reads-modifies-writes around the chosen address:

```yaml
memory_access_size: 4     # 1 | 2 | 4 | 8 bytes
```

## Bit width and fault model

```yaml
bit_width: 8                    # 8 | 16 | 32 | 64
fault_model: single_bit_flip    # single_bit_flip | stuck_at_0 | stuck_at_1
```

For memory targets, keep `bit_width` consistent with `memory_access_size`
(a 1-byte access can only flip bits 0-7).

## Full example

```yaml
observable_outputs:
  comparison: "exact"
  variables:
    - name: "result"

fault: memory
section: .bss
memory_access_size: 4
bit_width: 32
fault_model: single_bit_flip
```

Run it:

```bash
./run.sh benchmarks/my_algo -n 50 --fault memory
```

## See also

- [Register Injection](register-injection.md)
- [fim.yaml Reference](fim-yaml-reference.md)
