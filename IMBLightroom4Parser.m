/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2013 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroom4Parser.h"
#import "IMBLightroomObject.h"
#import "FMDatabase.h"
#import "IMBNode.h"
#import <iMedia/IMBFolderObject.h>
#import <iMedia/IMBObject.h>
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "SBUtilities.h"
#import <Quartz/Quartz.h>
#import <sqlite3.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroom4Parser ()

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroom4Parser


//----------------------------------------------------------------------------------------------------------------------


// Unique identifier for this parser...

+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom4";
}

// The bundle identifier of the Lightroom app this parser is based upon

+ (NSString*) lightroomAppBundleIdentifier
{
    return @"com.adobe.Lightroom4";
}

+ (NSString *)lightroomAppVersion
{
    return @"4";
}

//----------------------------------------------------------------------------------------------------------------------


- (BOOL) checkDatabaseVersion
{
	NSNumber *databaseVersion = [self databaseVersion];
	
	if (databaseVersion != nil) {
		long databaseVersionLong = [databaseVersion longValue];
		
		if (databaseVersionLong < 400020) {
			return NO;
		}
		else if (databaseVersionLong >= 500000) {
			return NO;
		}
        
        return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------

- (FMDatabasePool*) createLibraryDatabasePool
{
	NSString* databasePath = [self.mediaSource path];
	FMDatabasePool* databasePool = [[FMDatabasePool alloc] initWithPath:databasePath flags:SQLITE_OPEN_READONLY vfs:@"unix-none"];

	return [databasePool autorelease];
}

- (FMDatabasePool*) createThumbnailDatabasePool
{
	NSString* mainDatabasePath = [self.mediaSource path];
	NSString* rootPath = [mainDatabasePath stringByDeletingPathExtension];
	NSString* previewPackagePath = [[NSString stringWithFormat:@"%@ Previews", rootPath] stringByAppendingPathExtension:@"lrdata"];
	NSString* previewDatabasePath = [[previewPackagePath stringByAppendingPathComponent:@"previews"] stringByAppendingPathExtension:@"db"];
	FMDatabasePool* databasePool = [[FMDatabasePool alloc] initWithPath:previewDatabasePath flags:SQLITE_OPEN_READONLY vfs:@"unix-none"];

	return [databasePool autorelease];
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
	return @"IMBLightroom3Parser";
}

@end
