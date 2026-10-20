#import <Cocoa/Cocoa.h>

// The atlas is sliced without repainting or replacing its generated alpha.
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 3) { fprintf(stderr, "prepare-assets ATLAS OUTPUT_DIR\n"); return 1; }
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfFile:@(argv[1])]];
        if (!rep) return 2;
        NSArray *names = @[@"sit", @"tilt", @"sleep", @"jump", @"run-a", @"run-b",
                           @"roll", @"lie", @"poop", @"pee", @"back", @"paw"];
        // Generated poses are not perfectly aligned to cell boundaries. Extract
        // their connected alpha regions instead of cutting a neighbor's ears off.
        int width=(int)rep.pixelsWide, height=(int)rep.pixelsHigh;
        unsigned char *mask=calloc(width*height,1);
        int *queue=malloc(width*height*sizeof(int));
        NSInteger totalTransparent=0;
        for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
            CGFloat alpha=[[rep colorAtX:x y:y] alphaComponent];
            mask[y*width+x]=alpha>.06;
            if(alpha<.01) totalTransparent++;
        }
        NSMutableArray<NSDictionary *> *components=[NSMutableArray array];
        for(int index=0;index<width*height;index++) {
            if(!mask[index]) continue;
            int start=0,end=1;queue[0]=index;mask[index]=0;
            int minX=width,maxX=0,minY=height,maxY=0;
            while(start<end) {
                int p=queue[start++],x=p%width,y=p/width;
                minX=MIN(minX,x);maxX=MAX(maxX,x);minY=MIN(minY,y);maxY=MAX(maxY,y);
                for(int dy=-1;dy<=1;dy++) for(int dx=-1;dx<=1;dx++) {
                    int nx=x+dx,ny=y+dy;
                    if(nx<0||nx>=width||ny<0||ny>=height) continue;
                    int next=ny*width+nx;
                    if(mask[next]) {mask[next]=0;queue[end++]=next;}
                }
            }
            if(end>3000) [components addObject:@{@"x":@(minX),@"y":@(minY),@"r":@(maxX),@"b":@(maxY),@"size":@(end)}];
        }
        free(mask);free(queue);
        if(components.count!=12) {fprintf(stderr,"Expected 12 sprites, got %lu\n",components.count);return 3;}
        [components sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
            return @(([a[@"y"] intValue]+[a[@"b"] intValue])/2).intValue <
                   @(([b[@"y"] intValue]+[b[@"b"] intValue])/2).intValue ? NSOrderedAscending:NSOrderedDescending;
        }];
        NSMutableArray *ordered=[NSMutableArray array];
        for(int row=0;row<3;row++) {
            NSArray *group=[[components subarrayWithRange:NSMakeRange(row*4,4)] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
                return [a[@"x"] compare:b[@"x"]];
            }];
            [ordered addObjectsFromArray:group];
        }
        for (int index=0;index<12;index++) {
            NSDictionary *part=ordered[index];
            NSInteger minX=MAX(0,[part[@"x"] intValue]-3),minY=MAX(0,[part[@"y"] intValue]-3);
            NSInteger maxX=MIN(width-1,[part[@"r"] intValue]+3),maxY=MIN(height-1,[part[@"b"] intValue]+3);
            CGImageRef crop = CGImageCreateWithImageInRect(rep.CGImage,
                CGRectMake(minX, minY, maxX-minX+1, maxY-minY+1));
            NSBitmapImageRep *out = [[NSBitmapImageRep alloc] initWithCGImage:crop];
            NSString *path = [@(argv[2]) stringByAppendingPathComponent:[names[index] stringByAppendingString:@".png"]];
            [[out representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
            printf("%s %ld×%ld\n", [names[index] UTF8String], out.pixelsWide, out.pixelsHigh);
            CGImageRelease(crop);
        }
        printf("Fully transparent atlas pixels: %ld\n", totalTransparent);
        return totalTransparent < 10000 ? 4 : 0;
    }
}
