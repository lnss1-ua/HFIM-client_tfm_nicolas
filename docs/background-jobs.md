# Background Jobs

A campaign normally runs in the foreground: `run.sh` blocks until every
injection is done, then downloads the results. For long campaigns you can
detach the run, let the server work, and collect results later.

## Run in the background

Add `--background` to any `run.sh` invocation:

```bash
./run.sh benchmarks/mmult -n 1000 --background
```

The command returns immediately. The campaign keeps running on the server under
your user. Nothing is downloaded yet.

## Check status

`status.sh` lists every job you have on the server and its state (running,
completed, failed):

```bash
./status.sh
```

When jobs have finished, pull their results:

```bash
./status.sh --download
```

`--download` copies back every completed campaign you do not already have
locally, into `results/<campaign>/`, and clears it from the server. Jobs still
running are skipped, so it is safe to run repeatedly while you wait.

## Batch campaigns

Run several campaigns from one YAML file instead of invoking `run.sh` per
benchmark:

```bash
./run.sh --batch campaign.yaml
./run.sh --batch campaign.yaml --background
```

The batch file lists multiple campaigns that share a `defaults:` block; each
entry can override any default. See `campaign.yaml.example` for the full set of
fields. `run.sh` uploads every benchmark the file references before starting.

## See also

- [Running Campaigns](running-campaigns.md) - the foreground workflow and flags
- [Notifications](notifications.md) - get pinged when a background run finishes
- [Results](results.md) - what `--download` brings back
