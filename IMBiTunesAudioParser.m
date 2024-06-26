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


// Author: Peter Baumgartner

// Note: Maybe we could put something like CorePasteboardFlavorType 0x6974756E on the pasteboard for metadata?

//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBiTunesAudioParser.h"
#import "IMBConfig.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import <iMedia/IMBObject.h>
#import "IMBIconCache.h"
#import "NSDictionary+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBTimecodeTransformer.h"
#import "NSURL+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBiTunesAudioParser ()

@property (retain) NSDictionary* atomic_plist;

- (NSString*) identifierWithPersistentID:(NSString*)inPersistentID;
- (BOOL) shoudlUsePlaylist:(NSDictionary*)inPlaylistDict;
- (BOOL) shouldUseTrack:(NSDictionary*)inTrackDict;
- (BOOL) isLeafPlaylist:(NSDictionary*)inPlaylistDict;
- (NSImage*) iconForPlaylist:(NSDictionary*)inPlaylistDict;
- (void) addSubnodesToNode:(IMBNode*)inParentNode playlists:(NSArray*)inPlaylists tracks:(NSDictionary*)inTracks;
- (void) populateNode:(IMBNode*)inNode playlists:(NSArray*)inPlaylists tracks:(NSDictionary*)inTracks;
- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiTunesAudioParser

@synthesize appPath = _appPath;
@synthesize atomic_plist = _plist;
@synthesize modificationDate = _modificationDate;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize version = _version;
@synthesize timecodeTransformer = _timecodeTransformer;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.version = 0;
		self.timecodeTransformer = [[[IMBTimecodeTransformer alloc] init] autorelease];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_plist);
	IMBRelease(_modificationDate);
	IMBRelease(_timecodeTransformer);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	NSString* path = [self.mediaSource path];

	NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];
	[icon setSize:NSMakeSize(16.0,16.0)];
	
	// Create an empty (unpopulated) root node...
	
	IMBNode* node = [[[IMBNode alloc] initWithParser:self topLevel:YES] autorelease];
	node.icon = icon;
	node.name = @"iTunes";
	node.identifier = [self identifierForPath:@"/"];
	node.groupType = kIMBGroupTypeLibrary;
	node.isLeafNode = NO;

	// If we have more than one library then append the library name to the root node...
	
	if (self.shouldDisplayLibraryName)
	{
		NSString* libraryName = [[[path stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension];
		node.name = [NSString stringWithFormat:@"%@ (%@)",node.name,libraryName];
	}

	// Watch the XML file. Whenever something in iTunes changes, we have to replace the WHOLE tree from  
	// the root node down, as we have no way of finding WHAT has changed in iTunes...
	
	node.watcherType = kIMBWatcherTypeFSEvent;
	node.watchedPath = [path stringByDeletingLastPathComponent];
	
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSDictionary* plist = self.plist;
	NSArray* playlists = [plist objectForKey:@"Playlists"];
	NSDictionary* tracks = [plist objectForKey:@"Tracks"];
	
	[self addSubnodesToNode:inNode playlists:playlists tracks:tracks]; 
	[self populateNode:inNode playlists:playlists tracks:tracks]; 

	// If we are populating the top-level node, then also populate the "Music" node (first subnode) and mirror 
	// its objects array into the objects array of the root node. Please note that this is non-standard parser 
	// behavior, which is implemented here, to achieve the desired "feel" in the browser...
	
    BOOL result = YES;
    
	if (inNode.isTopLevelNode)
	{
		if ([inNode.subnodes count] > 0)
		{
			IMBNode* musicNode = [inNode.subnodes objectAtIndex:0];
			result = [self populateNode:musicNode error:outError];
			inNode.objects = musicNode.objects;
		}
	}
	
	return result;
}


//----------------------------------------------------------------------------------------------------------------------


// Try to get the cover art from directly from the audio file via Quicklook...

- (id) thumbnailForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
	NSURL* url = inObject.URL;
	CGImageRef thumbnail = [url imb_quicklookCGImage];
	if (outError) *outError = error;
	return (id)thumbnail;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return [self bookmarkForLocalFileObject:inObject error:outError];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods

// Load the XML file into a plist lazily (on demand). If we notice that an existing cached plist is out-of-date 
// we get rid of it and load it anew...

- (NSDictionary*) plist
{
	NSURL* url = self.mediaSource;
	
    NSDate* modificationDate;
    if (![url getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:NULL]) modificationDate = nil;
    
	
	@synchronized(self)
	{
		// If for some reason the modification date could not be fetched, or the modification is newer, recache
		if ((modificationDate == nil) || ([self.modificationDate compare:modificationDate] == NSOrderedAscending))
		{
			self.atomic_plist = nil;
		}
		
		if (_plist == nil)
		{
			self.atomic_plist = [NSDictionary dictionaryWithContentsOfURL:url];
			self.modificationDate = modificationDate;
			self.version = [[_plist objectForKey:@"Application Version"] intValue];
		}
	}
	
	return self.atomic_plist;
}


//----------------------------------------------------------------------------------------------------------------------


// This method must return an appropriate prefix for IMBObject identifiers. Refer to the method
// -[IMBParser iMedia2PersistentResourceIdentifierForObject:] to see how it is used. Historically we used class names as the prefix. 
// However, during the evolution of iMedia class names can change and identifier string would thus also change. 
// This is undesirable, as things that depend of the immutability of identifier strings would break. One such 
// example are the object badges, which use object identifiers. To guarrantee backward compatibilty, a parser 
// class must override this method to return a prefix that matches the historic class name...

- (NSString*) iMedia2PersistentResourceIdentifierPrefix
{
	return @"IMBiTunesParser";
}


//----------------------------------------------------------------------------------------------------------------------


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBiPhotoParser://AlbumId/17"...

- (NSString*) identifierWithPersistentID:(NSString*)inPersistentID
{
	NSString* path = [NSString stringWithFormat:@"/PlaylistPersistentID/%@",inPersistentID];
	return [self identifierForPath:path];
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude some playlist types...

- (BOOL) shoudlUsePlaylist:(NSDictionary*)inPlaylistDict
{
	if (inPlaylistDict == nil) return NO;
	
	NSNumber* visible = [inPlaylistDict objectForKey:@"Visible"];
	if (visible!=nil && [visible boolValue]==NO) return NO;
	
	if ([[inPlaylistDict objectForKey:@"Distinguished Kind"] intValue]==26) return NO;	// Genius
	
	if ([self.mediaType isEqualToString:kIMBMediaTypeAudio])
	{
		if ([inPlaylistDict objectForKey:@"Movies"]) return NO;
		if ([inPlaylistDict objectForKey:@"TV Shows"]) return NO;
	}
	else if ([self.mediaType isEqualToString:kIMBMediaTypeMovie])
	{
		if ([inPlaylistDict objectForKey:@"Music"]) return NO;
		if ([inPlaylistDict objectForKey:@"Podcasts"]) return NO;
		if ([inPlaylistDict objectForKey:@"Audiobooks"]) return NO;
		if ([inPlaylistDict objectForKey:@"Purchased Music"]) return NO;
		if ([inPlaylistDict objectForKey:@"Party Shuffle"]) return NO;
	}
	
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Everything except folders is a leaf node...

- (BOOL) isLeafPlaylist:(NSDictionary*)inPlaylistDict
{
	return [inPlaylistDict objectForKey:@"Folder"] == nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) iconForPlaylist:(NSDictionary*)inPlaylistDict
{
	NSString* filename = nil;
	
	if (_version < 7)
	{
		if ([inPlaylistDict objectForKey:@"Library"])
			filename = @"itunes-icon-library.png";
		else if ([inPlaylistDict objectForKey:@"Movies"])
			filename =  @"itunes-icon-movies.png";
		else if ([inPlaylistDict objectForKey:@"TV Shows"])
			filename =  @"itunes-icon-tvshows.png";
		else if ([inPlaylistDict objectForKey:@"Podcasts"])
			filename =  @"itunes-icon-podcasts.png";
		else if ([inPlaylistDict objectForKey:@"Audiobooks"])
			filename =  @"itunes-icon-audiobooks.png";
		else if ([inPlaylistDict objectForKey:@"Purchased Music"])
			filename =  @"itunes-icon-purchased.png";
		else if ([inPlaylistDict objectForKey:@"Party Shuffle"])
			filename =  @"itunes-icon-partyshuffle.png";
		else if ([inPlaylistDict objectForKey:@"Folder"])
			filename =  @"itunes-icon-folder.png";
		else if ([inPlaylistDict objectForKey:@"Smart Info"])
			filename =  @"itunes-icon-playlist-smart.png";
		else 
			filename =  @"itunes-icon-playlist-normal.png";
	}
	else if (_version < 9)
	{
		if ([inPlaylistDict objectForKey:@"master"])
			filename =  @"itunes-icon-music.png";
		else if ([inPlaylistDict objectForKey:@"Library"])
			filename =  @"itunes-icon-music.png";
		else if ([inPlaylistDict objectForKey:@"Music"])
			filename =  @"itunes-icon-music.png";
		else if ([inPlaylistDict objectForKey:@"Movies"])
			filename =  @"itunes-icon-movies.png";
		else if ([inPlaylistDict objectForKey:@"TV Shows"])
			filename =  @"itunes-icon-tvshows.png";
		else if ([inPlaylistDict objectForKey:@"Podcasts"])
			filename =  @"itunes-icon-podcasts7.png";
		else if ([inPlaylistDict objectForKey:@"Audiobooks"])
			filename =  @"itunes-icon-audiobooks.png";
		else if ([inPlaylistDict objectForKey:@"Purchased Music"])
			filename =  @"itunes-icon-purchased7.png";
		else if ([inPlaylistDict objectForKey:@"Party Shuffle"])
			filename =  @"itunes-icon-partyshuffle7.png";
		else if ([inPlaylistDict objectForKey:@"Folder"])
			filename =  @"itunes-icon-folder7.png";
		else if ([inPlaylistDict objectForKey:@"Smart Info"])
			filename =  @"itunes-icon-playlist-smart7.png";
		else 
			filename =  @"itunes-icon-playlist-normal7.png";
	}
	else if (_version < 10)
	{
		if ([inPlaylistDict objectForKey:@"master"])
			filename =  @"iTunes9-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Library"])
			filename =  @"iTunes9-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Music"])
			filename =  @"iTunes9-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Movies"])
			filename =  @"iTunes9-icon-02.png";
		else if ([inPlaylistDict objectForKey:@"TV Shows"])
			filename =  @"iTunes9-icon-03.png";
		else if ([inPlaylistDict objectForKey:@"Podcasts"])
			filename =  @"iTunes9-icon-04.png";
		else if ([inPlaylistDict objectForKey:@"Audiobooks"])
			filename =  @"iTunes9-icon-06.png";
		else if ([inPlaylistDict objectForKey:@"iTunesU"])
			filename =  @"iTunes9-icon-30.png";
		else if ([inPlaylistDict objectForKey:@"Purchased Music"])
			filename =  @"iTunes9-icon-07.png";
		else if ([inPlaylistDict objectForKey:@"Party Shuffle"])
			filename =  @"iTunes9-icon-18.png";
		else if ([inPlaylistDict objectForKey:@"Folder"])
			filename =  @"iTunes9-icon-19.png";
		else if ([inPlaylistDict objectForKey:@"Smart Info"])
			filename =  @"iTunes9-icon-20.png";
		else 
			filename =  @"iTunes9-icon-21.png";
	}
	else if (_version < 11)
	{
		if ([inPlaylistDict objectForKey:@"master"])
			filename =  @"iTunes10-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Library"])
			filename =  @"iTunes10-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Music"])
			filename =  @"iTunes10-icon-01.png";
		else if ([inPlaylistDict objectForKey:@"Movies"])
			filename =  @"iTunes10-icon-02.png";
		else if ([inPlaylistDict objectForKey:@"TV Shows"])
			filename =  @"iTunes10-icon-03.png";
		else if ([inPlaylistDict objectForKey:@"Podcasts"])
			filename =  @"iTunes10-icon-04.png";
		else if ([inPlaylistDict objectForKey:@"Audiobooks"])
			filename =  @"iTunes10-icon-06.png";
		else if ([inPlaylistDict objectForKey:@"iTunesU"])
			filename =  @"iTunes10-icon-30.png";
		else if ([inPlaylistDict objectForKey:@"Purchased Music"])
			filename =  @"iTunes10-icon-07.png";
		else if ([inPlaylistDict objectForKey:@"Party Shuffle"])
			filename =  @"iTunes10-icon-18.png";
		else if ([inPlaylistDict objectForKey:@"Folder"])
			filename =  @"iTunes10-icon-19.png";
		else if ([inPlaylistDict objectForKey:@"Smart Info"])
			filename =  @"iTunes10-icon-20.png";
		else 
			filename =  @"iTunes10-icon-21.png";
	}
	else 
	{
		if ([inPlaylistDict objectForKey:@"master"])
			filename =  @"iTunes11-icon-01.tiff";
		else if ([inPlaylistDict objectForKey:@"Library"])
			filename =  @"iTunes11-icon-01.tiff";
		else if ([inPlaylistDict objectForKey:@"Music"])
			filename =  @"iTunes11-icon-01.tiff";
		else if ([inPlaylistDict objectForKey:@"Movies"])
			filename =  @"iTunes11-icon-02.tiff";
		else if ([inPlaylistDict objectForKey:@"TV Shows"])
			filename =  @"iTunes11-icon-03.tiff";
		else if ([inPlaylistDict objectForKey:@"Podcasts"])
			filename =  @"iTunes11-icon-04.tiff";
		else if ([inPlaylistDict objectForKey:@"Audiobooks"])
			filename =  @"iTunes11-icon-06.tiff";
		else if ([inPlaylistDict objectForKey:@"iTunesU"])
			filename =  @"iTunes11-icon-30.tiff";
		else if ([inPlaylistDict objectForKey:@"Purchased Music"])
			filename =  @"iTunes11-icon-07.tiff";
		else if ([inPlaylistDict objectForKey:@"Party Shuffle"])
			filename =  @"iTunes11-icon-18.tiff";
		else if ([inPlaylistDict objectForKey:@"Folder"])
			filename =  @"iTunes11-icon-19.tiff";
		else if ([inPlaylistDict objectForKey:@"Smart Info"])
			filename =  @"iTunes11-icon-20.tiff";
		else 
			filename =  @"iTunes11-icon-21.tiff";
	}
	
	if (filename)
	{
		NSBundle* bundle = [NSBundle bundleForClass:[self class]];
		NSString* path = [bundle pathForResource:filename ofType:nil];
		return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubnodesToNode:(IMBNode*)inParentNode playlists:(NSArray*)inPlaylists tracks:(NSDictionary*)inTracks
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];

	// Now parse the iTunes XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* playlistDict in inPlaylists)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumName = [playlistDict objectForKey:@"Name"];
		NSString* parentID = [playlistDict objectForKey:@"Parent Persistent ID"];
		NSString* parentIdentifier = parentID ? [self identifierWithPersistentID:parentID] : [self identifierForPath:@"/"];
		
		if ([self shoudlUsePlaylist:playlistDict] && [inParentNode.identifier isEqualToString:parentIdentifier])
		{
			// Create node for this album...
			
			IMBNode* playlistNode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			
			playlistNode.isLeafNode = [self isLeafPlaylist:playlistDict];
			playlistNode.icon = [self iconForPlaylist:playlistDict];
			playlistNode.name = albumName;

			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSString* playlistID = [playlistDict objectForKey:@"Playlist Persistent ID"];
			playlistNode.identifier = [self identifierWithPersistentID:playlistID];

			// Add the new album node to its parent (inRootNode)...
			
			[subnodes addObject:playlistNode];
		}
		
		[pool drain];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) populateNode:(IMBNode*)inNode playlists:(NSArray*)inPlaylists tracks:(NSDictionary*)inTracks
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
    
	// Look for the correct playlist in the iTunes XML plist. Once we find it, populate the node with IMBVisualObjects
	// for each song in this playlist...
	
	for (NSDictionary* playlistDict in inPlaylists)
	{
		NSAutoreleasePool* pool1 = [[NSAutoreleasePool alloc] init];
		NSString* playlistID = [playlistDict objectForKey:@"Playlist Persistent ID"];
		NSString* playlistIdentifier = [self identifierWithPersistentID:playlistID];

		if ([inNode.identifier isEqualToString:playlistIdentifier])
		{
			NSArray* trackKeys = [playlistDict objectForKey:@"Playlist Items"];
			NSUInteger index = 0;

			for (NSDictionary* trackID in trackKeys)
			{
				NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];
				NSString* key = [[trackID objectForKey:@"Track ID"] stringValue];
				NSDictionary* trackDict = [inTracks objectForKey:key];
			
				if ([self shouldUseTrack:trackDict])
				{
					// Get name and path to file...
					
					NSString* name = [trackDict objectForKey:@"Name"];
					NSString* location = [trackDict objectForKey:@"Location"];
					NSURL* url = [NSURL URLWithString:location];
					
					// Create an object...
					
					IMBObject* object = [[IMBObject alloc] init];
					[objects addObject:object];
					[object release];

					// For local files path is preferred (as we gain automatic support for some context menu items).
					// For remote files we'll use a URL (less context menu support)...
					
					object.location = url;
                    object.accessibility = [self accessibilityForObject:object];
					object.name = name;
					object.parserIdentifier = self.identifier;
					object.index = index++;
					
					object.imageLocation = (id)url;
					object.imageRepresentationType = IKImageBrowserCGImageRepresentationType; 
					object.imageRepresentation = nil;	// will be loaded lazily when needed

					// Add metadata and convert the duration property to seconds. Also note that the original
					// key "Total Time" is not bindings compatible as it contains a space...
					
					NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:trackDict];
					object.metadata = metadata;
					
					double duration = [[trackDict objectForKey:@"Total Time"] doubleValue] / 1000.0;
					[metadata setObject:[NSNumber numberWithDouble:duration] forKey:@"duration"]; 
					
					NSString* artist = [trackDict objectForKey:@"Artist"];
					if (artist) [metadata setObject:artist forKey:@"artist"]; 
					
					NSString* album = [trackDict objectForKey:@"Album"];
					if (album) [metadata setObject:album forKey:@"album"]; 
					
					NSString* genre = [trackDict objectForKey:@"Genre"];
					if (genre) [metadata setObject:genre forKey:@"genre"]; 

					NSString* comment = [trackDict objectForKey:@"Comment"];
					if (comment) [metadata setObject:comment forKey:@"comment"]; 
					
					object.metadataDescription = [self metadataDescriptionForMetadata:metadata];
				}
				
				[pool2 drain];
			}
		}
		
		[pool1 drain];
	}
    
    inNode.objects = objects;
}


// Convert metadata into human readable string...

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return [NSDictionary imb_metadataDescriptionForAudioMetadata:inMetadata];
}


//----------------------------------------------------------------------------------------------------------------------


// A track is eligible if it has a name, a url, and if it is not a movie file...

- (BOOL) shouldUseTrack:(NSDictionary*)inTrackDict
{
	if (inTrackDict == nil) return NO;
	if ([inTrackDict objectForKey:@"Name"] == nil) return NO;
	if ([[inTrackDict objectForKey:@"Location"] length] == 0) return NO;
	if ([[inTrackDict objectForKey:@"Has Video"] boolValue] == 1) return NO;
	if (![[inTrackDict objectForKey:@"Location"] hasPrefix:@"file:"]) return NO;
	if ([[inTrackDict objectForKey:@"Location"] hasSuffix:@".m4p"]) return NO;
	
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


@end
