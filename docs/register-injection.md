# Register Injection

Register injection flips bits in CPU registers during the fault window. It is
the default target, so `--fault register` is implied unless you say otherwise.

## The default register set (and why it can hide bugs)

If you do **not** set `target_registers`, FIM uses an integer-only default set.

**RISC-V64 default:** `a0`-`a7`, `s0`-`s11`, `t0`-`t6` (general-purpose only,
no float registers).

This matters: **for float-heavy code, the default set will report mostly
MASKED.** A PID controller, a DSP kernel, or anything doing real arithmetic
keeps its live values in the float registers (`fa*`, `fs*`, `ft*`). If you only
inject into integer registers, ~95% of faults land in idle registers and look
harmless - you miss the real SDCs. Override `target_registers` to include the
float ABI when your computation is floating-point.

## Selecting registers

List ABI names (recommended) or raw register numbers in `fim.yaml`:

```yaml
target_registers:
  # integer ABI - control flow, loop counters, addresses, integer math
  - a0
  - a1
  - s0
  - t0
  # float ABI - where floating-point math actually lives
  - fa0
  - fa1
  - fs0
  - ft0
```

## Valid RISC-V64 register names

**Integer (x1-x31; `x0` is hardwired zero and cannot be injected):**

| ABI name | x-number | Role |
| --- | --- | --- |
| `ra` | x1 | return address |
| `sp` | x2 | stack pointer |
| `gp` / `tp` | x3 / x4 | global / thread pointer |
| `t0`-`t2` | x5-x7 | temporaries |
| `s0`/`fp`, `s1` | x8, x9 | saved / frame pointer |
| `a0`-`a7` | x10-x17 | function args / return values |
| `s2`-`s11` | x18-x27 | saved registers |
| `t3`-`t6` | x28-x31 | temporaries |

**Float (f0-f31, with the D extension these are 64-bit doubles):**

| ABI name | f-number | Role |
| --- | --- | --- |
| `ft0`-`ft7` | f0-f7 | FP temporaries |
| `fs0`, `fs1` | f8, f9 | FP saved |
| `fa0`-`fa7` | f10-f17 | FP args / return values |
| `fs2`-`fs11` | f18-f27 | FP saved |
| `ft8`-`ft11` | f28-f31 | FP temporaries |

You may use the alias (`a0`) or the raw number (`x10` / `f10`) interchangeably.

**AArch64:** valid registers are `x0`-`x30` and `v0`-`v31` (`d0`-`d31` alias the
64-bit view); default set is `x0`-`x15`.

`bit_width` and `fault_model` apply here too - see the
[fim.yaml Reference](fim-yaml-reference.md).

## See also

- [Memory Injection](memory-injection.md)
- [fim.yaml Reference](fim-yaml-reference.md)
