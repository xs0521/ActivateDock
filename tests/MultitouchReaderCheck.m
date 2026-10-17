#import <AppKit/AppKit.h>
#import "MultitouchReader.h"
int main(void) {
    @autoreleasepool {
        MultitouchReader *reader = [MultitouchReader new];
        __block int changes = 0;
        reader.onDevicesChanged = ^{ changes++; };
        if (![reader start]) return 1;
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4.2]];
        NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
        [center postNotificationName:NSWorkspaceWillSleepNotification object:nil];
        [center postNotificationName:NSWorkspaceDidWakeNotification object:nil];
        [reader stop];
        if (changes != 4) { NSLog(@"Unexpected device refresh count: %d", changes); return 2; }
        if (![reader start]) return 3;
        [reader stop];
        NSLog(@"PASS: enumeration, stable refresh, sleep/wake notifications, stop and restart");
    }
    return 0;
}
