// Sky Go (x86_64 under Rosetta, Electron 22) corrupts its malloc free lists. When macOS
// signals memory pressure, libdispatch calls malloc_memory_event_handler(), which walks those
// lists in szone_pressure_relief() and segfaults.
//
// This dylib interposes the two entry points and turns them into no-ops, but only in the
// Sky Go main process. Every other process that loads it passes the calls through untouched.
// It does not repair the corruption: the app can still fail later elsewhere, and it stops
// handing cached memory back to the OS under pressure.
//
// Log: ~/Library/Logs/skygo-nopressure.log

#include <fcntl.h>
#include <malloc/malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

extern void malloc_memory_event_handler(unsigned long event);

// Same definition as <mach-o/dyld-interposing.h>, which the Command Line Tools SDK does not ship.
#define DYLD_INTERPOSE(_replacement, _replacee)                                              \
    __attribute__((used)) static struct { const void *replacement; const void *replacee; }   \
        _interpose_##_replacee __attribute__((section("__DATA,__interpose"))) = {            \
            (const void *)(unsigned long)&_replacement, (const void *)(unsigned long)&_replacee};

static int g_active;
static int g_log = -1;
static volatile unsigned long g_swallowed;

static void note(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

static void note(const char *fmt, ...)
{
    if (g_log < 0) return;
    char line[256];
    time_t now = time(NULL);
    struct tm tm;
    localtime_r(&now, &tm);
    int n = (int)strftime(line, sizeof line, "%F %T ", &tm);
    __builtin_va_list ap;
    __builtin_va_start(ap, fmt);
    n += vsnprintf(line + n, sizeof line - (size_t)n - 1, fmt, ap);
    __builtin_va_end(ap);
    line[n++] = '\n';
    write(g_log, line, (size_t)n);
}

// Log the first few events, then every 50th, so a long session does not flood the file.
static int should_log(void)
{
    unsigned long c = __sync_add_and_fetch(&g_swallowed, 1);
    return c <= 10 || c % 50 == 0;
}

static void shim_memory_event_handler(unsigned long event)
{
    if (!g_active) {
        malloc_memory_event_handler(event);
        return;
    }
    if (should_log()) note("swallowed malloc_memory_event_handler(0x%lx) [#%lu]", event, g_swallowed);
}

static size_t shim_pressure_relief(malloc_zone_t *zone, size_t goal)
{
    if (!g_active) return malloc_zone_pressure_relief(zone, goal);
    if (should_log()) note("swallowed malloc_zone_pressure_relief(%p, %zu) [#%lu]", (void *)zone, goal, g_swallowed);
    return 0;
}

DYLD_INTERPOSE(shim_memory_event_handler, malloc_memory_event_handler)
DYLD_INTERPOSE(shim_pressure_relief, malloc_zone_pressure_relief)

__attribute__((constructor)) static void shim_init(void)
{
    const char *name = getprogname();
    g_active = (name && strcmp(name, "Sky Go") == 0) || getenv("SKYGO_SHIM_FORCE") != NULL;

    const char *home = getenv("HOME");
    char path[1024];
    if (home && snprintf(path, sizeof path, "%s/Library/Logs/skygo-nopressure.log", home) < (int)sizeof path)
        g_log = open(path, O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0600);

    note("loaded in %s pid=%d active=%d", name ? name : "?", getpid(), g_active);

    // Do not leak the injection into children (helpers, updater): only the main process needs it.
    if (g_active) unsetenv("DYLD_INSERT_LIBRARIES");
}
