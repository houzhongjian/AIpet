#import "PetModel.h"

@interface PetRenderer : NSObject
@property (readonly) NSDictionary<NSString *, NSImage *> *sprites;
- (instancetype)initWithDirectory:(NSString *)directory;
- (NSRect)drawInRect:(NSRect)rect action:(PetAction)action time:(double)time
             facing:(BOOL)left gaze:(NSPoint)gaze held:(BOOL)held effects:(BOOL)effects;
- (BOOL)opaqueAtPoint:(NSPoint)point rect:(NSRect)rect action:(PetAction)action time:(double)time facing:(BOOL)left;
@end
