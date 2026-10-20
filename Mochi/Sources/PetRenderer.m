#import "PetRenderer.h"

static NSColor *Color(unsigned rgb, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:((rgb>>16)&255)/255. green:((rgb>>8)&255)/255. blue:(rgb&255)/255. alpha:alpha];
}
static void Text(NSString *text, NSPoint point, CGFloat size, NSColor *color) {
    [text drawAtPoint:point withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:size weight:NSFontWeightSemibold],
                                           NSForegroundColorAttributeName:color}];
}
static void Heart(NSPoint p, CGFloat size, CGFloat alpha) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(p.x,p.y-size*.45)];
    [path curveToPoint:NSMakePoint(p.x-size*.5,p.y+size*.15)
        controlPoint1:NSMakePoint(p.x-size*.12,p.y-size*.2) controlPoint2:NSMakePoint(p.x-size*.58,p.y-size*.05)];
    [path curveToPoint:NSMakePoint(p.x,p.y+size*.26)
        controlPoint1:NSMakePoint(p.x-size*.5,p.y+size*.55) controlPoint2:NSMakePoint(p.x-size*.14,p.y+size*.56)];
    [path curveToPoint:NSMakePoint(p.x+size*.5,p.y+size*.15)
        controlPoint1:NSMakePoint(p.x+size*.14,p.y+size*.56) controlPoint2:NSMakePoint(p.x+size*.5,p.y+size*.55)];
    [path curveToPoint:NSMakePoint(p.x,p.y-size*.45)
        controlPoint1:NSMakePoint(p.x+size*.58,p.y-size*.05) controlPoint2:NSMakePoint(p.x+size*.12,p.y-size*.2)];
    [Color(0xEE8D9C,alpha) setFill]; [path fill];
}

@interface PetRenderer ()
@property NSDictionary<NSString *,NSImage *> *sprites;
@property NSDictionary<NSString *,NSBitmapImageRep *> *bitmaps;
@property NSRect lastImageRect;
@property NSAffineTransform *lastTransform;
@property NSString *lastSprite;
@end

@implementation PetRenderer
- (instancetype)initWithDirectory:(NSString *)directory {
    if ((self = [super init])) {
        NSMutableDictionary *images = [NSMutableDictionary dictionary];
        NSMutableDictionary *bitmaps = [NSMutableDictionary dictionary];
        for (NSString *name in @[@"sit",@"tilt",@"sleep",@"jump",@"run-a",@"run-b",@"roll",@"lie",@"poop",@"pee",@"back",@"paw"]) {
            NSString *path = [directory stringByAppendingPathComponent:[name stringByAppendingString:@".png"]];
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
            if (image) {
                images[name] = image;
                bitmaps[name] = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:path]];
            }
        }
        _sprites = images; _bitmaps = bitmaps;
    }
    return self;
}
- (NSRect)drawInRect:(NSRect)rect action:(PetAction)action time:(double)t
             facing:(BOOL)left gaze:(NSPoint)gaze held:(BOOL)held effects:(BOOL)effects {
    CGFloat unit = rect.size.width/300.;
    CGFloat ground = rect.origin.y + 24*unit;
    CGFloat cx = NSMidX(rect);
    CGFloat lift = 0, angle = 0, sx = 1, sy = 1;
    NSString *name = held ? @"jump" : PetSpriteName(action,t);
    NSImage *image = self.sprites[name];
    BOOL wide = [@[@"sleep",@"roll",@"lie",@"run-a",@"run-b"] containsObject:name];
    CGFloat maxWidth = (wide ? 217 : 192)*unit, maxHeight = 203*unit;
    CGFloat scale = MIN(maxWidth/image.size.width, maxHeight/image.size.height);
    NSSize size = NSMakeSize(image.size.width*scale,image.size.height*scale);
    if (action == PetIdle || action == PetLove || action == PetPaw) {
        sy = 1 + .012*sin(t*2.5);
        angle = gaze.x * 2.2 + sin(t*.9)*.7;
    } else if (PetMoving(action)) {
        lift = fabs(sin(t*(action == PetWalk ? 7 : 13)))*9*unit;
        angle = sin(t*13)*2;
    } else if (action == PetSleep) {
        sy = 1+.025*sin(t*1.8);
    } else if (action == PetJump) {
        double cycle = fmod(t,1.2)/1.2;
        lift = pow(MAX(0,sin(cycle*M_PI)),1.3)*66*unit;
        sx = 1-.055*sin(cycle*M_PI); sy = 1+.065*sin(cycle*M_PI);
    } else if (action == PetSpin) {
        sx = .65+.35*fabs(cos(t*M_PI*1.5)); lift = 5*unit*fabs(sin(t*7));
        left = ((NSInteger)(t*5)%4 == 3);
    } else if (action == PetRoll) {
        angle = 32*sin(t*3.5); lift = 13*unit;
    } else if (action == PetFlip) {
        if (t<1.5) { angle = 180*sin((t/1.5)*M_PI/2); lift = 36*unit*sin((t/1.5)*M_PI); }
    } else if (action == PetPoop) {
        sy = .97+.025*sin(t*7);
    } else if (action == PetEat) {
        angle = 3*sin(t*8); sy = 1+.02*sin(t*8);
    }
    if (held) { lift = 24*unit; angle = sin(t*5)*9; }
    if (effects && !held) {
        NSRect shadow = NSMakeRect(cx-64*unit,ground-3*unit,128*unit,14*unit);
        CGFloat shrink = 1-lift/(250*unit);
        shadow = NSInsetRect(shadow,(1-shrink)*shadow.size.width/2,0);
        [Color(0x1C2730,.12 * (1-lift/(180*unit))) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:shadow] fill];
    }
    NSRect imageRect = NSMakeRect(-size.width/2,0,size.width,size.height);
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:cx yBy:ground+lift];
    // Rotate around the puppy's middle so rolling stays inside the transparent window.
    [transform translateXBy:0 yBy:size.height*.45];
    [transform rotateByDegrees:angle];
    [transform scaleXBy:(left ? -sx : sx) yBy:sy];
    [transform translateXBy:0 yBy:-size.height*.45];
    [NSGraphicsContext saveGraphicsState];
    [transform concat];
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
    BOOL wag=[name isEqualToString:@"sit"] || [name isEqualToString:@"tilt"];
    if(wag) {
        NSRect tail=NSMakeRect(-size.width/2, size.height*.055,size.width*.205,size.height*.23);
        [NSGraphicsContext saveGraphicsState];
        NSBezierPath *clip=[NSBezierPath bezierPathWithRect:imageRect];
        [clip appendBezierPathWithRect:tail]; clip.windingRule=NSWindingRuleEvenOdd; [clip addClip];
        [image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:nil];
        [NSGraphicsContext restoreGraphicsState];
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *wagTransform=[NSAffineTransform transform];
        CGFloat jointX=NSMaxX(tail),jointY=NSMidY(tail);
        [wagTransform translateXBy:jointX yBy:jointY];
        [wagTransform rotateByDegrees:sin(t*9)*9];
        [wagTransform translateXBy:-jointX yBy:-jointY]; [wagTransform concat];
        [[NSBezierPath bezierPathWithRect:NSInsetRect(tail,-1,-1)] addClip];
        [image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:nil];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1
           respectFlipped:NO hints:nil];
    }
    // A short, occasional blink; eyelids inherit the same body transform.
    double blink=fmod(t+1.1,4.8);
    if([name isEqualToString:@"sit"] && blink>4.60) {
        CGFloat opacity=MIN(1,MIN((blink-4.60)/.05,(4.8-blink)/.05));
        CGFloat eyeX[]={.35,.665},eyeY[]={.722,.764};
        for(int i=0;i<2;i++) {
            NSRect lid=NSMakeRect(-size.width/2+size.width*(eyeX[i]-.048),size.height*(eyeY[i]-.034),
                                 size.width*.096,size.height*.068);
            [Color(0x302A2D,opacity) setFill]; [[NSBezierPath bezierPathWithOvalInRect:lid] fill];
            NSBezierPath *lash=[NSBezierPath bezierPath];
            [lash moveToPoint:NSMakePoint(NSMinX(lid)+2*unit,NSMidY(lid))];
            [lash curveToPoint:NSMakePoint(NSMaxX(lid)-2*unit,NSMidY(lid))
                controlPoint1:NSMakePoint(NSMidX(lid)-3*unit,NSMidY(lid)-3*unit)
                controlPoint2:NSMakePoint(NSMidX(lid)+3*unit,NSMidY(lid)-3*unit)];
            lash.lineWidth=1.1*unit; [Color(0x131418,opacity) setStroke]; [lash stroke];
        }
    }
    [NSGraphicsContext restoreGraphicsState];
    self.lastImageRect = imageRect; self.lastTransform = transform; self.lastSprite = name;

    if (effects && action == PetSleep) {
        for (int i=0; i<3; i++) {
            double phase = fmod(t*.4+i*.32,1.);
            Text(i==0?@"z":@"Z",NSMakePoint(cx+46*unit+phase*28*unit,ground+75*unit+phase*70*unit),
                 (13+phase*9)*unit,Color(0x8A99BB,1-phase));
        }
    }
    if (effects && (action == PetLove || action == PetPaw)) {
        for (int i=0;i<3;i++) {
            double phase = fmod(t*.45+i*.33,1.);
            Heart(NSMakePoint(cx+(i-1)*64*unit+sin(t*2+i)*9*unit,
                              ground+size.height*.55+phase*80*unit), (13+5*phase)*unit,1-phase);
        }
    }
    if (effects && action == PetEat) {
        // Small biscuit, progressively nibbled away.
        NSRect biscuit = NSMakeRect(cx+27*unit,ground+4*unit,24*unit*(1-.6*MIN(t/4.2,1)),14*unit);
        [Color(0xCE9556,1) setFill]; [[NSBezierPath bezierPathWithRoundedRect:biscuit xRadius:5*unit yRadius:5*unit] fill];
        for(int i=0;i<3;i++) {
            [Color(0x95663F,1) setFill];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(biscuit.origin.x+(5+i*5)*unit,ground+9*unit,2*unit,2*unit)] fill];
        }
    }
    if (effects && action == PetPoop && t>2.1) {
        CGFloat x = cx+80*unit;
        [Color(0xAF8262,.95) setFill];
        for(int i=0;i<3;i++) {
            NSRect r = NSMakeRect(x+4*i*unit,ground+(2+i*7)*unit,(26-8*i)*unit,10*unit);
            [[NSBezierPath bezierPathWithRoundedRect:r xRadius:5*unit yRadius:5*unit] fill];
        }
        Text(@"✦",NSMakePoint(x+27*unit,ground+14*unit),13*unit,Color(0xE4BE77,.9));
    }
    if (effects && action == PetPee && t>1.3 && t<4.1) {
        [Color(0xEBC96B,.5) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx+65*unit,ground+1*unit,30*unit,6*unit)] fill];
        for(int i=0;i<4;i++) {
            double phase = fmod(t*1.8+i*.25,1);
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(cx+(55+phase*24)*unit,ground+(29*(1-phase))*unit,3*unit,4*unit)] fill];
        }
    }
    return NSMakeRect(cx-size.width/2,ground+lift,size.width,size.height);
}
- (BOOL)opaqueAtPoint:(NSPoint)point rect:(NSRect)rect action:(PetAction)action time:(double)time facing:(BOOL)left {
    if (!self.lastTransform) return NO;
    NSAffineTransform *inverse = [self.lastTransform copy]; [inverse invert];
    NSPoint p = [inverse transformPoint:point];
    NSRect r = self.lastImageRect;
    if (!NSPointInRect(p,r)) return NO;
    NSBitmapImageRep *bitmap = self.bitmaps[self.lastSprite];
    NSInteger x = (p.x-r.origin.x)/r.size.width*bitmap.pixelsWide;
    NSInteger y = (1-(p.y-r.origin.y)/r.size.height)*bitmap.pixelsHigh;
    x = MAX(0,MIN(bitmap.pixelsWide-1,x)); y=MAX(0,MIN(bitmap.pixelsHigh-1,y));
    return [[bitmap colorAtX:x y:y] alphaComponent] > .12;
}
@end
