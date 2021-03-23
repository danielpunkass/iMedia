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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


/*
 DISCUSSION: METADATA DESCRIPTION
 
 Metadata descripton is built up on a per-parser basis; see imb_imageMetadataDescriptionForMetadata
 and metadataDescriptionForMetadata for most implementations.
 
 When an attribute is available and appropriate, it is shown; otherwise it is not shown.
 We don't show a "Label: " for the attribute if its context is obvious.
 
 In order to be consistent, this is the expected order that items are shown.  If we wanted to change
 this, we would have to change a bunch of code.
 
 No-Download indicator (Flickr)
 Owner (Flickr)
 Type (Images except for Flickr, Video, not Audio)
 Artist (Audio)
 Album (Audio)
 Width x Height (Image, Video)
 Duration (Audio, Video)
 Date -- NOTE -- THERE ARE PROBABLY SOME PARSERS WHERE I STILL NEED TO INCLUDE THIS
 Comment (when available; file-based parsers should get from Finder comments)
 Tags (Flickr) --  CAN WE GET THESE FOR IPHOTO, OTHERS TOO?
 
 Maybe add License for Flickr, perhaps others from EXIF data?
 */


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import <iMedia/IMBObject.h>
#import "IMBNode.h"
#import <iMedia/IMBParserMessenger.h>
#import "IMBAppleMediaLibraryParserMessenger.h"
#import "IMBCommon.h"
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBObjectFifoCache.h"
#import "IMBParserController.h"
#import "NSString+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSKeyedArchiver+iMedia.h"
#import "IMBSmartFolderObject.h"
#import "IMBConfig.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBObjectPasteboardType = @"com.karelia.imedia.IMBObject";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBObject (FileAccessPrivate)
- (NSURL*) _URLByRequestingAndResolvingBookmark;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObject

@synthesize location = _location;
@synthesize locationBookmark = _locationBookmark;
@synthesize name = _name;
@synthesize identifier = _identifier;
@synthesize persistentResourceIdentifier = _persistentResourceIdentifier;

@synthesize preliminaryMetadata = _preliminaryMetadata;
@synthesize metadata = _metadata;
@synthesize metadataDescription = _metadataDescription;

@synthesize parserIdentifier = _parserIdentifier;
@synthesize parserMessenger = _parserMessenger;
@synthesize error = _error;

@synthesize index = _index;
@synthesize shouldDrawAdornments = _shouldDrawAdornments;
@synthesize shouldDisableTitle = _shouldDisableTitle;
@synthesize accessibility = _accessibility;

@synthesize imageLocation = _imageLocation;
@synthesize atomic_imageRepresentation = _imageRepresentation;
@synthesize imageRepresentationType = _imageRepresentationType;
@synthesize needsImageRepresentation = _needsImageRepresentation;
@synthesize imageVersion = _imageVersion;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Lifetime


- (id) init
{
	if ((self = [super init]))
	{
		_index = NSNotFound;
		_shouldDrawAdornments = YES;
		_shouldDisableTitle = NO;
		_isLoadingThumbnail = NO;
		_accessibility = YES;
		_needsImageRepresentation = YES;
		_imageVersion = 0;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_location);
	IMBRelease(_locationBookmark);
	IMBRelease(_name);
	IMBRelease(_identifier);
	IMBRelease(_persistentResourceIdentifier);
	
	IMBRelease(_preliminaryMetadata);
	IMBRelease(_metadata);
	IMBRelease(_metadataDescription);
	
	IMBRelease(_parserIdentifier);
	IMBRelease(_parserMessenger);
	IMBRelease(_error);
	
	IMBRelease(_imageLocation);
	IMBRelease(_imageRepresentation);
	IMBRelease(_imageRepresentationType);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	NSKeyedUnarchiver* coder = (NSKeyedUnarchiver*)inCoder;
	
	if ((self = [super init]))
	{
		self.location = [coder decodeObjectForKey:@"location"];
		self.locationBookmark = [coder decodeObjectForKey:@"locationBookmark"];
		self.name = [coder decodeObjectForKey:@"name"];
		self.identifier = [coder decodeObjectForKey:@"identifier"];
		self.persistentResourceIdentifier = [coder decodeObjectForKey:@"persistentResourceIdentifier"];
		self.error = [inCoder decodeObjectForKey:@"error"];

		self.preliminaryMetadata = [coder decodeObjectForKey:@"preliminaryMetadata"];
		self.metadata = [coder decodeObjectForKey:@"metadata"];
		self.metadataDescription = [coder decodeObjectForKey:@"metadataDescription"];
		self.parserIdentifier = [coder decodeObjectForKey:@"parserIdentifier"];

		self.index = (NSUInteger)[coder decodeInt64ForKey:@"index"];
		self.shouldDrawAdornments = [coder decodeBoolForKey:@"shouldDrawAdornments"];
		self.shouldDisableTitle = [coder decodeBoolForKey:@"shouldDisableTitle"];
		self.accessibility = (IMBResourceAccessibility)[coder decodeInt64ForKey:@"accessibility"];
		
		self.imageLocation = [coder decodeObjectForKey:@"imageLocation"];
		self.imageRepresentationType = [coder decodeObjectForKey:@"imageRepresentationType"];
		self.needsImageRepresentation = [coder decodeBoolForKey:@"needsImageRepresentation"];
		self.imageVersion = (NSUInteger)[coder decodeInt64ForKey:@"imageVersion"];

		if ([self.imageRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType])
		{
			self.atomic_imageRepresentation = (id)[coder decodeCGImageForKey:@"imageRepresentation"];
		}
		else
		{
			self.atomic_imageRepresentation = [coder decodeObjectForKey:@"imageRepresentation"];
		}
	}
	
//    if (!self.imageLocation) {
//        NSLog(@"Image location was not set on decoding of object: %@ !!!!!!", self.name);
//    }
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	NSKeyedArchiver* coder = (NSKeyedArchiver*)inCoder;
	
	[coder encodeObject:self.location forKey:@"location"];
	[coder encodeObject:self.locationBookmark forKey:@"locationBookmark"];
	[coder encodeObject:self.name forKey:@"name"];
	[coder encodeObject:self.identifier forKey:@"identifier"];
	[coder encodeObject:self.persistentResourceIdentifier forKey:@"persistentResourceIdentifier"];
	[coder encodeObject:self.error forKey:@"error"];

	[coder encodeObject:self.preliminaryMetadata forKey:@"preliminaryMetadata"];
	[coder encodeObject:self.metadata forKey:@"metadata"];
	[coder encodeObject:self.metadataDescription forKey:@"metadataDescription"];
	[coder encodeObject:self.parserIdentifier forKey:@"parserIdentifier"];

	int64_t index = (int64_t)self.index; [coder encodeInt64:index forKey:@"index"];
	[coder encodeBool:self.shouldDrawAdornments forKey:@"shouldDrawAdornments"];
	[coder encodeBool:self.shouldDisableTitle forKey:@"shouldDisableTitle"];
	int64_t accessibility = (int64_t)self.accessibility;
    [coder encodeInt64:accessibility forKey:@"accessibility"];

	[coder encodeObject:self.imageLocation forKey:@"imageLocation"];
	[coder encodeObject:self.imageRepresentationType forKey:@"imageRepresentationType"];
	[coder encodeBool:self.needsImageRepresentation forKey:@"needsImageRepresentation"];
	int64_t imageVersion = (int64_t)self.imageVersion; [coder encodeInteger:imageVersion forKey:@"imageVersion"];

	if (self.atomic_imageRepresentation)
	{
		if ([self.imageRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType])
		{
			[coder encodeCGImage:(CGImageRef)self.atomic_imageRepresentation forKey:@"imageRepresentation"];
		}
		else
		{
			[coder encodeObject:self.atomic_imageRepresentation forKey:@"imageRepresentation"];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObject* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.location = self.location;
	copy.locationBookmark = self.locationBookmark;
	copy.name = self.name;
	copy.identifier = self.identifier;
	copy.persistentResourceIdentifier = self.persistentResourceIdentifier;
	copy.error = self.error;

	copy.preliminaryMetadata = self.preliminaryMetadata;
	copy.metadata = self.metadata;
	copy.metadataDescription = self.metadataDescription;

	copy.parserIdentifier = self.parserIdentifier;
	copy.parserMessenger = self.parserMessenger;
	
    copy.index = self.index;
	copy.shouldDrawAdornments = self.shouldDrawAdornments;
	copy.shouldDisableTitle = self.shouldDisableTitle;
	copy.accessibility = self.accessibility;

	copy.imageLocation = self.imageLocation;
	copy.atomic_imageRepresentation = self.atomic_imageRepresentation;
	copy.imageRepresentationType = self.imageRepresentationType;
	copy.needsImageRepresentation = self.needsImageRepresentation;
	copy.imageVersion = self.imageVersion;
	
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


// Convert location to url...

- (NSURL*) URL
{
	return _location;
}


//----------------------------------------------------------------------------------------------------------------------


// Since an object may or may not point to a local file we have to assume that we are dealing with a remote file. 
// For this reason we may have to use the file extension to guess the uti of the object. Obviously this can fail 
// if we do not have an extension, or if we are not dealing with files or urls at all, e.g. with image capture 
// objects...

- (NSString*) type
{
	NSString* uti = nil;
	NSURL *url = [self URL];
	NSString* extension = [url pathExtension];
		
	if ([url isFileURL])
	{
		uti = [NSString imb_UTIForFileAtPath:[url path]];
	}
	else if (extension != nil)
	{
		uti = [NSString imb_UTIForFilenameExtension:extension];
	}

	if (uti != nil && [NSString imb_doesUTI:uti conformsToUTI:(NSString*)kUTTypeAliasFile])
	{
		url = [url imb_URLByResolvingSymlinksAndBookmarkFilesInPath];
		uti = (url ? [NSString imb_UTIForFileAtPath:[url path]] : nil);
	}
	
	return uti;
}


//----------------------------------------------------------------------------------------------------------------------


// Convenience accessor for the mediaType...

- (NSString*) mediaType
{
	return self.parserMessenger.mediaType;
}

					
//----------------------------------------------------------------------------------------------------------------------

/**
 Returns the receiver's .imageRepresentation in canonical NSImage format.
 */
- (NSImage *)thumbnail
{
	NSImage* result = nil;

	// While we haven't loaded an image representation yet, faithfully report that
    if ([self imageRepresentation] != nil)
	{
		result = [NSImage imageWithIMBImageItem:self];

		// Last resort: use the item's icon
		if (result == nil)
		{
			result = self.icon;
		}
	}

	return result;
}


// Return a small generic icon for this file. This icon is displayed in the list view...

- (NSImage*) icon
{
	NSImage* icon = nil;
	
	if (self.imageRepresentationType == IKImageBrowserNSImageRepresentationType)
	{
		icon = self.imageRepresentation;
	}
	else if ([[self URL] isFileURL])
	{
		NSString* iconType = self.type;
		if (iconType != nil)
		{
			icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFileType:iconType];
		}
	}
	
	return icon;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) description
{
	return self.identifier;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) tooltipString
{
	NSString* name = [self name];
	NSString* description = [self metadataDescription];
	
	NSMutableString* tooltip = [NSMutableString string];
	
	if (name && ![name isEqualToString:@""])
	{
		if (tooltip.length > 0) [tooltip imb_appendNewline];
		[tooltip appendFormat:@"%@",name];
	}
	
	if (description && ![description isEqualToString:@""])
	{
		if (tooltip.length > 0) [tooltip imb_appendNewline];
		[tooltip appendFormat:@"%@",description];
	}
	
	return tooltip;
}


- (NSString*) view:(NSView*)inView stringForToolTip:(NSToolTipTag)inTag point:(NSPoint)inPoint userData:(void*)inUserData
{
	return [self tooltipString];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserItem Protocol


// Return a unique identifier for IKImageBrowserView...

- (NSString*) imageUID
{
    return self.identifier;
}


// When this method is called we assume that the object is about to be displayed. 
// So this could be a  possible hook for lazily loading thumbnail and metadata...

- (id) imageRepresentation
{
	if (self.needsImageRepresentation)
	{
		[self loadThumbnail];
	}
	
	return [[_imageRepresentation retain] autorelease];
}

- (void) setImageRepresentation:(id)inImageRepresentation
{
	self.atomic_imageRepresentation = inImageRepresentation;
}


// The name of the object will be used as the title in the icon view and tables...

- (NSString*) imageTitle
{
	NSString* name = self.name;
	
	if (name==nil || [name isEqualToString:@""])
	{
		name = NSLocalizedStringWithDefaultValue(
			@"IMBObject.untitled",
			nil,
			IMBBundle(),
			@"untitled",
			@"placeholder for untitled image");
	}
	
	return name;
}


// May be overridden by subclasses...

- (BOOL) isSelectable 
{
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Override simple accessor - also return YES if no actual image rep data...

- (BOOL) needsImageRepresentation	
{
	return _needsImageRepresentation || (_imageRepresentation == nil);
}


// Can this object be dragged from the iMediaBrowser?

- (BOOL) isDraggable
{
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Convert imageLocation to url...

- (NSURL*) imageLocationURL
{
	NSURL* url = nil;
	
	if ([_imageLocation isKindOfClass:[NSURL class]])
	{
		url = (NSURL*)_imageLocation;
	}
	else if ([_imageLocation isKindOfClass:[NSString class]])
	{
		url = [NSURL fileURLWithPath:(NSString*)_imageLocation];
	}
	
	return url;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSPasteboard Protocols

- (void) pasteboard:(NSPasteboard*)inPasteboard item:(NSPasteboardItem*)inItem provideDataForType:(NSString*)inType
{
	// If we want a URL, we need to request the bookmark and resolve it, or the sandbox will interfere...
	
	if ((self.accessibility == kIMBResourceIsAccessible) && [inType isEqualToString:(NSString*)kUTTypeFileURL])
	{
        NSURL* url = [self _URLByRequestingAndResolvingBookmark];
        if (url) [inItem setString:[url absoluteString] forType:(NSString*)kUTTypeFileURL];
	}
	
	// using 'public.bookmark' instead kUTTypeBookmark, which is not available before 10.10
    else if ([inType isEqualToString:@"public.bookmark"])
    {
        [self requestBookmarkWithError:nil];    // Ensures bookmark is set
        [inItem setData:self.locationBookmark forType:@"public.bookmark"];
    }
    
	// For IMBObjects simply use self...
	
    else if ([inType isEqualToString:(NSString*)kIMBObjectPasteboardType])
	{
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];
		[inItem setData:data forType:(NSString*)kIMBObjectPasteboardType];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QLPreviewItem Protocol


- (NSURL*) previewItemURL
{
	if (self.accessibility == kIMBResourceIsAccessible || self.accessibility == kIMBResourceIsAccessibleSecurityScoped)
	{
        return [self _URLByRequestingAndResolvingBookmark];
	}
	
	return nil;
}


- (NSString*) previewItemTitle
{
	return self.name;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Lazy Loading

@implementation IMBObject (LazyLoading)


//----------------------------------------------------------------------------------------------------------------------


// Store the imageRepresentation and add this object to the fifo cache. Older objects get bumped out off cache 
// and are thus unloaded. Please note that missing thumbnails will be replaced with a generic image
// (which will possibly change the object's image representation type!).

- (void) storeReceivedImageRepresentation:(id)inImageRepresentation
{
    NSString* defaultThumbnailName = @"missing-thumbnail.jpg";

	self.imageRepresentation = inImageRepresentation;
	
	if (inImageRepresentation)
	{
		[IMBObjectFifoCache addObject:self];
	}
	else
	{
		self.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
		self.imageRepresentation = [NSImage imb_imageNamed:defaultThumbnailName];
	}
//    NSAssert(self.imageRepresentation != nil, @"Thumbnail not set on media object. Must be at least set to \"%@\"", defaultThumbnailName);
    
    // Getting here the image representation must have been updated
    self.imageVersion = _imageVersion + 1;
    self.needsImageRepresentation = NO;
}


// If the image representation isn't available yet, then trigger asynchronous loading. When the results come in,
// copy the properties from the incoming object. Do not replace the old object here, as that would unecessarily
// upset the NSArrayController. Redrawing of the view will be triggered automatically...

- (void) loadThumbnail
{
	if ([IMBConfig suspendBackgroundTasks]) return;

	if (self.needsImageRepresentation && !self.isLoadingThumbnail)
	{
		_isLoadingThumbnail = YES;
		
		IMBParserMessenger* messenger = self.parserMessenger;
		SBPerformSelectorAsync(messenger.connection,
                               messenger,
                               @selector(loadThumbnailAndMetadataForObject:error:),
                               self,
                               dispatch_get_main_queue(),
		
			^(IMBObject* inPopulatedObject,NSError* inError)
			{
				if (inError)
				{
					NSLog(@"%s Error trying to load thumbnail of IMBObject %@ (%@)",__FUNCTION__,self.name,inError);
                    
                    self.accessibility = kIMBResourceDoesNotExist;
					self.error = inError;
				}
				else {
					self.error = inPopulatedObject.error;
				}
				
                self.accessibility = inPopulatedObject.accessibility;
                self.imageRepresentationType = inPopulatedObject.imageRepresentationType;
                [self storeReceivedImageRepresentation:inPopulatedObject.atomic_imageRepresentation];
                if (self.metadata == nil) self.metadata = inPopulatedObject.metadata;
                if (self.metadataDescription == nil) self.metadataDescription = inPopulatedObject.metadataDescription;
                _isLoadingThumbnail = NO;
			});
	}
}


// Unload the imageRepresentation to save some memory...

- (void) unloadThumbnail
{
	self.imageRepresentation = nil;
}


- (BOOL) isLoadingThumbnail
{
	return _isLoadingThumbnail;
}


//----------------------------------------------------------------------------------------------------------------------


// This method load metadata only. It is useful for the list view, which doesn't display any thumbnails. The
// icon and combo view need bath thumbnail and metadata, so they should use the loadThumbnail method instead...

- (void) loadMetadata
{
	if ([IMBConfig suspendBackgroundTasks]) return;

	if (self.metadata == nil && !self.isLoadingThumbnail)
	{
		IMBParserMessenger* messenger = self.parserMessenger;
		SBPerformSelectorAsync(messenger.connection,
                               messenger,
                               @selector(loadMetadataForObject:error:),
                               self,
                               dispatch_get_main_queue(),
		
			^(IMBObject* inPopulatedObject,NSError* inError)
			{
				if (inError)
				{
					NSLog(@"%s Error trying to load metadata of IMBObject %@ (%@)",__FUNCTION__,self.name,inError);
				}
				else
				{
					self.metadata = inPopulatedObject.metadata;
					self.metadataDescription = inPopulatedObject.metadataDescription;
				}
			});
	}
}


// Unload the metadata to save some memory...

- (void) unloadMetadata
{
	self.metadata = nil;
}


//----------------------------------------------------------------------------------------------------------------------


//- (void) postProcessLocalURL:(NSURL*)localURL
//{
//	// For overriding by subclass
//}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark File Access

@implementation IMBObject (FileAccess)

/**
 @abstract
 Asynchronously requests a bookmark for self and sets it within self.
 Submits the completion block to the provided queue.
 
 @discussion
 If the bookmark is already stored with self calls the completion block synchronously.
 */
- (void) requestBookmarkWithQueue:(dispatch_queue_t)inQueue completionBlock:(void(^)(NSError*))inCompletionBlock
{
	if (self.locationBookmark == nil)
	{
		void (^completionBlock)(NSError*) = [inCompletionBlock copy];
		IMBParserMessenger* messenger = self.parserMessenger;
		
		SBPerformSelectorAsync(messenger.connection,
                               messenger,
                               @selector(bookmarkForObject:error:),
                               self,
                               inQueue,
		
			^(NSData* inBookmark,NSError* inError)
			{
				if (inError)
				{
					NSLog(@"%s Error trying to load bookmark of IMBObject %@ (%@)",__FUNCTION__,self.name,inError);
				}
				else
				{
					self.locationBookmark = inBookmark;
				}
				
				completionBlock(inError);
				[completionBlock release];
			});
	}
	else
	{
		inCompletionBlock(nil);
	}
}

/**
 @abstract
 Asynchronously requests a bookmark for self and sets it within self.
 Submits the completion block to the main queue.
 
 @discussion
 If the bookmark is already stored with self calls the completion block synchronously.
 
 @see
 requestBookmarkWithQueue:completionBlock:
 */
- (void) requestBookmarkWithCompletionBlock:(void (^)(NSError *))inCompletionBlock
{
    [self requestBookmarkWithQueue:dispatch_get_main_queue() completionBlock:inCompletionBlock];
}

/**
 Synchronous version of -requestBookmarkWithQueue:completionBlock:.
 
 @discussion Will not request bookmark (and return NO) from Apple media library parser for any node object (IMBNodeObject) if request was posted synchronously on main thread (would block main thread indefinitely)
 @see requestBookmarkWithQueue:completionBlock:
 */
- (BOOL)requestBookmarkWithError:(NSError **)outError
{
    // FIXME: No bookmark from Apple media library parser for node object if request was posted synchronously on main thread (would block main thread indefinitely)
    if ([NSThread isMainThread] &&
        [self isKindOfClass:[IMBNodeObject class]] &&
        [self.parserMessenger isKindOfClass:[IMBAppleMediaLibraryParserMessenger class]]) {
        return NO;
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = YES;
    
    [self requestBookmarkWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0)
                   completionBlock:^(NSError* inError)
     {
         if (inError) {
             success = NO;
             if (outError) *outError = inError;
         }
         dispatch_semaphore_signal(semaphore);
     }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_release(semaphore);
    return success;
}



//----------------------------------------------------------------------------------------------------------------------


// Resolve the bookmark and return a URL that we can access in the host application...

- (NSURL*) URLByResolvingBookmark
{
	NSError* error = nil;
	BOOL isStale = NO;
	NSURL* url = nil;
	
	if (self.locationBookmark)
	{
        NSURLBookmarkResolutionOptions options = self.accessibility == kIMBResourceIsAccessibleSecurityScoped ? NSURLBookmarkResolutionWithSecurityScope : 0;
        url = [NSURL
               URLByResolvingBookmarkData:self.locationBookmark
               options:options
               relativeToURL:nil
               bookmarkDataIsStale:&isStale
               error:&error];
	}
	
	return url;
}


//----------------------------------------------------------------------------------------------------------------------


/**
 Returns the same value as locationBookmark property. Method kept for backward compatibility.
 */
- (NSData*) bookmark
{
	return self.locationBookmark;
}


//----------------------------------------------------------------------------------------------------------------------


@end

@implementation IMBObject (FileAccessPrivate)

// Request bookmark if it is not set and resolve it to its corresponding URL.

- (NSURL*) _URLByRequestingAndResolvingBookmark
{
    if ([self requestBookmarkWithError:nil]) {
        return [self URLByResolvingBookmark];
    }
    return nil;
}

@end
