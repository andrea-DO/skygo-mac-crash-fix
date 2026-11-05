#!/bin/bash
# Run while Sky Go shows a grey window, BEFORE quitting it. Collects what is needed to tell a
# hang/dead player thread (heap corruption surfacing elsewhere) from a Mac starved of memory:
# per-process state, all-thread samples of the main process and every helper, memory snapshot.
# Output: ~/Library/Logs/SkyGoFix/diagnostics/<timestamp>/ (override the base with SKYGO_DIAG_DIR).
# The samples contain process and memory details of your Mac: review them before sharing.
set -u
OUT="${SKYGO_DIAG_DIR:-$HOME/Library/Logs/SkyGoFix/diagnostics}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
MAIN=$(pgrep -x "Sky Go" | head -1)
[ -n "$MAIN" ] || { echo "Sky Go is not running" >&2; exit 1; }

{
    date; echo
    echo "== processes (pid, start, uptime, %cpu, rss KB, state, command)"
    for p in $(pgrep -f "Sky Go.app/Contents"); do
        ps -o pid=,lstart=,etime=,%cpu=,rss=,state=,args= -p "$p" | cut -c1-200
    done
    echo; echo "== shim log (tail)"; tail -20 ~/Library/Logs/skygo-nopressure.log
    echo; echo "== memory"
    sysctl vm.swapusage kern.memorystatus_vm_pressure_level
    top -l 1 -n 0 | grep -E "PhysMem|CPU usage|Processes"
    echo; echo "== crash reports for Sky Go (newest 3)"
    ls -lt ~/Library/Logs/DiagnosticReports | grep -i "sky go" | head -3
} > "$OUT/summary.txt" 2>&1

sample "$MAIN" 5 -file "$OUT/main.sample.txt" >/dev/null 2>&1 &
for p in $(pgrep -f "Sky Go Helper"); do
    t=$(ps -o args= -p "$p" | grep -o -- '--type=[a-z-]*' | head -1 | cut -d= -f2)
    sample "$p" 3 -file "$OUT/helper-${t:-unknown}-$p.sample.txt" >/dev/null 2>&1 &
done
vmmap -summary "$MAIN" > "$OUT/main.vmmap.txt" 2>&1
wait
echo "saved in $OUT"
