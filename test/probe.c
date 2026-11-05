// Minimal x86_64 process used to exercise the shim. It sits in dispatch_main() so libdispatch's
// own memory-pressure source (the same one that crashes Sky Go) is live and can be triggered with
// `memory_pressure -S -l warn`.
//   probe            wait for pressure events
//   probe --direct   also call the two entry points straight from this binary, then keep waiting
//   probe --watch    also print every pressure event delivered to a source owned by this binary,
//                    to tell "no event arrived" apart from "event arrived but was not intercepted"
#include <dispatch/dispatch.h>
#include <malloc/malloc.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

extern void malloc_memory_event_handler(unsigned long event);

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "--direct") == 0) {
        malloc_memory_event_handler(0x2);
        malloc_zone_pressure_relief(NULL, 0);
    }
    if (argc > 1 && strcmp(argv[1], "--watch") == 0) {
        dispatch_source_t src = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
            DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
            dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
        dispatch_source_set_event_handler(src, ^{
            printf("%ld pressure event 0x%lx\n", (long)time(NULL), dispatch_source_get_data(src));
            fflush(stdout);
        });
        dispatch_resume(src);
    }
    printf("probe ready pid=%d\n", getpid());
    fflush(stdout);
    dispatch_main();
}
