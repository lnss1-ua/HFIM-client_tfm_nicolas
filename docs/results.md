# Results

`run.sh` downloads results automatically when a campaign finishes. They land in
`results/<campaign>/` on your machine. You can also pull past runs by hand with
`download-results.sh`.

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
  injections/
    0001/
      output.txt       # captured UART output
      trajectory.csv   # per-fault artefact, if your feeder wrote one
    0002/
    ...
```

Per-injection files (like a feeder's `trajectory.csv`) sit in
`injections/NNNN/`, keyed by the same index used in `injections.csv`, so each
artefact is unambiguously tied to its fault.

## download-results.sh

```bash
./download-results.sh                          # list past results on the server
./download-results.sh <campaign>               # download one campaign
./download-results.sh <campaign> --with-golden # campaign + its paired golden run
./download-results.sh --all                    # download every campaign

./download-results.sh --list-golden            # list golden dirs on the server
./download-results.sh --golden <name>          # download one golden dir
./download-results.sh --golden-all             # download every golden dir
```

Campaign results go to `results/<campaign>/`; golden runs go to
`golden/<name>/`. Use `--with-golden` when you want to diff a per-injection
artefact (e.g. `injections/0001/trajectory.csv`) against the golden baseline
(`golden/.../trajectory.csv`) - both trees come down together.

## See also

- [Running Campaigns](running-campaigns.md)
- [Serial Feeder](serial-feeder.md)
