#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface ADTouch : NSObject
@property(nonatomic) float x;
@property(nonatomic) float y;
@property(nonatomic) int state;
@end

// Delivers copied contact frames on the main queue, with a separate device key.
@interface MultitouchReader : NSObject
@property(nonatomic, copy, nullable) void (^onFrame)(NSUInteger device, NSArray<ADTouch *> *touches);
@property(nonatomic, copy, nullable) void (^onDevicesChanged)(void);
- (BOOL)start;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
