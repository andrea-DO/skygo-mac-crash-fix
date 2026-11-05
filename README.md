# Sky Go Mac crash fix (unofficial)

Stops the **Sky Go desktop app for macOS** from quitting with *"Sky Go quit unexpectedly"* on Apple Silicon Macs.

It does not modify Sky Go, does not touch DRM or the video stream, and can be removed at any time.
Not affiliated with or endorsed by Sky. 🇮🇹 [Italiano più sotto](#italiano).
Questions and reports: [thread on the Sky Community forum](https://helpforum.sky.com/t5/Sky-Go/Sky-Go-for-Mac-quits-unexpectedly-EXC-BAD-ACCESS-in-szone-pressure-relief-unofficial-workaround/m-p/5411240) or a GitHub issue.

## Is this your crash?

Open the crash report (Console → Crash Reports → *Sky Go*, or `~/Library/Logs/DiagnosticReports/Sky Go-*.ips`).
It is this bug if you see all of these:

- `Code Type: X86-64 (Translated)`
- `Exception Type: EXC_BAD_ACCESS (SIGSEGV)` with `KERN_INVALID_ADDRESS`
- `Triggered by Thread: …, Dispatch Queue: com.apple.libdispatch-manager`
- in that thread's stack: `szone_pressure_relief`, `malloc_zone_pressure_relief`, `malloc_memory_event_handler`

The same signature has been reported on the Sky Community forum with Sky Go 26.1.3 to 26.3.3 on macOS 26 and 27.
It is not the crash *at launch* that many Macs, Intel ones included, hit with 26.3.2 around 24 October 2026:
that one has a different stack (`NSButtonCell`) and this fix does not address it.
Reinstalling Sky Go, clearing its data or reinstalling Rosetta does not help.

## What is going on

Sky Go is an Intel-only Electron app that runs through Rosetta 2. Something inside it corrupts its own memory
allocator. Nothing happens until macOS signals memory pressure: the system allocator then walks its free lists to
hand memory back, hits the corrupted pointer and the app crashes. That is why it dies at random moments, from a few
seconds to an hour after launch, more often when the Mac is short of memory.

## What this fix does

- **`src/nopressure.c`**: a small library injected into the Sky Go main process at launch. In that process only,
  it turns `malloc_memory_event_handler` and `malloc_zone_pressure_relief` into no-ops, so the routine that crashes
  never runs. Every other process passes the calls through unchanged.
- **`skygo-launch.sh`**: starts Sky Go with the library through `open --env DYLD_INSERT_LIBRARIES=…`. This works
  because Sky Go's own code signature allows it (`allow-dyld-environment-variables`, `disable-library-validation`).
  The app bundle and its signature stay untouched, so Sky Go updates keep working.
- It also passes Chromium's `--disable-layer-tree-host-memory-pressure`, which stops the page from going grey after
  a memory-pressure event.
- **`install.sh`**: builds the library and creates **Sky Go Fix.app** in `~/Applications`, which you open instead of
  the normal Sky Go icon.

Results on one Mac (Apple M4 Pro, 24 GB): before, 6 crashes in about 5 hours. Since then, three weeks of use,
16 launches, 35 memory-pressure events intercepted and no Sky Go crash, including after Sky Go auto-updated from
26.2.4 to 26.3.3 and macOS from 27.0.1 to 27.2.

## Requirements

- A Mac with Apple Silicon, with Sky Go installed in `/Applications` or `~/Applications` (Rosetta 2 is already
  needed by Sky Go).
- Xcode Command Line Tools, to compile the library: `xcode-select --install`.

## Install

In Terminal:

```sh
git clone https://github.com/andrea-DO/skygo-mac-crash-fix.git
cd skygo-mac-crash-fix
./install.sh
```

No git? Use *Code → Download ZIP* on GitHub, unzip, then `cd` into the folder and run `./install.sh`.

Then **always open "Sky Go Fix"** (in `~/Applications` or Spotlight). Put it in the Dock and remove the old Sky Go
icon from the Dock: the original icon still starts Sky Go *without* the fix.

## Check that it works

```sh
cat ~/Library/Logs/skygo-nopressure.log
```

- `loaded in Sky Go pid=… active=1` appears at each launch through Sky Go Fix.
- `swallowed malloc_memory_event_handler(0x…)` appears each time macOS signalled memory pressure: without the fix,
  that is when Sky Go would have crashed.

## Uninstall

```sh
./uninstall.sh
```

This removes Sky Go Fix.app, the installed files and the log. Sky Go itself is not touched.

## Limitations

- It works around the crash; it does not repair whatever corrupts Sky Go's memory. The real fix has to come from Sky.
  If you are affected, send your `.ips` crash reports to Sky support (UK users on the forum use apps@sky.uk).
- While it runs, Sky Go no longer returns cached memory to macOS when asked.
- If the Mac is very short of memory (tens of GB in swap), Sky Go can still pause for 30–60 seconds. That is the
  system paging, not a crash; closing heavy apps helps.
- Only the Sky Go main process is covered, because every crash observed was there.
- Sky Go needs Rosetta 2, which Apple has announced will be limited after macOS 27.

## Troubleshooting

- **The fix does not load**: quit Sky Go completely (⌘Q) before opening Sky Go Fix. An instance that is already
  running ignores the launch settings; Sky Go Fix then just brings it to the front.
- **Build fails with `tapi error … unknown architecture`**: the Command Line Tools SDK is out of step with the linker.
  `build.sh` retries with Xcode's SDK if Xcode is installed; otherwise reinstall the Command Line Tools, or point
  `SDKROOT` at a working macOS SDK.
- **Grey or frozen window**: while it happens, run `tools/capture-gray.sh`. It saves thread samples and memory
  state to `~/Library/Logs/SkyGoFix/diagnostics/`. Review them before sharing, because they describe your Mac.

## For developers

```sh
./build.sh
SKYGO_SHIM_FORCE=1 DYLD_INSERT_LIBRARIES="$PWD/build/libskygo_nopressure.dylib" ./build/probe --direct
cat ~/Library/Logs/skygo-nopressure.log   # expect two "swallowed" lines from the probe
```

`build/probe` is x86_64-only, so it runs under Rosetta like Sky Go. Run it directly: `arch -x86_64` is a protected
system binary and drops `DYLD_*` variables. `SKYGO_FLAGS` overrides the Chromium switches;
`SKYGO_FIX_CHROMIUM_LOG=1` writes Chromium's log to `~/Library/Logs/skygo-chromium.log`.

---

## Italiano

**Cos'è**: una correzione non ufficiale per l'app Sky Go su Mac con chip Apple che si chiude da sola
("Sky Go si è chiuso inaspettatamente"). Non modifica Sky Go, non tocca il DRM e si rimuove quando vuoi.

**La causa**: Sky Go (app Intel che gira con Rosetta) corrompe la propria memoria. Quando macOS segnala che la RAM
scarseggia, il sistema prova a recuperarne, incontra il dato corrotto e l'app va in crash. Reinstallare non serve.

**Cosa fa**: all'avvio carica nel processo di Sky Go una piccola libreria che disattiva quel recupero di memoria,
solo per Sky Go, più un'opzione di Chromium che evita la pagina grigia.

**Installazione** (serve `xcode-select --install`):

```sh
git clone https://github.com/andrea-DO/skygo-mac-crash-fix.git
cd skygo-mac-crash-fix
./install.sh
```

Da quel momento apri sempre **"Sky Go Fix"** da `~/Applications` o da Spotlight, non l'icona normale di Sky Go.
Per verificare che sia attivo: `cat ~/Library/Logs/skygo-nopressure.log`. Per toglierlo: `./uninstall.sh`.

---

Sky and Sky Go are trademarks of their respective owners. This project is provided as is, under the
[MIT License](LICENSE), without any warranty.
