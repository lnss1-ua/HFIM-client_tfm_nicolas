# Results

`run.sh --follow` downloads results automatically when a campaign finishes. They
land in `results/<campaign>/` on your machine. For fire-and-forget runs (the
default), pull them by hand with `download.sh` once `status.sh` shows the
campaign done.

## Outcome classes

Every injection is classified into exactly one outcome:

| Outcome | Meaning |
| --- | --- |
| **MASKED** | The fault had no observable effect on the result. |
| **SDC** | Silent Data Corruption - wrong result, not detected by the program. |
| **DETECTED** | The benchmark's own error-detection logic caught the fault. |
| **CRASH** | The program crashed (illegal instruction, bad access, etc.). |
| **TIMEOUT** | Execution exceeded the time limit (usually a fault-induced hang). |

A healthy campaign on real arithmetic typically shows a mix dominated by SDC,
with some TIMEOUT (faults that derail control flow into a hang) and MASKED
(faults in idle state). All-MASKED usually means you targeted the wrong
registers - see [Register Injection](register-injection.md). All-TIMEOUT for a
feeder-driven benchmark usually means the feeder is not running - see
[Serial Feeder](serial-feeder.md).

## What you get per campaign

```
results/<campaign>/
  results.txt          # human-readable summary (outcome table, per-register breakdown)
  injections.csv       # one row per injection (target, bit, outcome, ...)
  report.tsv           # tab-separated report
  metadata.json        # campaign parameters
  provenance.json      # what was run, with what tooling
  faultlist.json       # the generated fault list (reproducible from the seed)
  server.log           # server-side log for this run
  source/              # the benchmark source as it was run
    build/
      <bench>_<arch>.elf  # the exact binary the campaign injected into
  injections/
    0001/
      output.txt       # captured UART output
      trajectory.csv   # per-fault artefact, if your feeder wrote one
    0002/
    ...
```

The summary download (no `--full`) brings down everything above except the
`injections/` subtree. The captured `.elf` ships inside `source/build/` so the
exact binary the campaign injected into travels with its results.

Per-injection files (like a feeder's `trajectory.csv`) sit in
`injections/NNNN/`, keyed by the same index used in `injections.csv`, so each
artefact is unambiguously tied to its fault.

## download.sh

```bash
./download.sh <id-or-prefix>          # download one campaign (summary only)
./download.sh --latest                # download the most recent completed campaign
./download.sh <id> --full             # also pull the per-injection injections/ tree
./download.sh <id> --with-golden      # also pull this campaign's golden reference
./download.sh <id> --purge            # delete the server copy after a good fetch

./download.sh --list-golden           # list golden dirs on the server
./download.sh --golden <name>         # download one golden dir
./download.sh --golden-all            # download every golden dir
```

You name WHICH campaign to pull: an exact id, a unique prefix of one, or
`--latest`. An ambiguous prefix is refused (the candidates are listed) so you
never download the wrong run. Run `status.sh` to see ids.

Campaign results go to `results/<campaign>/`; golden runs go to
`golden/<name>/`. Use `--with-golden` when you want to diff a per-injection
artefact (e.g. `injections/0001/trajectory.csv`) against the golden baseline
(`golden/.../trajectory.csv`) - both trees come down together. The server copy
is kept by default; pass `--purge` to remove it after a successful fetch.

## See also

- [Running Campaigns](running-campaigns.md)
- [Serial Feeder](serial-feeder.md)
