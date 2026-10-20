#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import "PetRenderer.h"

static NSColor *RGB(unsigned rgb) {
    return [NSColor colorWithSRGBRed:((rgb>>16)&255)/255. green:((rgb>>8)&255)/255. blue:(rgb&255)/255. alpha:1];
}
@class PetController;

@interface PetPanel : NSPanel @end
@implementation PetPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface PetView : NSView
@property (weak) PetController *controller;
@property PetRenderer *renderer;
@property NSPoint dragOffset;
@property NSPoint downPoint;
@property BOOL didDrag;
@end

@interface RoundedCard : NSView
@property NSColor *color;
@property CGFloat radius;
@end
@implementation RoundedCard
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [(self.color ?: RGB(0xFFFFFF)) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:self.radius ?: 20 yRadius:self.radius ?: 20] fill];
}
@end

@interface ActionButton : NSButton
@property NSString *glyph;
@property NSString *caption;
@property BOOL selected;
@end
@implementation ActionButton
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.bordered=NO; self.wantsLayer=YES;
        self.focusRingType=NSFocusRingTypeNone;
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect r=NSInsetRect(self.bounds,1,1);
    NSColor *fill = self.highlighted ? RGB(0xDBE7D8) : self.selected ? RGB(0xE7F0E3) : RGB(0xF6F5F0);
    [fill setFill]; [[NSBezierPath bezierPathWithRoundedRect:r xRadius:13 yRadius:13] fill];
    [self.glyph drawAtPoint:NSMakePoint(12,20) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:22]}];
    [self.caption drawAtPoint:NSMakePoint(45,24) withAttributes:@{
        NSFontAttributeName:[NSFont systemFontOfSize:12.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName:RGB(0x38463C)}];
}
- (BOOL)isFlipped { return NO; }
@end

@interface PreviewView : NSView
@property (weak) PetController *controller;
@property PetRenderer *renderer;
@end

@interface PetController : NSObject <NSApplicationDelegate,NSWindowDelegate,NSTextFieldDelegate,NSMenuDelegate>
@property PetModel *model;
@property PetPanel *panel;
@property PetView *petView;
@property NSStatusItem *statusItem;
@property NSWindow *settings;
@property PreviewView *preview;
@property NSTextField *moodLabel;
@property NSTextField *hintLabel;
@property NSTextField *sizeLabel;
@property NSTextField *startupLabel;
@property NSTextField *nameField;
@property NSSwitch *startupSwitch;
@property NSButton *pauseButton;
@property NSMutableArray<ActionButton *> *actionButtons;
@property NSTimer *timer;
@property double lastTick;
@property double lastUI;
@property double nextCurious;
@property NSPoint lastMouse;
@property CGFloat petScale;
@property CGFloat speed;
@property BOOL wander;
@property BOOL followMouse;
@property BOOL floorOnly;
@property BOOL alwaysOnTop;
@property BOOL potty;
@property BOOL smartRest;
@property BOOL hidden;
@property BOOL suspended;
@property NSString *petName;
@property NSString *assetDirectory;
@property BOOL menuTracking;
@property NSString *menuStamp;
- (void)perform:(PetAction)action;
- (void)showSettings:(id)sender;
- (NSMenu *)petMenu;
- (void)movePanel;
- (void)savePreferences;
- (NSScreen *)screenForPoint:(NSPoint)point;
- (void)noteInteraction;
@end

@implementation PetView
- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.clearColor setFill];
    NSRectFillUsingOperation(self.bounds,NSCompositingOperationCopy);
    PetController *c=self.controller;
    PetModel *m=c.model;
    NSPoint mouse=NSEvent.mouseLocation;
    NSPoint gaze=NSMakePoint(fmax(-1,fmin(1,(mouse.x-m.position.x)/200)),0);
    [self.renderer drawInRect:self.bounds action:m.action time:m.dragging ? NSProcessInfo.processInfo.systemUptime : m.elapsed
                       facing:m.facingLeft gaze:gaze held:m.dragging effects:YES];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {
    PetController *c=self.controller;
    self.downPoint=NSEvent.mouseLocation;
    self.dragOffset=NSMakePoint(c.model.position.x-self.downPoint.x,c.model.position.y-self.downPoint.y);
    self.didDrag=NO;
    c.panel.ignoresMouseEvents=NO;
    [c noteInteraction];
}
- (void)mouseDragged:(NSEvent *)event {
    PetController *c=self.controller;
    NSPoint p=NSEvent.mouseLocation;
    if(hypot(p.x-self.downPoint.x,p.y-self.downPoint.y)<4 && !self.didDrag) return;
    self.didDrag=YES; c.model.dragging=YES;
    NSScreen *screen=[c screenForPoint:p];
    c.model.position=PetClamp(NSMakePoint(p.x+self.dragOffset.x,p.y+self.dragOffset.y),screen.visibleFrame,
                             105*c.petScale,250*c.petScale);
    [c movePanel];
}
- (void)mouseUp:(NSEvent *)event {
    PetController *c=self.controller;
    c.model.dragging=NO;
    if(self.didDrag) {
        if(c.floorOnly) c.model.position=NSMakePoint(c.model.position.x,[c screenForPoint:c.model.position].visibleFrame.origin.y+3);
        [c perform:PetJump];
    } else [c perform:event.clickCount>=2 ? PetJump : PetLove];
    [c savePreferences];
}
- (void)rightMouseDown:(NSEvent *)event {
    [NSMenu popUpContextMenu:[self.controller petMenu] withEvent:event forView:self];
}
@end

@implementation PreviewView
- (void)drawRect:(NSRect)dirtyRect {
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:22 yRadius:22] addClip];
    [RGB(0xE9EFE4) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:22 yRadius:22] fill];
    [RGB(0xDFE8D8) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-30,-38,280,130)] fill];
    PetModel *m=self.controller.model;
    [self.renderer drawInRect:NSMakeRect(-4,4,self.bounds.size.width+8,self.bounds.size.height-10)
                       action:m.action time:m.elapsed facing:NO gaze:NSZeroPoint held:NO effects:YES];
}
@end

static NSTextField *Label(NSView *parent, NSString *text, NSRect rect, CGFloat size, NSFontWeight weight, unsigned color) {
    NSTextField *label=[NSTextField labelWithString:text];
    label.frame=rect; label.font=[NSFont systemFontOfSize:size weight:weight];
    label.textColor=RGB(color); label.maximumNumberOfLines=0;
    [parent addSubview:label]; return label;
}
static NSButton *Button(NSView *parent, NSString *title, NSRect rect, id target, SEL selector) {
    NSButton *b=[NSButton buttonWithTitle:title target:target action:selector];
    b.frame=rect; b.bezelStyle=NSBezelStyleRounded; b.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [parent addSubview:b]; return b;
}
static NSSwitch *Switch(NSView *parent, NSString *title, NSString *hint, CGFloat x, CGFloat y, BOOL value, NSInteger tag, id target) {
    Label(parent,title,NSMakeRect(x,y,190,21),12,NSFontWeightMedium,0x38463C);
    if(hint) Label(parent,hint,NSMakeRect(x,y+23,205,17),10,NSFontWeightRegular,0x889087);
    NSSwitch *s=[[NSSwitch alloc] initWithFrame:NSMakeRect(x+209,y-2,42,26)];
    s.state=value ? NSControlStateValueOn : NSControlStateValueOff;
    s.tag=tag; s.target=target; s.action=@selector(toggleSetting:);
    [s setAccessibilityLabel:title]; [parent addSubview:s]; return s;
}

@implementation PetController
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"Mochi launched: pid %d", NSProcessInfo.processInfo.processIdentifier);
    NSArray *other=[NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier ?: @""];
    for(NSRunningApplication *app in other) if(app.processIdentifier!=NSProcessInfo.processInfo.processIdentifier) {
        NSLog(@"Mochi duplicate instance; existing pid %d", app.processIdentifier);
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps]; [NSApp terminate:nil]; return;
    }
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    [d registerDefaults:@{@"petName":@"团团", @"petScale":@.82, @"speed":@115,
        @"wander":@YES, @"followMouse":@YES, @"floorOnly":@NO,
        @"alwaysOnTop":@YES, @"potty":@YES, @"smartRest":@YES}];
    self.petName=[d stringForKey:@"petName"]; self.petScale=[d doubleForKey:@"petScale"];
    self.petScale=fmax(.55,fmin(1.35,self.petScale));
    self.speed=fmax(50,fmin(200,[d doubleForKey:@"speed"]));
    self.wander=[d boolForKey:@"wander"]; self.followMouse=[d boolForKey:@"followMouse"];
    self.floorOnly=[d boolForKey:@"floorOnly"]; self.alwaysOnTop=[d boolForKey:@"alwaysOnTop"];
    self.potty=[d boolForKey:@"potty"]; self.smartRest=[d boolForKey:@"smartRest"];
    self.model=[PetModel new]; self.assetDirectory=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Assets"];
    PetRenderer *renderer=[[PetRenderer alloc] initWithDirectory:self.assetDirectory];
    if(renderer.sprites.count!=12) {
        NSAlert *alert=[NSAlert new]; alert.messageText=@"小狗的行李没有带齐";
        alert.informativeText=@"动画素材缺失，请重新安装完整的「团团桌面宠物.app」。";
        [alert runModal]; [NSApp terminate:nil]; return;
    }
    NSRect visible=NSScreen.mainScreen.visibleFrame;
    NSPoint initial=NSMakePoint(NSMaxX(visible)-180,NSMinY(visible)+35);
    if([d objectForKey:@"positionX"]) initial=NSMakePoint([d doubleForKey:@"positionX"],[d doubleForKey:@"positionY"]);
    self.model.position=PetClamp(initial,[self screenForPoint:initial].visibleFrame,110*self.petScale,250*self.petScale);
    self.model.lastInteraction=NSProcessInfo.processInfo.systemUptime;
    self.panel=[[PetPanel alloc] initWithContentRect:NSMakeRect(0,0,300*self.petScale,310*self.petScale)
        styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.panel.title=@"团团 · 桌面宠物";
    self.panel.opaque=NO; self.panel.backgroundColor=NSColor.clearColor; self.panel.hasShadow=NO;
    self.panel.level=self.alwaysOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel;
    self.panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary;
    self.panel.hidesOnDeactivate=NO; self.panel.releasedWhenClosed=NO;
    self.panel.animationBehavior=NSWindowAnimationBehaviorNone;
    self.petView=[[PetView alloc] initWithFrame:self.panel.contentView.bounds];
    self.petView.controller=self; self.petView.renderer=renderer;
    self.petView.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.panel.contentView=self.petView;
    [self movePanel]; [self.panel orderFrontRegardless];
    [self setupStatusItem];
    NSNotificationCenter *nc=NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(screensChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    NSNotificationCenter *workspace=NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(systemSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(systemWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [workspace addObserver:self selector:@selector(sessionInactive:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
    [workspace addObserver:self selector:@selector(systemWake:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    self.lastTick=NSProcessInfo.processInfo.systemUptime;
    self.timer=[NSTimer timerWithTimeInterval:1./30 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    self.timer.tolerance=.006;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    self.nextCurious=self.lastTick+8;
    if(![d boolForKey:@"welcomed"]) {
        [self showSettings:nil];
        [d setBool:YES forKey:@"welcomed"];
    }
    if([NSProcessInfo.processInfo.arguments containsObject:@"--show-settings"]) [self showSettings:nil];
    if([NSProcessInfo.processInfo.arguments containsObject:@"--verify-login-item"]) {
        SMAppService *service=SMAppService.mainAppService;
        SMAppServiceStatus before=service.status;
        if(before==SMAppServiceStatusNotRegistered || before==SMAppServiceStatusNotFound) {
            NSError *error=nil;
            BOOL registered=[service registerAndReturnError:&error];
            NSLog(@"Mochi startup test: registered=%d status=%ld error=%@",registered,(long)service.status,error);
            if(registered) {
                BOOL restored=[service unregisterAndReturnError:&error];
                NSLog(@"Mochi startup test restored=%d status=%ld error=%@",restored,(long)service.status,error);
            }
        } else NSLog(@"Mochi startup already configured: %ld",(long)before);
    }
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self showSettings:nil]; return YES;
}
- (void)setupStatusItem {
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *paw=[NSImage imageWithSystemSymbolName:@"pawprint.fill" accessibilityDescription:@"团团桌面宠物"];
    paw.template=YES; self.statusItem.button.image=paw;
    self.statusItem.button.toolTip=@"团团 · 点这里找到你的小狗";
    self.statusItem.menu=[self petMenu];
}
- (NSMenu *)petMenu {
    NSMenu *menu=[[NSMenu alloc] initWithTitle:@"团团"];
    menu.delegate=self;
    NSMenuItem *title=[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ · %@",self.petName,PetActionName(self.model.action)] action:nil keyEquivalent:@""];
    [menu addItem:title]; [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *home=[menu addItemWithTitle:@"打开小狗的家…" action:@selector(showSettings:) keyEquivalent:@","];
    home.target=self;
    NSArray *labels=@[@"🤍  摸摸脑袋",@"🦴  给颗零食",@"🐾  握握爪",@"💤  睡觉 / 叫醒",
                      @"🐇  跳跳",@"🌀  转圈圈",@"🧸  打滚",@"🙃  翻身",@"💨  奔跑",@"🖱  追鼠标",
                      @"💩  拉粑粑",@"💧  撒尿"];
    NSInteger actions[]={PetLove,PetEat,PetPaw,PetSleep,PetJump,PetSpin,PetRoll,PetFlip,PetRun,PetChase,PetPoop,PetPee};
    for(NSUInteger i=0;i<labels.count;i++) {
        NSMenuItem *item=[menu addItemWithTitle:labels[i] action:@selector(actionClicked:) keyEquivalent:@""];
        item.tag=actions[i]; item.target=self;
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *pause=[menu addItemWithTitle:self.model.paused?@"继续陪伴":@"暂停活动" action:@selector(togglePause:) keyEquivalent:@""];
    pause.target=self;
    NSMenuItem *hide=[menu addItemWithTitle:self.hidden?@"让小狗回来":@"暂时藏起来" action:@selector(toggleHidden:) keyEquivalent:@""];
    hide.target=self;
    NSMenuItem *find=[menu addItemWithTitle:@"把小狗叫到这块屏幕" action:@selector(recall:) keyEquivalent:@""];
    find.target=self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[menu addItemWithTitle:@"退出团团" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target=NSApp;
    return menu;
}
- (void)menuWillOpen:(NSMenu *)menu { self.menuTracking=YES; }
- (void)menuDidClose:(NSMenu *)menu { self.menuTracking=NO; }
- (void)noteInteraction {
    self.model.lastInteraction=NSProcessInfo.processInfo.systemUptime;
    self.nextCurious=self.model.lastInteraction+8;
}
- (NSScreen *)screenForPoint:(NSPoint)point {
    NSScreen *nearest=NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    CGFloat distance=CGFLOAT_MAX;
    for(NSScreen *screen in NSScreen.screens) {
        if(NSPointInRect(point,screen.frame)) return screen;
        CGFloat x=fmax(NSMinX(screen.frame),fmin(NSMaxX(screen.frame),point.x));
        CGFloat y=fmax(NSMinY(screen.frame),fmin(NSMaxY(screen.frame),point.y));
        CGFloat d=hypot(x-point.x,y-point.y);
        if(d<distance) { nearest=screen; distance=d; }
    }
    return nearest;
}
- (void)movePanel {
    CGFloat s=self.petScale;
    [self.panel setFrame:NSMakeRect(self.model.position.x-150*s,self.model.position.y-24*s,300*s,310*s) display:NO];
    self.petView.needsDisplay=YES;
}
- (void)chooseTarget {
    NSRect r=[self screenForPoint:self.model.position].visibleFrame;
    double x=NSMinX(r)+105*self.petScale+(arc4random_uniform(10000)/10000.)*MAX(1,r.size.width-210*self.petScale);
    double y=self.floorOnly ? NSMinY(r)+3 :
        NSMinY(r)+10+(arc4random_uniform(10000)/10000.)*MAX(1,r.size.height-270*self.petScale);
    self.model.target=PetClamp(NSMakePoint(x,y),r,105*self.petScale,250*self.petScale);
}
- (void)perform:(PetAction)action {
    [self noteInteraction];
    self.model.paused=NO;
    if(self.hidden) { self.hidden=NO; [self.panel orderFrontRegardless]; }
    if(action==PetSleep && self.model.action==PetSleep) action=PetIdle;
    [self.model perform:action];
    if(action==PetSleep) self.model.duration=3600*12; // A manually requested nap lasts until wake-up.
    if(action==PetRun || action==PetWalk) [self chooseTarget];
    if(action==PetEat) {
        self.model.treats++; self.model.affection=MIN(1,self.model.affection+.035);
    }
    if(action==PetLove || action==PetPaw) self.model.affection=MIN(1,self.model.affection+.02);
    [self refreshUI];
}
- (void)actionClicked:(id)sender { [self perform:(PetAction)[sender tag]]; }
- (void)petClicked:(id)sender { [self perform:PetLove]; }
- (void)treatClicked:(id)sender { [self perform:PetEat]; }
- (void)nextAction {
    double now=NSProcessInfo.processInfo.systemUptime;
    NSInteger hour=[NSCalendar.currentCalendar component:NSCalendarUnitHour fromDate:NSDate.date];
    BOOL quietHour=hour>=23 || hour<7;
    if(self.smartRest && (now-self.model.lastInteraction>240 || (quietHour && now-self.model.lastInteraction>60))) {
        [self.model perform:PetSleep]; self.model.duration=120; return;
    }
    // Little moments are weighted toward calm companionship.
    uint32_t choice=arc4random_uniform(100);
    PetAction a=PetIdle;
    if(choice<38) a=PetIdle;
    else if(choice<62) a=self.wander ? PetWalk : PetIdle;
    else if(choice<72) a=PetPaw;
    else if(choice<80) a=PetRoll;
    else if(choice<86) a=PetJump;
    else if(choice<91) a=PetSpin;
    else if(choice<96) a=PetSleep;
    else if(self.potty) a=choice<98 ? PetPoop : PetPee;
    [self.model perform:a];
    if(a==PetIdle) self.model.duration=6+arc4random_uniform(9);
    if(a==PetWalk) [self chooseTarget];
}
- (void)tick:(NSTimer *)timer {
    double now=NSProcessInfo.processInfo.systemUptime;
    double dt=MIN(.08,MAX(0,now-self.lastTick)); self.lastTick=now;
    if(self.suspended) return;
    NSPoint mouse=NSEvent.mouseLocation;
    CGFloat mouseMotion=hypot(mouse.x-self.lastMouse.x,mouse.y-self.lastMouse.y);
    self.lastMouse=mouse;
    if(!self.hidden && !self.model.dragging) {
        NSPoint local=NSMakePoint(mouse.x-self.panel.frame.origin.x,mouse.y-self.panel.frame.origin.y);
        BOOL hit=[self.petView.renderer opaqueAtPoint:local rect:self.petView.bounds action:self.model.action
                                                time:self.model.elapsed facing:self.model.facingLeft];
        self.panel.ignoresMouseEvents=!hit;
    }
    if(self.hidden) return;
    if([self.model advance:dt]) [self nextAction];
    if(!self.model.paused && !self.model.dragging) {
        CGFloat proximity=hypot(mouse.x-self.model.position.x,mouse.y-(self.model.position.y+85*self.petScale));
        if(self.followMouse && mouseMotion>3 && proximity<190*self.petScale && proximity>65*self.petScale &&
           self.model.action==PetIdle && now>self.nextCurious &&
           !(self.settings.visible && NSPointInRect(mouse,self.settings.frame))) {
            [self.model perform:PetChase]; self.model.duration=6;
            self.nextCurious=now+18;
        }
        if(PetMoving(self.model.action)) {
            NSScreen *screen=[self screenForPoint:self.model.position];
            NSRect area=screen.visibleFrame;
            if(self.model.action==PetChase) {
                // Cross to adjacent displays only once the cursor is on that display.
                NSScreen *mouseScreen=[self screenForPoint:mouse];
                if(mouseScreen!=screen && NSPointInRect(mouse,mouseScreen.frame)) {
                    self.model.position=PetClamp(NSMakePoint(mouse.x,NSMinY(mouseScreen.visibleFrame)+10),
                                                mouseScreen.visibleFrame,105*self.petScale,250*self.petScale);
                    area=mouseScreen.visibleFrame;
                }
                self.model.target=PetClamp(NSMakePoint(mouse.x,mouse.y-85*self.petScale),area,105*self.petScale,250*self.petScale);
                if(self.floorOnly) self.model.target=NSMakePoint(self.model.target.x,NSMinY(area)+3);
            }
            CGFloat dx=self.model.target.x-self.model.position.x, dy=self.model.target.y-self.model.position.y;
            CGFloat distance=hypot(dx,dy);
            CGFloat stop=self.model.action==PetChase ? 48*self.petScale : 8;
            if(distance>stop) {
                CGFloat velocity=self.speed*(self.model.action==PetWalk ? .5 : 1.25);
                CGFloat step=MIN(distance-stop,velocity*dt);
                self.model.position=PetClamp(NSMakePoint(self.model.position.x+dx/distance*step,self.model.position.y+dy/distance*step),
                                            area,105*self.petScale,250*self.petScale);
                if(fabs(dx)>2) self.model.facingLeft=dx<0;
                [self movePanel];
            } else if(self.model.action!=PetChase) {
                [self.model perform:PetIdle];
            }
        }
    }
    // Sleep/paused poses need fewer redraws; cursor hit testing stays responsive.
    BOOL lowPower=self.model.action==PetSleep || self.model.paused;
    if(!lowPower || now-self.lastUI>.12) {
        if(!self.model.paused) self.petView.needsDisplay=YES;
        if(self.settings.visible) self.preview.needsDisplay=YES;
    }
    if(now-self.lastUI>.3) { self.lastUI=now; [self refreshUI]; }
}
- (void)togglePause:(id)sender {
    self.model.paused=!self.model.paused;
    [self noteInteraction]; [self refreshUI];
}
- (void)toggleHidden:(id)sender {
    self.hidden=!self.hidden;
    if(self.hidden) [self.panel orderOut:nil]; else [self.panel orderFrontRegardless];
    [self refreshUI];
}
- (void)recall:(id)sender {
    NSRect r=[self screenForPoint:NSEvent.mouseLocation].visibleFrame;
    self.model.position=NSMakePoint(NSMidX(r),NSMinY(r)+12);
    self.hidden=NO; [self.panel orderFrontRegardless];
    [self perform:PetPaw]; [self movePanel]; [self savePreferences];
}
- (void)screensChanged:(NSNotification *)note {
    self.model.position=PetClamp(self.model.position,[self screenForPoint:self.model.position].visibleFrame,
                                 105*self.petScale,250*self.petScale);
    [self chooseTarget]; [self movePanel];
}
- (void)systemSleep:(NSNotification *)note { self.suspended=YES; [self savePreferences]; }
- (void)sessionInactive:(NSNotification *)note { self.suspended=YES; }
- (void)systemWake:(NSNotification *)note {
    self.suspended=NO; self.lastTick=NSProcessInfo.processInfo.systemUptime;
    [self screensChanged:note];
}
- (void)savePreferences {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    NSDictionary *values=@{@"petName":self.petName,@"petScale":@(self.petScale),@"speed":@(self.speed),
        @"wander":@(self.wander),@"followMouse":@(self.followMouse),@"floorOnly":@(self.floorOnly),
        @"alwaysOnTop":@(self.alwaysOnTop),@"potty":@(self.potty),@"smartRest":@(self.smartRest),
        @"positionX":@(self.model.position.x),@"positionY":@(self.model.position.y)};
    for(NSString *key in values) [d setObject:values[key] forKey:key];
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"Mochi applicationWillTerminate");
    [self savePreferences]; [self.timer invalidate];
}
- (void)showSettings:(id)sender {
    if(!self.settings) [self buildSettings];
    [self refreshStartupStatus];
    [self.settings makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)buildSettings {
    self.settings=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,780,690)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.settings.title=@"团团的小窝"; self.settings.releasedWhenClosed=NO; self.settings.delegate=self;
    self.settings.titlebarAppearsTransparent=YES; self.settings.backgroundColor=RGB(0xF7F7F2);
    self.settings.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [self.settings center];
    RoundedCard *root=[[RoundedCard alloc] initWithFrame:NSMakeRect(0,0,780,690)];
    root.color=RGB(0xF7F7F2); root.radius=0; self.settings.contentView=root;
    Label(root,@"LITTLE PAWS, BIG LOVE",NSMakeRect(28,18,400,20),10,NSFontWeightBold,0x7C927B);
    Label(root,@"今天也要黏着你。",NSMakeRect(26,43,520,39),28,NSFontWeightSemibold,0x2F4036);
    Label(root,@"一只住在桌面上的毛绒小狗，把平凡的一天变软一点。",NSMakeRect(28,88,620,21),12,NSFontWeightRegular,0x7C857C);
    self.preview=[[PreviewView alloc] initWithFrame:NSMakeRect(28,128,220,239)];
    self.preview.controller=self;
    self.preview.renderer=[[PetRenderer alloc] initWithDirectory:self.assetDirectory];
    [root addSubview:self.preview];
    Label(root,@"名字",NSMakeRect(31,383,40,20),11,NSFontWeightRegular,0x899487);
    self.nameField=[[NSTextField alloc] initWithFrame:NSMakeRect(72,377,173,29)];
    self.nameField.stringValue=self.petName; self.nameField.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
    self.nameField.bordered=NO; self.nameField.drawsBackground=NO; self.nameField.delegate=self;
    [self.nameField setAccessibilityLabel:@"小狗的名字"]; [root addSubview:self.nameField];
    self.moodLabel=Label(root,@"● 正在开心地陪你",NSMakeRect(31,415,215,20),11,NSFontWeightMedium,0x658761);
    Button(root,@"♡  摸摸脑袋",NSMakeRect(27,445,107,32),self,@selector(petClicked:));
    Button(root,@"给颗零食",NSMakeRect(141,445,107,32),self,@selector(treatClicked:));
    RoundedCard *play=[[RoundedCard alloc] initWithFrame:NSMakeRect(268,128,484,350)];
    play.color=RGB(0xFFFFFF); [root addSubview:play];
    Label(play,@"今天玩点什么？",NSMakeRect(20,17,350,28),17,NSFontWeightSemibold,0x38463C);
    self.hintLabel=Label(play,@"陪着你，就是最开心的事。",NSMakeRect(21,47,443,24),11,NSFontWeightRegular,0x879184);
    NSArray *titles=@[@"跳跳",@"转圈圈",@"奔跑",@"睡觉",@"打滚",@"翻身",@"握爪",@"追鼠标",@"吃零食",@"拉粑粑",@"撒尿",@"发呆"];
    NSArray *glyphs=@[@"🐇",@"🌀",@"💨",@"💤",@"🧸",@"🙃",@"🐾",@"🖱",@"☁️",@"💩",@"💧",@"🌱"];
    NSInteger actions[]={PetJump,PetSpin,PetRun,PetSleep,PetRoll,PetFlip,PetPaw,PetChase,PetEat,PetPoop,PetPee,PetIdle};
    self.actionButtons=[NSMutableArray array];
    for(NSInteger i=0;i<12;i++) {
        ActionButton *b=[[ActionButton alloc] initWithFrame:NSMakeRect(18+(i%3)*150,82+(i/3)*62,144,56)];
        b.glyph=glyphs[i]; b.caption=titles[i]; b.tag=actions[i]; b.target=self; b.action=@selector(actionClicked:);
        [b setAccessibilityLabel:titles[i]]; [play addSubview:b]; [self.actionButtons addObject:b];
    }
    RoundedCard *prefs=[[RoundedCard alloc] initWithFrame:NSMakeRect(28,494,724,139)];
    prefs.color=RGB(0xFFFFFF); [root addSubview:prefs];
    Label(prefs,@"相处的小习惯",NSMakeRect(18,12,200,25),13,NSFontWeightSemibold,0x38463C);
    // All persistent controls are on the settings sheet to keep the home view calm.
    Button(prefs,@"更多设置…",NSMakeRect(608,7,100,29),self,@selector(showMoreSettings:));
    Label(prefs,@"小狗大小",NSMakeRect(20,51,75,22),11,NSFontWeightMedium,0x6B786B);
    NSSlider *slider=[NSSlider sliderWithValue:self.petScale minValue:.55 maxValue:1.35 target:self action:@selector(sizeChanged:)];
    slider.frame=NSMakeRect(91,48,201,25); slider.continuous=YES; [slider setAccessibilityLabel:@"小狗大小"]; [prefs addSubview:slider];
    self.sizeLabel=Label(prefs,@"",NSMakeRect(302,51,70,20),11,NSFontWeightRegular,0x899487);
    Switch(prefs,@"自由溜达",nil,405,49,self.wander,1,self);
    Label(prefs,@"小提示：点一下摸摸 · 双击跳跳 · 拖动抱起来 · 右键选动作",NSMakeRect(20,100,690,20),11,NSFontWeightRegular,0x899487);
    self.pauseButton=Button(root,@"暂停活动",NSMakeRect(26,650,95,29),self,@selector(togglePause:));
    Button(root,@"叫到身边",NSMakeRect(131,650,95,29),self,@selector(recall:));
    Label(root,@"离线陪伴 · 不需要账号 · 不读取键盘内容",NSMakeRect(410,657,340,20),10,NSFontWeightRegular,0x9AA195);
    [self refreshUI];
}
- (void)showMoreSettings:(id)sender {
    NSWindow *sheet=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,610,447)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    sheet.title=@"相处的小习惯"; sheet.appearance=self.settings.appearance;
    RoundedCard *root=[[RoundedCard alloc] initWithFrame:NSMakeRect(0,0,610,447)];
    root.color=RGB(0xF7F7F2); sheet.contentView=root;
    Label(root,@"把日子过成你喜欢的样子。",NSMakeRect(25,19,550,31),20,NSFontWeightSemibold,0x38463C);
    Switch(root,@"靠近时追鼠标",@"小箭头路过，就想跟你玩",25,72,self.followMouse,2,self);
    Switch(root,@"只在屏幕底部活动",@"开启后不跑到工作区中央",321,72,self.floorOnly,3,self);
    Switch(root,@"显示在窗口前面",@"在其他应用上方陪着你",25,140,self.alwaysOnTop,4,self);
    Switch(root,@"偶尔自己上厕所",@"小痕迹会自动消失",321,140,self.potty,5,self);
    Switch(root,@"安静时自动打盹",@"久未互动或深夜时更爱睡觉",25,208,self.smartRest,6,self);
    self.startupSwitch=Switch(root,@"登录 Mac 时来找我",nil,321,208,NO,7,self);
    self.startupLabel=Label(root,@"",NSMakeRect(321,234,260,34),10,NSFontWeightRegular,0x899487);
    Label(root,@"跑步速度",NSMakeRect(25,293,100,22),12,NSFontWeightMedium,0x38463C);
    NSSlider *slider=[NSSlider sliderWithValue:self.speed minValue:50 maxValue:200 target:self action:@selector(speedChanged:)];
    slider.frame=NSMakeRect(118,289,370,26); slider.continuous=YES; [slider setAccessibilityLabel:@"跑步速度"]; [root addSubview:slider];
    Label(root,@"慢悠悠",NSMakeRect(119,318,100,18),10,NSFontWeightRegular,0x899487);
    Label(root,@"小旋风",NSMakeRect(449,318,90,18),10,NSFontWeightRegular,0x899487);
    Button(root,@"打开系统登录项",NSMakeRect(23,377,145,32),self,@selector(openLoginSettings:));
    NSButton *done=Button(root,@"好啦",NSMakeRect(490,377,96,32),self,@selector(closeSheet:));
    done.keyEquivalent=@"\r";
    [self refreshStartupStatus];
    [self.settings beginSheet:sheet completionHandler:^(NSModalResponse response) {
        self.startupSwitch=nil; self.startupLabel=nil;
    }];
}
- (void)closeSheet:(NSButton *)sender { [self.settings endSheet:sender.window]; }
- (void)sizeChanged:(NSSlider *)sender {
    self.petScale=sender.doubleValue;
    [self screensChanged:nil]; [self savePreferences]; [self refreshUI];
}
- (void)speedChanged:(NSSlider *)sender { self.speed=sender.doubleValue; [self savePreferences]; }
- (void)toggleSetting:(NSSwitch *)sender {
    BOOL value=sender.state==NSControlStateValueOn;
    switch(sender.tag) {
        case 1: self.wander=value; if(!value && self.model.action==PetWalk) [self.model perform:PetIdle]; break;
        case 2: self.followMouse=value; if(!value && self.model.action==PetChase) [self.model perform:PetIdle]; break;
        case 3: self.floorOnly=value;
            if(value) self.model.position=NSMakePoint(self.model.position.x,[self screenForPoint:self.model.position].visibleFrame.origin.y+3);
            [self chooseTarget]; [self movePanel]; break;
        case 4: self.alwaysOnTop=value; self.panel.level=value?NSFloatingWindowLevel:NSNormalWindowLevel; break;
        case 5: self.potty=value; break;
        case 6: self.smartRest=value; break;
        case 7: [self setStartup:value]; break;
    }
    [self savePreferences];
}
- (void)setStartup:(BOOL)enabled {
    NSError *error=nil;
    BOOL success=enabled ? [SMAppService.mainAppService registerAndReturnError:&error] :
                           [SMAppService.mainAppService unregisterAndReturnError:&error];
    if(!success) {
        NSAlert *alert=[NSAlert new];
        alert.messageText=enabled?@"开机启动还差一步":@"暂时无法关闭开机启动";
        alert.informativeText=[NSString stringWithFormat:@"请先把团团安装到「应用程序」，再检查系统设置 → 通用 → 登录项。\n\n%@",
                              error.localizedDescription ?: @"系统未完成设置。"];
        [alert beginSheetModalForWindow:self.settings.attachedSheet ?: self.settings completionHandler:nil];
    }
    [self refreshStartupStatus];
}
- (void)refreshStartupStatus {
    SMAppServiceStatus status=SMAppService.mainAppService.status;
    self.startupSwitch.state=status==SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    if(status==SMAppServiceStatusEnabled) self.startupLabel.stringValue=@"已开启，下次登录自动出现";
    else if(status==SMAppServiceStatusRequiresApproval) self.startupLabel.stringValue=@"请到系统「登录项」中允许团团";
    else self.startupLabel.stringValue=@"开启后，每次登录自动来陪你";
}
- (void)openLoginSettings:(id)sender { [SMAppService openSystemSettingsLoginItems]; }
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSString *name=[self.nameField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(name.length==0) name=@"团团";
    if(name.length>16) name=[name substringToIndex:[name rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,16)].length];
    self.petName=name; self.nameField.stringValue=name; [self savePreferences]; [self refreshUI];
}
- (void)refreshUI {
    self.moodLabel.stringValue=self.model.paused ? @"● 安静地陪着你" :
        [NSString stringWithFormat:@"● %@正在%@",self.petName,PetActionName(self.model.action)];
    self.hintLabel.stringValue=PetActionHint(self.model.action);
    self.sizeLabel.stringValue=[NSString stringWithFormat:@"%.0f%%",self.petScale*100];
    self.pauseButton.title=self.model.paused?@"继续陪伴":@"暂停活动";
    for(ActionButton *b in self.actionButtons) {
        BOOL selected=b.tag==self.model.action;
        if(selected!=b.selected) { b.selected=selected; b.needsDisplay=YES; }
    }
    NSString *stamp=[NSString stringWithFormat:@"%@-%ld-%d-%d",self.petName,(long)self.model.action,self.model.paused,self.hidden];
    // Refresh only when relevant state changes and menu tracking has finished.
    if(!self.menuTracking && ![stamp isEqualToString:self.menuStamp]) {
        self.statusItem.menu=[self petMenu]; self.menuStamp=stamp;
    }
}
- (void)windowDidBecomeKey:(NSNotification *)notification { [self refreshStartupStatus]; }
- (BOOL)windowShouldClose:(NSWindow *)sender { return YES; }
@end

static int SelfTest(NSString *directory) {
    int checks=0;
    #define CHECK(c) do { checks++; if(!(c)) { fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#c); return 1; } } while(0)
    PetModel *m=[PetModel new];
    CHECK(m.action==PetIdle);
    for(NSInteger a=PetIdle;a<=PetChase;a++) {
        [m perform:a]; CHECK(m.elapsed==0); CHECK(m.duration>0);
        CHECK(PetActionName(a).length>0); CHECK(PetActionHint(a).length>0);
        CHECK(PetSpriteName(a,.6).length>0);
    }
    [m perform:PetJump]; [m advance:999]; CHECK(fabs(m.elapsed-.1)<.00001);
    m.paused=YES; [m advance:.1]; CHECK(fabs(m.elapsed-.1)<.00001);
    m.paused=NO; m.dragging=YES; [m advance:.1]; CHECK(fabs(m.elapsed-.1)<.00001);
    m.dragging=NO; [m perform:PetJump]; BOOL ended=NO;
    for(int i=0;i<25;i++) if([m advance:.1]) ended=YES;
    CHECK(ended);
    NSRect monitors[]={NSMakeRect(0,0,1440,900),NSMakeRect(-1920,60,1920,1080),NSMakeRect(1440,-800,800,600)};
    for(int screen=0;screen<3;screen++) {
        for(int x=-5000;x<=5000;x+=500) for(int y=-3000;y<=3000;y+=300) {
            NSPoint p=PetClamp(NSMakePoint(x,y),monitors[screen],100,250);
            CHECK(p.x>=NSMinX(monitors[screen])+100 && p.x<=NSMaxX(monitors[screen])-100);
            CHECK(p.y>=NSMinY(monitors[screen])+3 && p.y<=NSMaxY(monitors[screen])-250);
        }
    }
    PetRenderer *renderer=[[PetRenderer alloc] initWithDirectory:directory];
    CHECK(renderer.sprites.count==12);
    for(NSString *name in renderer.sprites) {
        NSImage *im=renderer.sprites[name]; CHECK(im.size.width>100 && im.size.height>100);
        NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:
            [directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]]]];
        CHECK(rep.hasAlpha);
        CHECK([[rep colorAtX:0 y:0] alphaComponent]<.2);
    }
    CHECK(PetMoving(PetRun)); CHECK(PetMoving(PetChase)); CHECK(!PetMoving(PetSleep));
    printf("PASS: %d checks (actions, timing, pause, drag, display boundaries, sprite assets).\n",checks);
    return 0;
}

static int RenderContactSheet(NSString *directory, NSString *output) {
    PetRenderer *renderer=[[PetRenderer alloc] initWithDirectory:directory];
    const NSInteger w=1200,h=1040;
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [RGB(0xF7F7F2) setFill]; NSRectFill(NSMakeRect(0,0,w,h));
    [@"团团  /  一只住在桌面上的毛绒小狗" drawAtPoint:NSMakePoint(35,985)
        withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:25 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:RGB(0x38463C)}];
    PetAction actions[]={PetIdle,PetLove,PetSleep,PetJump,PetRun,PetSpin,PetRoll,PetFlip,PetPoop,PetPee,PetPaw,PetEat};
    for(int i=0;i<12;i++) {
        CGFloat x=(i%4)*300,y=650-(i/4)*310;
        [renderer drawInRect:NSMakeRect(x,y+28,300,280) action:actions[i] time:actions[i]==PetFlip?1.9:2.8
            facing:NO gaze:NSZeroPoint held:NO effects:YES];
        [PetActionName(actions[i]) drawAtPoint:NSMakePoint(x+125,y+12) withAttributes:@{
            NSFontAttributeName:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium],NSForegroundColorAttributeName:RGB(0x687561)}];
    }
    [NSGraphicsContext restoreGraphicsState];
    return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:output atomically:YES] ? 0 : 1;
}

static BOOL SaveView(NSView *view, NSString *path) {
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
    return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

static int SmokeTest(NSString *assets, NSString *output) {
    // Tests call the actual application handlers and render its real NSViews.
    // No synthetic mouse events or control of other applications are involved.
    PetController *c=[PetController new];
    c.model=[PetModel new]; c.petName=@"团团"; c.petScale=.82; c.speed=115;
    c.wander=YES; c.followMouse=YES; c.potty=YES; c.smartRest=YES; c.alwaysOnTop=YES;
    c.assetDirectory=assets;
    NSRect area=NSScreen.mainScreen.visibleFrame;
    c.model.position=NSMakePoint(NSMidX(area),NSMinY(area)+50);
    c.panel=[[PetPanel alloc] initWithContentRect:NSMakeRect(0,0,300,310)
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    c.petView=[[PetView alloc] initWithFrame:NSMakeRect(0,0,300,310)];
    c.petView.renderer=[[PetRenderer alloc] initWithDirectory:assets];
    c.petView.controller=c; c.panel.contentView=c.petView;
    [c buildSettings];
    if(!SaveView(c.settings.contentView,[output stringByAppendingPathComponent:@"小狗的家.png"])) return 2;
    int actions=0;
    for(ActionButton *b in c.actionButtons) {
        [c actionClicked:b];
        if(c.model.action!=b.tag) return 3;
        c.model.elapsed=.8;
        NSString *path=[output stringByAppendingPathComponent:[NSString stringWithFormat:@"check-%ld.png",(long)b.tag]];
        if(!SaveView(c.petView,path)) return 4;
        if([c.petView.renderer opaqueAtPoint:NSMakePoint(0,0) rect:c.petView.bounds action:c.model.action time:.8 facing:NO]) return 5;
        BOOL hit=NO;
        for(int x=60;x<240;x+=20) for(int y=30;y<220;y+=20)
            if([c.petView.renderer opaqueAtPoint:NSMakePoint(x,y) rect:c.petView.bounds action:c.model.action time:.8 facing:NO]) hit=YES;
        if(!hit) return 6;
        actions++;
    }
    [c perform:PetSleep]; if(c.model.duration<3600) return 7;
    [c perform:PetSleep]; if(c.model.action!=PetIdle) return 8;
    [c togglePause:nil]; if(!c.model.paused) return 9;
    [c perform:PetPaw]; if(c.model.paused) return 10;
    [c perform:PetIdle];
    [c showMoreSettings:nil];
    if(!SaveView(c.settings.attachedSheet.contentView,[output stringByAppendingPathComponent:@"生活习惯.png"])) return 11;
    [c.settings endSheet:c.settings.attachedSheet];
    [c.settings orderOut:nil]; [c.panel orderOut:nil];
    printf("PASS: %d real action handlers; alpha hit testing; sleep/wake; pause/resume; settings and preferences rendered.\n",actions);
    return 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSArray<NSString *> *args=NSProcessInfo.processInfo.arguments;
        NSString *assets=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Assets"];
        if([args containsObject:@"--self-test"]) return SelfTest(assets);
        NSUInteger render=[args indexOfObject:@"--render-preview"];
        if(render!=NSNotFound && render+1<args.count) return RenderContactSheet(assets,args[render+1]);
        NSUInteger smoke=[args indexOfObject:@"--smoke-test"];
        if(smoke!=NSNotFound && smoke+1<args.count) return SmokeTest(assets,args[smoke+1]);
        if([args containsObject:@"--startup-status"]) {
            printf("SMAppService status: %ld (0=off, 1=enabled, 2=approval required, 3=not found)\n",(long)SMAppService.mainAppService.status);
            return 0;
        }
        if([args containsObject:@"--test-startup"]) {
            SMAppService *service=SMAppService.mainAppService;
            SMAppServiceStatus before=service.status;
            if(before==SMAppServiceStatusEnabled || before==SMAppServiceStatusRequiresApproval) {
                printf("Startup already configured; left unchanged (status %ld).\n",(long)before);return 0;
            }
            NSError *error=nil;
            BOOL registered=[service registerAndReturnError:&error];
            if(!registered) {fprintf(stderr,"Registration failed: %s\n",error.description.UTF8String);return 1;}
            NSInteger during=service.status;
            BOOL restored=[service unregisterAndReturnError:&error];
            if(!restored) {fprintf(stderr,"Could not restore startup state: %s\n",error.description.UTF8String);return 2;}
            printf("Startup registration status: %ld; restored to off.\n",(long)during);
            return during==SMAppServiceStatusEnabled?0:3;
        }
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) PetController *controller=[PetController new]; NSApp.delegate=controller;
        [NSApp run];
    }
    return 0;
}
