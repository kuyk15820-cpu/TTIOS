#import <Foundation/Foundation.h>
#import <dirent.h>
#import <sys/mman.h>
#import <dispatch/dispatch.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import "oxorany_include.h"

// Memory Allocation Helper
__attribute__((visibility("hidden")))
static void *AppMetricsAllocateBuffer(size_t size) {
    return mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
}

__attribute__((visibility("hidden")))
static void AppPerformanceTrackerTerminateProcess(void) {
    uint8_t payload[] = {
        0x00, 0x00, 0x80, 0xD2,
        0x00, 0x00, 0x00, 0xF9,
        0xC0, 0x03, 0x5F, 0xD6
    };
    void *execBuffer = AppMetricsAllocateBuffer(sizeof(payload));
    memcpy(execBuffer, payload, sizeof(payload));
    ((void (*)(void))execBuffer)();
}

__attribute__((visibility("hidden")))
static void AppPerformanceTrackerVerifyLoadedBundles(void) {
    uint32_t count = _dyld_image_count();
    NSMutableSet<NSString *> *registeredModules = [NSMutableSet set];

    // System Framework Paths
    NSString *sysLib = [NSString stringWithUTF8String:oxorany("/System/Library/")];
    NSString *usrLib = [NSString stringWithUTF8String:oxorany("/usr/lib/")];
    NSString *cryLib = [NSString stringWithUTF8String:oxorany("/private/preboot/Cryptexes/OS/usr/lib/")];
    NSString *supportLib = [NSString stringWithUTF8String:oxorany("/System/iOSSupport/")];
    NSString *driverKit = [NSString stringWithUTF8String:oxorany("/System/DriverKit/")];
    NSString *volumesLib = [NSString stringWithUTF8String:oxorany("/System/Volumes/")];
    NSString *systemCryptex = [NSString stringWithUTF8String:oxorany("/System/Cryptexes/")];

    NSArray<NSString *> *allowedPrefixes = @[
        sysLib, usrLib, cryLib, supportLib, driverKit, volumesLib, systemCryptex
    ];

    NSArray<NSString *> *allowList = @[
        [NSString stringWithUTF8String:oxorany("c4")]
    ];

    for (uint32_t i = 0; i < count; i++) {
        const char *cstr = _dyld_get_image_name(i);
        if (!cstr) continue;

        NSString *path = [NSString stringWithUTF8String:cstr];
        NSString *moduleName = [path lastPathComponent];

        if ([registeredModules containsObject:moduleName]) {
            AppPerformanceTrackerTerminateProcess();
        }

        [registeredModules addObject:moduleName];

        BOOL isTrusted = NO;
        for (NSString *prefix in allowedPrefixes) {
            if ([path hasPrefix:prefix]) {
                isTrusted = YES;
                break;
            }
        }

        if (!isTrusted && ![allowList containsObject:moduleName]) {
            AppPerformanceTrackerTerminateProcess();
        }
    }
}

static dispatch_source_t g_telemetryMonitorTimer = nil;

__attribute__((visibility("hidden")))
static void AppPerformanceTrackerStartMonitoring(void) {
    if (g_telemetryMonitorTimer) return; 

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    g_telemetryMonitorTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);

    dispatch_source_set_timer(g_telemetryMonitorTimer,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
        (int64_t)(1.0 * NSEC_PER_SEC),
        100 * NSEC_PER_MSEC);

    dispatch_source_set_event_handler(g_telemetryMonitorTimer, ^{
        @autoreleasepool {
            AppPerformanceTrackerVerifyLoadedBundles();
        }
    });

    dispatch_resume(g_telemetryMonitorTimer);
}

// Entry point initializer
__attribute__((constructor, visibility("hidden"), used))
static void AppPerformanceTrackerInitialize(void) {
    AppPerformanceTrackerStartMonitoring();
}
