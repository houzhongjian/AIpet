#import "PetModel.h"

NSString *PetActionName(PetAction action) {
    return @[@"发呆", @"散步", @"奔跑", @"睡觉", @"跳跳", @"转圈圈",
             @"打滚", @"翻身", @"拉粑粑", @"撒尿", @"握爪", @"摸摸", @"吃零食", @"追鼠标"][action];
}
NSString *PetActionHint(PetAction action) {
    return @[@"陪着你，就是最开心的事。", @"小短腿也要探索世界！", @"看我的小短腿！",
             @"呼噜呼噜… 梦里也有你。", @"开心得要飞起来啦！", @"转一圈，好运就来啦。",
             @"肚皮给你，摸摸嘛。", @"嘿咻！我会自己翻回来。", @"等一下下… 马上就好。",
             @"嘘… 借过一下下。", @"你好呀，把手给我。", @"再摸一下，就一下～",
             @"啊呜！是幸福的味道。", @"小箭头，等等我！"][action];
}
double PetDuration(PetAction action) {
    const double values[] = {8, 7, 5, 50, 2.4, 3.6, 4.8, 2.8, 4.8, 4.6, 3.4, 4, 4.2, 18};
    return values[action];
}
BOOL PetMoving(PetAction action) { return action == PetWalk || action == PetRun || action == PetChase; }
NSString *PetSpriteName(PetAction action, double time) {
    switch (action) {
        case PetWalk: case PetRun: case PetChase:
            return ((int)(time * (action == PetWalk ? 5 : 9)) % 2) ? @"run-b" : @"run-a";
        case PetSleep: return @"sleep";
        case PetJump: return @"jump";
        case PetSpin: {
            NSInteger phase = (NSInteger)(time * 5) % 4;
            return @[@"sit", @"run-a", @"back", @"run-b"][phase];
        }
        case PetRoll: return @"roll";
        case PetFlip: return time < 1.5 ? @"roll" : @"lie";
        case PetPoop: return @"poop";
        case PetPee: return @"pee";
        case PetPaw: return @"paw";
        case PetLove: return ((int)(time * 1.3) % 2) ? @"tilt" : @"paw";
        case PetEat: return @"lie";
        case PetIdle: return fmod(time, 9) > 5.8 ? @"tilt" : @"sit";
    }
    return @"sit";
}
NSPoint PetClamp(NSPoint p, NSRect visible, CGFloat halfWidth, CGFloat height) {
    CGFloat loX = NSMinX(visible) + halfWidth, hiX = NSMaxX(visible) - halfWidth;
    CGFloat loY = NSMinY(visible) + 3, hiY = NSMaxY(visible) - height;
    return NSMakePoint(hiX < loX ? NSMidX(visible) : fmax(loX, fmin(hiX,p.x)),
                       hiY < loY ? NSMinY(visible) : fmax(loY, fmin(hiY,p.y)));
}
@implementation PetModel
- (instancetype)init {
    if ((self = [super init])) { _action = PetIdle; _duration = 8; _affection = .65; }
    return self;
}
- (void)perform:(PetAction)action {
    self.action = action;
    self.elapsed = 0;
    self.duration = PetDuration(action);
}
- (BOOL)advance:(double)dt {
    if (self.paused || self.dragging) return NO;
    dt = fmax(0, fmin(.1,dt)); // Wake from system sleep without teleporting.
    self.clock += dt; self.elapsed += dt;
    return self.elapsed >= self.duration;
}
@end
