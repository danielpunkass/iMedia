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
    
    CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
    
    CGContextRelease(bitmapContext);
    
    return image;
}

/**
 Returns a trimmed, squared image from the image given.
 @parameter cornerRadius a value between 0 and 255 denoting the percentage of rounding corners (0 = no unrounded, 255 = circle)
 */
- (NSImage *)imageSquaredWithCornerRadius:(CGFloat)cornerRadius fromImage:(NSImage *)image
{
    CGImageRef imageSquaredRef = [self CGImageSquaredWithCornerRadius:cornerRadius fromImage:[image imb_CGImage]];
    
    NSSize imageSize = NSMakeSize(CGImageGetWidth(imageSquaredRef), CGImageGetHeight(imageSquaredRef));
    NSImage *imageSquared = [[NSImage alloc] initWithCGImage: imageSquaredRef size:imageSize];
    
    CGImageRelease(imageSquaredRef);
    
    return imageSquared;
}

/**
 @parameter cornerRadius a value between 0 and 255 denoting the percentage of rounding corners (0 = no unrounded, 255 = circle)
 */
- (NSImage *)imageMosaicFromImages:(NSArray *)images withBackgroundImage:(NSImage *)backgroundImage withCornerRadius:(CGFloat)cornerRadius
{
    CGImageRef backgroundImageRef = [backgroundImage imb_CGImage];
    size_t backgroundWidth = CGImageGetWidth(backgroundImageRef);
    size_t backgroundHeight = CGImageGetHeight(backgroundImageRef);
    size_t squareSize = MIN(backgroundWidth, backgroundHeight);
    
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
                                                       squareSize,
                                                       squareSize,
                                                       8,
                                                       4 * squareSize,
                                                       CGImageGetColorSpace(backgroundImageRef),
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
    
    CGContextDrawImage(bitmapContext, imageBounds, backgroundImageRef);
    
    
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
            int imageIndex = row * rowCount + col;
            
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
    
    CGImageRef imageMosaicRef = CGBitmapContextCreateImage(bitmapContext);
    
    CGContextRelease(bitmapContext);
    
    NSSize imageMosaicSize = NSMakeSize(CGImageGetWidth(imageMosaicRef), CGImageGetHeight(imageMosaicRef));
    NSImage *imageMosaic = [[NSImage alloc] initWithCGImage:imageMosaicRef size:imageMosaicSize];
    
    CGImageRelease(imageMosaicRef);
    
    return imageMosaic;
}

@end
