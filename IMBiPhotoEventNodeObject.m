/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------

#import "IMBiPhotoEventNodeObject.h"
#import "IMBiPhotoParser.h"
#import <iMedia/IMBParserMessenger.h>

@interface IMBiPhotoEventNodeObject ()

@property(retain) NSString *currentImageKey;

@end


@implementation IMBiPhotoEventNodeObject

@synthesize currentImageKey = _currentImageKey;


#pragma mark - Lifecycle


- (void) dealloc
{
	IMBRelease(_currentImageKey);

	[super dealloc];
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.currentImageKey = [inCoder decodeObjectForKey:@"currentImageKey"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	
	[inCoder encodeObject:self.currentImageKey forKey:@"currentImageKey"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBiPhotoEventNodeObject* copy = [super copyWithZone:inZone];
	
	copy.currentImageKey = self.currentImageKey;
	return copy;
}


#pragma mark - IMBSkimmableObject must subclass


- (void) setCurrentSkimmingIndex:(NSUInteger)currentSkimmingIndex
{
    [super setCurrentSkimmingIndex:currentSkimmingIndex];
    
	NSArray* keyList = [self.preliminaryMetadata objectForKey:@"KeyList"];
	
    if (currentSkimmingIndex < keyList.count)
    {
        // We are currently skimming on the image
        
        self.currentImageKey = [keyList objectAtIndex:currentSkimmingIndex];
    } else {
        // We just initialized the object or left the image while skimming and thus restore the key image
        
        self.currentImageKey = [self.preliminaryMetadata objectForKey:@"KeyPhotoKey"];
    }
}


// Returns a sparse copy of self that carrys just enough data to load its thumbnail.
// Self must have a current image key set because copy cannot provide thumbnail otherwise.
//
- (IMBSkimmableObject *)thumbnailProvider
{
    // Copy must have a current image key set to be able to provide thumbnail
    NSAssert1(self.currentImageKey != nil, @"Must set current image key on skimmable object %@ before loading thumbnail", self);
    
    IMBiPhotoEventNodeObject *copy = [[[IMBiPhotoEventNodeObject alloc] init] autorelease];
    copy.imageRepresentationType = self.imageRepresentationType;
    copy.currentImageKey = self.currentImageKey;
    copy.parserIdentifier = self.parserIdentifier;
    
    return copy;
}


//----------------------------------------------------------------------------------------------------------------------
// Returns the image location that corresponds to the current skimming index

- (id) imageLocationForCurrentSkimmingIndex
{
	IMBiPhotoParser *parser = (IMBiPhotoParser *)[self.parserMessenger parserWithIdentifier:self.parserIdentifier];
    
    return [NSURL fileURLWithPath:[parser thumbnailPathForImageKey:_currentImageKey] isDirectory:NO];
}


- (NSUInteger) imageCount
{
	return [[self.preliminaryMetadata objectForKey:@"KeyList"] count];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark - Image representation


//----------------------------------------------------------------------------------------------------------------------
// Key image and skimmed images of events are processed by Core Graphics before display

- (CGImageRef) processedImageFromImage:(CGImageRef)inImage
{
	size_t imgWidth = CGImageGetWidth(inImage);
	size_t imgHeight = CGImageGetHeight(inImage);
	size_t squareSize = MIN(imgWidth, imgHeight);
	
	CGContextRef bitmapContext = CGBitmapContextCreate(NULL, 
													   squareSize, 
													   squareSize,
													   8, 
													   4 * squareSize, 
													   CGImageGetColorSpace(inImage),
													   // CGImageAlphaInfo type documented as being safe to pass in as CGBitmapInfo
													   (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	// Fill everything with transparent pixels
	CGRect bounds = CGContextGetClipBoundingBox(bitmapContext);
	CGContextClearRect(bitmapContext, bounds);
	
	// Set clipping path
	CGFloat cornerRadius = squareSize / 10.0;
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
	[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(bounds) xRadius: cornerRadius yRadius:cornerRadius] addClip];
	
	// Move image in context to get desired image area to be in context bounds
	CGRect imageBounds = CGRectMake(((NSInteger)(squareSize - imgWidth)) / 2.0,   // Will be negative or zero
									((NSInteger)(squareSize - imgHeight)) / 2.0,  // Will be negative or zero
									imgWidth, imgHeight);
	
	CGContextDrawImage(bitmapContext, imageBounds, inImage);
	
	CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
    if (image) CFMakeCollectable(image);        // NO-OP if garbage collector is OFF (but appeases static analyzer)
    [(id)image autorelease];
	
	CGContextRelease(bitmapContext);
	
	return image;
}


//----------------------------------------------------------------------------------------------------------------------
// Set a processed image instead of the image provided

- (void) storeReceivedImageRepresentation:(id)inImageRepresentation
{
    if ([self.imageRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType])
    {
//        NSData *data = inImageRepresentation;
//        CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)data,NULL);
//        CGImageRef image = NULL;
//		if (imageSource)
//		{
//			image = CGImageSourceCreateImageAtIndex(imageSource,0,NULL);
//			CFRelease(imageSource);
//		}
//        if (image)
        {
            inImageRepresentation = (id)[self processedImageFromImage:(CGImageRef)inImageRepresentation];
        }
    }
    [super storeReceivedImageRepresentation:inImageRepresentation];
}


// Set a processed image instead of the image provided

//- (void) setQuickLookImage:(CGImageRef)inImage
//{
//	CGImageRef image = NULL;
//	if (inImage)
//	{
//		image = [self processedImageFromImage:inImage];
//		if (image) inImage = image;
//	}
//	
//	[super setQuickLookImage:inImage];
//	
//	if (image) CGImageRelease(image);
//}


@end
