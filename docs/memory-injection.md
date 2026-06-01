# Memory Injection

Memory injection flips a bit in a byte of program memory during the fault
window, instead of in a register. Enable it with `--fault memory` or in
`fim.yaml`.

## Targeting a range or a section

You specify the address span with `memory_start` and `memory_end`. Both accept
three forms:

- an **ELF section name** (starts with `.`), e.g. `.bss`, `.data`
- a **hex string**, e.g. `"0x80001000"`
- an **integer** address

### By section (easiest)

Inject anywhere inside a named section. The client resolves the section's
address range from your ELF automatically:

```yaml
target_types:
  - memory
memory_start: ".bss"     # your volatile outputs usually live in .bss or .data
memory_end: ".bss"
```

### By explicit address range

```yaml
target_types:
  - memory
memory_start: "0x80001000"
memory_end: "0x80002000"
```

`memory_end` must be greater than `memory_start`.

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

target_types:
  - memory
memory_start: ".bss"
memory_end: ".bss"
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
