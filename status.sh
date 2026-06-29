#!/usr/bin/env bash
# Show campaign status on the FIM server. Status only -- to fetch results use
# ./download.sh.
#
# The server lists campaigns newest-first; this client reverses them so the
# most recent prints at the BOTTOM (closest to your prompt) and can trim the
# view to the last N with --tail. Reordering is purely cosmetic and never
# touches the server-side ledger.
#
# Usage:
#   ./status.sh              # list campaigns (most recent at the bottom)
#   ./status.sh --tail 15    # show only the 15 most recent
#   ./status.sh --watch      # poll every 5s until all campaigns are terminal
#   ./status.sh --watch 10   # poll every 10s
#   ./status.sh --watch 10 --tail 15
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

read_config() {
    python3 -c "import yaml; print(yaml.safe_load(open('$SCRIPT_DIR/config.yaml'))['$1'])" 2>/dev/null \
        || grep "^$1:" "$SCRIPT_DIR/config.yaml" | awk '{print $2}'
}

USER=$(read_config user)
SERVER=$(read_config server)
SSH_KEY=$(read_config ssh_key)
SSH_KEY="${SSH_KEY/#\~/$HOME}"

REMOTE="fim-${USER}@${SERVER}"
SSH_OPTS="-o StrictHostKeyChecking=no"
[ -f "$SSH_KEY" ] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

WATCH=false
INTERVAL=5
TAIL=0   # 0 = show all
while [ $# -gt 0 ]; do
    case "$1" in
        --watch)
            WATCH=true
            # optional numeric interval immediately after --watch
            if [ -n "${2:-}" ] && [ "${2#-}" = "$2" ]; then
                INTERVAL="$2"; shift
            fi
            ;;
        --tail)
            TAIL="${2:-0}"; shift
            ;;
        *)
            echo "Unknown option: $1" >&2; exit 2
            ;;
    esac
    shift
done

# Reorder the server's newest-first listing into newest-last and, if --tail N
# was given, keep only the N most recent campaigns. A campaign is a block: the
# "  [icon] cid [status]" line plus an optional indented outcome line beneath
# it, so we reverse by block (never by raw line) to keep the two together. Any
# leading header/"No campaigns." text passes through unchanged. If the output
# does not look like the expected table, it is printed verbatim.
format_jobs() {
    printf '%s\n' "$1" | TAIL="$TAIL" python3 -c '
import os, sys
lines = sys.stdin.read().splitlines()
tail = int(os.environ.get("TAIL", "0") or "0")
header, blocks = [], []
for ln in lines:
    if ln.startswith("  [") and "]" in ln:        # start of a campaign block
        blocks.append([ln])
    elif blocks and (ln.startswith("    ") or ln.strip() == ""):
        blocks[-1].append(ln)                      # outcome / spacer for this block
    else:
        header.append(ln)                          # pre-table header text
if not blocks:
    print("\n".join(lines)); sys.exit(0)
blocks.reverse()                                   # newest now last
if tail > 0:
    blocks = blocks[-tail:]
out = [h for h in header if h.strip() != ""]
for b in blocks:
    out.extend(l for l in b if l.strip() != "")
print("\n".join(out))
'
}

if [ "$WATCH" != true ]; then
    OUT=$(ssh $SSH_OPTS "$REMOTE" "fim-run jobs")
    format_jobs "$OUT"
    exit 0
fi

# --watch: redraw the list every INTERVAL seconds. Stop once no campaign is in a
# non-terminal state (running/queued/cancelling). The server owns the campaign
# lifecycle, so this is a pure read loop -- closing it never affects the run.
while true; do
    OUT=$(ssh $SSH_OPTS "$REMOTE" "fim-run jobs")
    clear
    format_jobs "$OUT"
    echo ""
    echo "(watching every ${INTERVAL}s -- Ctrl-C to stop)"
    if ! printf '%s\n' "$OUT" | grep -qE '\[(run |que |canc)\]|\[running\]|\[queued\]|\[cancelling\]'; then
        echo ""
        echo "All campaigns terminal."
        exit 0
    fi
    sleep "$INTERVAL"
done
