//
//  IMBImageProcessor.m
//  iMedia
//
//  Created by Jörg Jacobsen on 16.04.15.
//
//

#import "IMBImageProcessor.h"
#import "NSImage+iMedia.h"

@implementation IMBImageProcessor

+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

/**
 Returns a trimmed, squared image from the image given.
 @parameter cornerRadius a value between 0 and 255 denoting the percentage of rounding corners (0 = no unrounded, 255 = circle)
 */
- (CGImageRef)CGImageSquaredWithCornerRadius:(CGFloat)cornerRadius fromImage:(CGImageRef)imageRef
{
    size_t imgWidth = CGImageGetWidth(imageRef);
    size_t imgHeight = CGImageGetHeight(imageRef);
    size_t squareSize = MIN(imgWidth, imgHeight);
    
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
                                                       squareSize,
                                                       squareSize,
                                                       8,
                                                       4 * squareSize,
                                                       CGImageGetColorSpace(imageRef),
                                                       // CGImageAlphaInfo type documented as being safe to pass in as CGBitmapInfo
                                                       (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    // Fill everything with transparent pixels
    CGRect bounds = CGContextGetClipBoundingBox(bitmapContext);
    CGContextClearRect(bitmapContext, bounds);
    
    // Set clipping path
    CGFloat absoluteCornerRadius = squareSize / 2 * cornerRadius / 255.0;
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(bounds) xRadius: absoluteCornerRadius yRadius:absoluteCornerRadius] addClip];
    
    // Move image in context to get desired image area to be in context bounds
    CGRect imageBounds = CGRectMake(((NSInteger)(squareSize - imgWidth)) / 2.0,   // Will be negative or zero
                                    ((NSInteger)(squareSize - imgHeight)) / 2.0,  // Will be negative or zero
                                    imgWidth, imgHeight);
    
    CGContextDrawImage(bitmapContext, imageBounds, imageRef);
    
    CGImageRef outImageRef = CGBitmapContextCreateImage(bitmapContext);
    [(id)outImageRef autorelease];
    
    CGContextRelease(bitmapContext);
    
    return outImageRef;
}

/**
 Returns a trimmed, squared image from the image given.
 @parameter cornerRadius a value between 0 and 255 denoting the percentage of rounding corners (0 = no unrounded, 255 = circle)
 */
- (NSImage *)imageSquaredWithCornerRadius:(CGFloat)cornerRadius fromImage:(NSImage *)image
{
    CGImageRef imageSquaredRef = [self CGImageSquaredWithCornerRadius:cornerRadius fromImage:[image imb_CGImage]];
    
    NSSize imageSize = NSMakeSize(CGImageGetWidth(imageSquaredRef), CGImageGetHeight(imageSquaredRef));
    NSImage *imageSquared = [[[NSImage alloc] initWithCGImage: imageSquaredRef size:imageSize] autorelease];
    
    return imageSquared;
}

/**
 @parameter cornerRadius a value between 0 and 255 denoting the percentage of rounding corners (0 = no unrounded, 255 = circle)
 */
- (NSImage *)imageMosaicFromImages:(NSArray *)images withBackgroundImage:(NSImage *)backgroundImage withCornerRadius:(CGFloat)cornerRadius
{
    if ([images count] == 0) {
        return nil;
    }
    
    // Default values
    CGImageRef backgroundImageRef = NULL;
    size_t backgroundWidth = 500.0;
    size_t backgroundHeight = 500.0;
    size_t squareSize = 500.0;
    CGColorSpaceRef colorSpaceRef = nil;
    
    if (backgroundImage) {
        backgroundImageRef = [backgroundImage imb_CGImage];
        colorSpaceRef = CGImageGetColorSpace(backgroundImageRef);
        
        backgroundWidth = CGImageGetWidth(backgroundImageRef);
        backgroundHeight = CGImageGetHeight(backgroundImageRef);
        squareSize = MIN(backgroundWidth, backgroundHeight);
    } else {
        colorSpaceRef = CGImageGetColorSpace([(NSImage *)[images firstObject] imb_CGImage]);
    }
    
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
                                                       squareSize,
                                                       squareSize,
                                                       8,
                                                       4 * squareSize,
                                                       colorSpaceRef,
                                                       // CGImageAlphaInfo type documented as being safe to pass in as CGBitmapInfo
                                                       (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    // Fill everything with transparent pixels
    CGRect bounds = CGContextGetClipBoundingBox(bitmapContext);
    CGContextClearRect(bitmapContext, bounds);
    
    // Set clipping path
    CGFloat absoluteCornerRadius = squareSize / 2 * cornerRadius / 255.0;
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(bounds) xRadius: absoluteCornerRadius yRadius:absoluteCornerRadius] addClip];

    // Move image in context to get desired image area to be in context bounds
    CGRect imageBounds = CGRectMake(((NSInteger)(squareSize - backgroundWidth)) / 2.0,   // Will be negative or zero
                                    ((NSInteger)(squareSize - backgroundHeight)) / 2.0,  // Will be negative or zero
                                    backgroundWidth, backgroundHeight);
    
    if (backgroundImageRef) {
        CGContextDrawImage(bitmapContext, imageBounds, backgroundImageRef);
    }
    
    
    NSInteger rowCount = 3;
    CGFloat marginFactor = 0.1 / 3;
    CGFloat spacingFactor = 0.0145;
    CGFloat margin = bounds.size.width * marginFactor;
    CGFloat spacing = bounds.size.width * spacingFactor;
    CGFloat imageSizeFactor = 1 - (2*marginFactor + (rowCount-1)*spacingFactor);
    CGFloat imageWidth = bounds.size.width / rowCount * imageSizeFactor;
    CGFloat imageHeight = bounds.size.width / rowCount * imageSizeFactor;
    CGFloat initialImageOriginY = margin + (rowCount-1)*imageHeight + (rowCount-1)*spacing;
    
    for (NSInteger row = 0; row < rowCount; row++) {
        for (NSInteger col = 0; col < 3; col++) {
			NSInteger imageIndex = row * rowCount + col;
            
            if (imageIndex >= [images count])  break;
            
            NSImage *image = images[imageIndex];
            CGImageRef squaredImageRef = [self CGImageSquaredWithCornerRadius:0.0 fromImage:[image imb_CGImage]];
            
            // Move image in context to get desired image area to be in context bounds
            CGRect imageBounds = CGRectMake(margin + col*spacing + col*imageWidth,
                                            initialImageOriginY - (row*spacing + row*imageHeight),
                                            imageWidth, imageHeight);
            
            CGContextDrawImage(bitmapContext, imageBounds, squaredImageRef);
        }
    }

    NSImage* imageMosaic = nil;

    CGImageRef imageMosaicRef = CGBitmapContextCreateImage(bitmapContext);
    if (imageMosaicRef != NULL) {
        NSSize imageMosaicSize = NSMakeSize(CGImageGetWidth(imageMosaicRef), CGImageGetHeight(imageMosaicRef));
        imageMosaic = [[[NSImage alloc] initWithCGImage:imageMosaicRef size:imageMosaicSize] autorelease];
        CFRelease(imageMosaicRef);
    }

    CGContextRelease(bitmapContext);

    return imageMosaic;
}

@end
