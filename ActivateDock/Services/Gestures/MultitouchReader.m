#import "MultitouchReader.h"
#import <AppKit/AppKit.h>
#import <dlfcn.h>

// Contact-frame ABI used by Apple's MultitouchSupport framework (also used by
// OpenMultitouchSupport; see Resources/MultitouchSupport-LICENSE.txt).
// Keep the full layout, including unused fields.
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int frame;
    double timestamp;
    int identifier, state, fingerID, handID;
    MTVector normalizedPosition;
    float total, pressure, angle, majorAxis, minorAxis;
    MTVector absolutePosition;
    int field14, field15;
    float density;
} MTContact;
typedef void (*MTCallback)(void *, MTContact *, int, double, int);

@implementation ADTouch
@end

@interface MultitouchReader ()
@property(nonatomic) NSMutableDictionary<NSNumber *, NSValue *> *devices;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) BOOL enabled;
@end

static __weak MultitouchReader *activeReader;
static CFArrayRef (*createDeviceList)(void);
static void (*registerCallback)(void *, MTCallback);
static void (*unregisterCallback)(void *, MTCallback);
static OSStatus (*startDevice)(void *, int);
static OSStatus (*stopDevice)(void *);
static OSStatus (*getDeviceID)(void *, uint64_t *);

static void contactFrame(void *device, MTContact *contacts, int count, double timestamp, int frame) {
    @autoreleasepool {
        NSMutableArray<ADTouch *> *touches = [NSMutableArray arrayWithCapacity:MAX(count, 0)];
        for (int i = 0; i < count; i++) {
            ADTouch *touch = [ADTouch new];
            touch.x = contacts[i].normalizedPosition.position.x;
            touch.y = contacts[i].normalizedPosition.position.y;
            touch.state = contacts[i].state;
            [touches addObject:touch];
        }
        // The framework owns contacts only for the duration of this callback.
        dispatch_async(dispatch_get_main_queue(), ^{
            MultitouchReader *reader = activeReader;
            if (!reader.enabled || !reader.onFrame) return;
            for (NSNumber *key in reader.devices) {
                if (reader.devices[key].pointerValue == device) {
                    reader.onFrame(key.unsignedIntegerValue, touches);
                    break;
                }
            }
        });
    }
}

@implementation MultitouchReader
- (BOOL)start {
    NSAssert(NSThread.isMainThread, @"Must run on main thread");
    if (self.enabled) return YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY);
        if (!framework) return;
        createDeviceList = dlsym(framework, "MTDeviceCreateList");
        registerCallback = dlsym(framework, "MTRegisterContactFrameCallback");
        unregisterCallback = dlsym(framework, "MTUnregisterContactFrameCallback");
        startDevice = dlsym(framework, "MTDeviceStart");
        stopDevice = dlsym(framework, "MTDeviceStop");
        getDeviceID = dlsym(framework, "MTDeviceGetDeviceID");
    });
    if (!createDeviceList || !registerCallback || !unregisterCallback || !startDevice || !stopDevice || !getDeviceID) return NO;
    self.enabled = YES;
    self.devices = [NSMutableDictionary new];
    activeReader = self;
    [self refreshDevices];
    // Retry enumeration even when no trackpad is currently connected.
    __weak MultitouchReader *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshDevices];
    }];
    NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
    [center addObserver:self selector:@selector(willSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [center addObserver:self selector:@selector(didWake:) name:NSWorkspaceDidWakeNotification object:nil];
    return YES;
}

- (void)refreshDevices {
    if (!self.enabled) return;
    CFArrayRef list = createDeviceList();
    if (!list) return;
    NSMutableSet<NSNumber *> *present = [NSMutableSet new];
    BOOL changed = NO;
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
        void *device = (void *)CFArrayGetValueAtIndex(list, i);
        // Enumeration returns new handles. Match by hardware ID so polling
        // never restarts existing listeners or resets a gesture in progress.
        uint64_t deviceID = 0;
        if (getDeviceID(device, &deviceID) != noErr) continue;
        NSNumber *key = @(deviceID);
        [present addObject:key];
        if (self.devices[key]) continue;
        CFRetain(device);
        registerCallback(device, contactFrame);
        OSStatus status = startDevice(device, 0);
        if (status != noErr) {
            unregisterCallback(device, contactFrame);
            CFRelease(device);
            NSLog(@"[FourFingerSwipe] device start failed: %d", (int)status);
            continue;
        }
        self.devices[key] = [NSValue valueWithPointer:device];
        changed = YES;
        NSLog(@"[FourFingerSwipe] listening to device %llu", (unsigned long long)deviceID);
    }
    for (NSNumber *key in self.devices.allKeys) {
        if (![present containsObject:key]) {
            [self removeDevice:key];
            changed = YES;
        }
    }
    CFRelease(list);
    if (changed && self.onDevicesChanged) self.onDevicesChanged();
}

- (void)removeDevice:(NSNumber *)key {
    void *device = self.devices[key].pointerValue;
    [self.devices removeObjectForKey:key];
    unregisterCallback(device, contactFrame);
    stopDevice(device);
    CFRelease(device);
}

- (void)clearDevices {
    for (NSNumber *key in self.devices.allKeys) [self removeDevice:key];
    if (self.onDevicesChanged) self.onDevicesChanged();
}

- (void)willSleep:(NSNotification *)note {
    [self.timer invalidate];
    self.timer = nil;
    [self clearDevices];
}

- (void)didWake:(NSNotification *)note {
    if (!self.enabled) return;
    [self.timer invalidate];
    [self refreshDevices];
    __weak MultitouchReader *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshDevices];
    }];
}

- (void)stop {
    NSAssert(NSThread.isMainThread, @"Must run on main thread");
    self.enabled = NO;
    [self.timer invalidate];
    self.timer = nil;
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [self clearDevices];
    if (activeReader == self) activeReader = nil;
}
@end
