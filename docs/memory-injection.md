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
[batch campaign](batch-campaigns.md) with one entry per section.

### The stack (`section: .stack`)

```yaml
fault: memory
section: .stack
```

Bare-metal C906 ELFs do not emit a real `.stack` section header - the stack is
reserved by the linker between `__stack_bottom` and `__stack_top`. FIM resolves
`.stack` to that range from the linker symbols automatically (and prefers a real
`.stack` section header if one exists). Recognised symbol pairs:
`__stack_bottom`/`__stack_top`, `_stack_bottom`/`_stack_top`,
`__stack_start`/`__stack_end`, `_estack_bottom`/`_estack`. If your ELF has none
of these and no `.stack` header, give a numeric `memory_start`/`memory_end` for
the stack region instead.

## By variable name

Point `target_variable:` at the name of a global or `static` variable and FIM
injects anywhere inside that variable's bytes. The address and size both come
from the ELF symbol table, so you never specify the size yourself:

```yaml
fault: memory
target_variable: "target_position"   # a global or function-static variable
memory_access_size: 4
```

FIM reads the variable's `st_value` (address) and `st_size` (byte extent) from
the symbol table - the same data `readelf -s` / `objdump -t` print. `st_size` is
the full extent, so an array like `float target_position[4]` resolves to its
whole 16-byte span, not one element. No DWARF/`-g` is required.

Requirements:

- The variable must have **static storage duration** - a file-scope global or a
  function-`static`. A plain stack local has no fixed address and cannot be
  targeted by name (use `section: .stack` or an explicit range instead).
- It must be a **data** symbol (`STT_OBJECT`). Pointing `target_variable` at a
  function name is rejected - inject code with a gem5 code target instead.
- It must have non-zero size in the symbol table.

`target_variable` replaces `section:` and `memory_start`/`memory_end`; give one
targeting mode, not several. When `target_variable` is set it takes precedence.

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

## Choosing a targeting mode

| Mode | Key(s) | Address from | Size from | Use when |
|------|--------|--------------|-----------|----------|
| Section | `section:` | ELF section header (or linker symbols for `.stack`) | whole section | you want to hit anywhere in `.bss`/`.data`/stack |
| Variable | `target_variable:` | symbol `st_value` | symbol `st_size` | you want exactly one named global/static (correct size, no manual sizing) |
| Range | `memory_start:` / `memory_end:` | you | you | you need a specific span the other two modes can't express |

All three feed the same byte-granular injector; they differ only in how the
target byte range is resolved. Pick one per campaign.

## See also

- [Register Injection](register-injection.md)
- [fim.yaml Reference](fim-yaml-reference.md)
