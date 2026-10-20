#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, PetAction) {
    PetIdle, PetWalk, PetRun, PetSleep, PetJump, PetSpin,
    PetRoll, PetFlip, PetPoop, PetPee, PetPaw, PetLove, PetEat, PetChase
};

FOUNDATION_EXPORT NSString *PetActionName(PetAction action);
FOUNDATION_EXPORT NSString *PetActionHint(PetAction action);
FOUNDATION_EXPORT NSString *PetSpriteName(PetAction action, double time);
FOUNDATION_EXPORT double PetDuration(PetAction action);
FOUNDATION_EXPORT NSPoint PetClamp(NSPoint p, NSRect visible, CGFloat halfWidth, CGFloat height);
FOUNDATION_EXPORT BOOL PetMoving(PetAction action);

@interface PetModel : NSObject
@property PetAction action;
@property double elapsed;
@property double duration;
@property double clock;
@property double lastInteraction;
@property BOOL dragging;
@property BOOL paused;
@property BOOL facingLeft;
@property NSPoint position;
@property NSPoint target;
@property CGFloat affection;
@property NSInteger treats;
- (void)perform:(PetAction)action;
- (BOOL)advance:(double)dt;
@end
