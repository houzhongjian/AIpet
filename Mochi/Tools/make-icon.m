#import <Cocoa/Cocoa.h>
int main(int argc,char **argv) {
    @autoreleasepool {
        if(argc!=3) return 1;
        NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:4096 bitsPerPixel:32];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        [[NSColor colorWithSRGBRed:.89 green:.93 blue:.85 alpha:1] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(45,45,934,934) xRadius:214 yRadius:214] fill];
        [[NSColor colorWithSRGBRed:.78 green:.85 blue:.71 alpha:.45] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(175,108,674,95)] fill];
        NSImage *puppy=[[NSImage alloc] initWithContentsOfFile:@(argv[1])];
        [puppy drawInRect:NSMakeRect(182,128,660,745) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
        [NSGraphicsContext restoreGraphicsState];
        return [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@(argv[2]) atomically:YES] ? 0:2;
    }
}
