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
 
 This file was authored by Dan Wood and Terrence Talbot. 
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX.
 PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
 */


// Author: Unknown


#import "NSString+iMedia.h"
#import "NSFileManager+iMedia.h"
#include <sys/stat.h>


@implementation NSString ( UTI )

//  convert to UTI

+ (NSString *)imb_UTIForFileAtPath:(NSString *)anAbsolutePath
{
	NSString *result = nil;
	NSURL* targetFileURL = [NSURL fileURLWithPath:anAbsolutePath];

	[targetFileURL getResourceValue:&result forKey:NSURLTypeIdentifierKey error:nil];
	return result;
}

+ (NSString *)imb_UTIForFilenameExtension:(NSString *)anExtension
{
	NSString *UTI = nil;
	
	if (anExtension == nil)
	{
		return nil;
	}
	
	if ([anExtension isEqualToString:@"m4v"])
	{
		// Hack, since we already have this UTI defined in the system, I don't think I can add it to the plist.
		UTI = (NSString *)kUTTypeMPEG4;
	}
	else
	{
		CFStringRef cfstr = UTTypeCreatePreferredIdentifierForTag(
																kUTTagClassFilenameExtension,
																(CFStringRef)anExtension,
																NULL
																);
		UTI = [NSMakeCollectable(cfstr) autorelease];
	}
	
	// If we don't find it, add an entry to the info.plist of the APP,
	// along the lines of what is documented here: 
	// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/understand_utis_conc/chapter_2_section_4.html
	// A good starting point for informal ones is:
	// http://www.huw.id.au/code/fileTypeIDs.html
	
	return UTI;
}

+ (NSString *)imb_descriptionForUTI:(NSString *)aUTI;
{
	CFStringRef result = UTTypeCopyDescription((CFStringRef)aUTI);
	return [NSMakeCollectable(result) autorelease];	
}

+ (NSString *)imb_UTIForFileType:(NSString *)aFileType;

{
	CFStringRef result = UTTypeCreatePreferredIdentifierForTag(
															   kUTTagClassOSType,
															   (CFStringRef)aFileType,
															   NULL
															   );
	return [NSMakeCollectable(result) autorelease];	
}

// See list here:
// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html

+ (BOOL) imb_doesUTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI
{
	return UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)aConformsToUTI);
}

+ (BOOL) imb_doesFileAtPath:(NSString*)inPath conformToUTI:(NSString*)inRequiredUTI;
{
	NSString* uti = [NSString imb_UTIForFileAtPath:inPath];
	return (BOOL) UTTypeConformsTo((CFStringRef)uti,(CFStringRef)inRequiredUTI);
}

@end

// This is from cocoadev.com -- public domain

@implementation NSString ( iMedia )


- (BOOL)validIndex:(NSInteger)index
{
    return index < [self length] && index >= 0;
}

// Returns the longest common sub path of self with inPath.
// Paths must be absolute paths.

- (NSString *)imb_commonSubPathWithPath:(NSString *)inPath
{
    if (!inPath || self.length == 0 || inPath.length == 0) return nil;
    
    NSArray *pathComponents1 = [self pathComponents];
    NSArray *pathComponents2 = [inPath pathComponents];
    
    __block NSInteger lastIdenticalComponentNumber = -1;
    
    // Determine last identical component
    
    [pathComponents1 enumerateObjectsUsingBlock:^(id pathComponent1, NSUInteger idx, BOOL *stop) {
        if ([pathComponents2 count] > idx)
        {
            NSString *pathComponent2 = (NSString *)[pathComponents2 objectAtIndex:idx];
            
            if ([pathComponent1 isEqualToString:pathComponent2])
            {
                lastIdenticalComponentNumber = idx;
            } else {
                *stop = YES;
            }
        } else {
            *stop = YES;
        }
    }];
    
    // Create sub path
    
    if (lastIdenticalComponentNumber >= 0)
    {
        NSRange subRange = NSMakeRange(0, lastIdenticalComponentNumber+1);
        NSArray *subPathComponents = [pathComponents1 subarrayWithRange:subRange];
        return [NSString pathWithComponents:subPathComponents];
    }
    return @"/";
}


// Returns whether inPath is a path prefix of self. Both strings must be absolute paths.

- (BOOL)hasPathPrefix:(NSString *)inPath
{
    return [[inPath imb_commonSubPathWithPath:self] isEqualToString:inPath];
}


// Convert a file:// URL (as a string) to just its path
- (NSString *)imb_pathForURLString;
{
	NSString *result = self;
	if ([self hasPrefix:@"file://"])
	{
		NSURL* url = [NSURL URLWithString:self];
		result = [url path];
	}
	return result;
}

// For compatibility with NSURL as in [(NSURL*)stringOrURL path]
- (NSString *)imb_path
{
	return [self imb_pathForURLString];
}

+ (id)uuid
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	return (NSString *)[NSMakeCollectable(uuidStr) autorelease];
}

//- (NSString *)imb_exifDateToLocalizedDisplayDate
//{
//	static NSDateFormatter *parser = nil;
//	static NSDateFormatter *formatter = nil;
//	static NSString* sMutex = @"com.karelia.NSString+iMedia";
//	
//	@synchronized(sMutex)
//	{
//		if (parser == nil)
//		{
//			parser = [[NSDateFormatter alloc] init];
//			[parser setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];
//		}
//		
//		if (formatter == nil)
//		{
//			formatter = [[NSDateFormatter alloc] init];
//			[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
//			[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
//			[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds
//		}
//	}
//	
//	NSDate *date = [parser dateFromString:self];
//	NSString *result = [formatter stringFromDate:date];
//	
//	return result;
//}

// PB 23/07/2010: Commented out the above version of this method and replaced it with the un-optimized version
// below, to avoid multiple crashes in the Release and Test builds. Both use an NSOperationQueue with multiple
// cores, which caused the above method to fail badly, despite the fact that I tried to safeguard it with the 
// @synchronized directive...
// JJ 2012/09/22: Changed method name and adapted to more formats

// Note: This method will return nil if not one of the following formats is met:
//
// @"yyyy':'MM':'dd kk':'mm':'ss"           (EXIF)
// @"yyyy'-'MM'-'dd'T'kk':'mm':'ss'.'SS"    (Lightroom)
// @"yyyy'-'MM'-'dd'T'kk':'mm':'ss"         (Lightroom)
// @"yyyy'-'MM'-'dd'T'kk':'mm':'ss"         (Lightroom)
// @"yyyy'-'MM'-'dd'T'kk':'mm':'ssZ"        (Facebook)

- (NSString *)imb_localizedDisplayDate
{
	NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    
    // Must use a locale compatible with gregorian calendar
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [parser setLocale:locale];
    
    // This is for EXIF-formatted dates
    
	[parser setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];	
	NSDate *date = [parser dateFromString:self];
    
    // This is for Lightroom-formatted dates
    
    if (!date)
    {
        [parser setDateFormat:@"yyyy'-'MM'-'dd'T'kk':'mm':'ss'.'SS"];
        date = [parser dateFromString:self];
    }
    if (!date)
    {
        [parser setDateFormat:@"yyyy'-'MM'-'dd'T'kk':'mm':'ss"];
        date = [parser dateFromString:self];
    }
    
    // This is for Facebook-formatted dates
    
    if (!date)
    {
        [parser setDateFormat:@"yyyy'-'MM'-'dd'T'kk':'mm':'ssZ"];
        date = [parser dateFromString:self];
    }
    
    // This is for self expressed in time interval since 1970
    
    if (!date) {
        NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        f.allowsFloats = YES;
        f.decimalSeparator = @".";
        NSNumber *timeInterval = [f numberFromString:self];
        if ([timeInterval integerValue] > 0) {
            date = [NSDate dateWithTimeIntervalSinceReferenceDate:[timeInterval integerValue]];
        }
    }
    
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterMediumStyle];    // medium date
	[formatter setTimeStyle:NSDateFormatterShortStyle];     // no seconds

	// date should never be nil but clang analyis detects a possibility of
	// nil date if [timeInterval integerValue] above is 0. Let's cover the
	// case explicitly to quiet clang analysis.
	NSString* result = nil;
	if (date != nil)
	{
		result = [formatter stringFromDate:date];
	}

	[formatter release];
	[parser release];
    [locale release];
	
	return result;
}


+ (NSString *)imb_stringFromStarRating:(NSUInteger)aRating;
{
	static unichar blackStars[] = { 0x2605, 0x2605, 0x2605, 0x2605, 0x2605 };
	aRating = MIN((NSUInteger)5,aRating);	// make sure not above 5
	return [NSString stringWithCharacters:blackStars length:aRating];
}

@end

@implementation NSMutableString (iMedia)

- (void)imb_appendNewline;
{
	[self appendString:@"\n"];
}

@end

