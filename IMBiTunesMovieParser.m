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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBiTunesMovieParser.h"
#import "IMBParserController.h"
#import <iMedia/IMBObject.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiTunesMovieParser


//----------------------------------------------------------------------------------------------------------------------


// This method must return an appropriate prefix for IMBObject identifiers. Refer to the method
// -[IMBParser iMedia2PersistentResourceIdentifierForObject:] to see how it is used. Historically we used class names as the prefix. 
// However, during the evolution of iMedia class names can change and identifier string would thus also change. 
// This is undesirable, as things that depend of the immutability of identifier strings would break. One such 
// example are the object badges, which use object identifiers. To guarrantee backward compatibilty, a parser 
// class must override this method to return a prefix that matches the historic class name...

- (NSString*) iMedia2PersistentResourceIdentifierPrefix
{
	return @"IMBiTunesVideoParser";
}


// Exclude some playlist types...

- (BOOL) shoudlUsePlaylist:(NSDictionary*)inPlaylistDict
{
	if (inPlaylistDict == nil) return NO;
	
	NSNumber* visible = [inPlaylistDict objectForKey:@"Visible"];
	if (visible!=nil && [visible boolValue]==NO) return NO;
	
	if ([[inPlaylistDict objectForKey:@"Distinguished Kind"] intValue]==26) return NO;	// Genius
	
	if ([self.mediaType isEqualToString:kIMBMediaTypeMovie])
	{
		if ([inPlaylistDict objectForKey:@"Movies"]) return YES;
		if ([inPlaylistDict objectForKey:@"TV Shows"]) return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// A track is eligible if it has a name, a url, and if it is a video file...

- (BOOL) shouldUseTrack:(NSDictionary*)inTrackDict
{
	if (inTrackDict == nil) return NO;
	if ([inTrackDict objectForKey:@"Name"] == nil) return NO;
	if ([[inTrackDict objectForKey:@"Location"] length] == 0) return NO;
	if ([[inTrackDict objectForKey:@"Has Video"] boolValue] == 0) return NO;
	if ([[inTrackDict objectForKey:@"Protected"] boolValue] == 1) return NO;	
	if (![[inTrackDict objectForKey:@"Location"] hasPrefix:@"file:"]) return NO;
	
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


@end
