//
//  IMBApertureParserConfiguration.m
//  iMedia
//
//  Created by Jörg Jacobsen on 11.03.15.
//
//

#import "IMBApertureParserConfiguration.h"
#import "NSImage+iMedia.h"
#import "IMBIconCache.h"
#import "IMBImageProcessor.h"
#import <iMedia/IMBNodeObject.h>

/**
 Reverse-engineered values of the iPhoto app media group type identifiers.
 
 Apple doesn't seem to yet publicly define these constants anywhere.
 */
NSString *kIMBApertureMediaGroupTypeIdentifierFaces =  @"com.apple.Aperture.FacesAlbum";

/**
 Reverse-engineered keys of the Photos app media source's attributes.
 
 Apple doesn't seem to yet publicly define these constants anywhere.
 */
/* Top Level Groups*/
NSString *kIMBApertureMediaGroupIdentifierAllProjects = @"AllProjectsItem";
NSString *kIMBApertureMediaGroupIdentifierLastViewedEvent = @"eventFilterBarAlbum";
NSString *kIMBApertureMediaGroupIdentifierFaces = @"peopleAlbum";

/**
 Parser configuration factory for Apple iPhoto app.
 */
IMBMLParserConfigurationFactory IMBMLApertureParserConfigurationFactory =
^id<IMBAppleMediaLibraryParserDelegate>(MLMediaType mediaType)
{
    NSSet *identifiersOfNonUserCreatedGroups = [NSSet set];
    
    return [[IMBApertureParserConfiguration alloc] initWithMediaSourceIdentifier:MLMediaSourceApertureIdentifier
                                                    AppleMediaLibraryMediaType:mediaType
                                             identifiersOfNonUserCreatedGroups:identifiersOfNonUserCreatedGroups];
};

@implementation IMBApertureParserConfiguration

/**
 Hardcoded library name.
 */
- (NSString *)libraryName
{
    return @"Aperture";
}

- (NSURL *)sourceURLForMediaGroup:(MLMediaGroup *)mediaGroup
{
    return mediaGroup.attributes[@"URL"];
}

- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *unqualifiedGroupIdentifiers = [NSSet setWithObjects:
                                          kIMBApertureMediaGroupIdentifierAllProjects,
                                          kIMBApertureMediaGroupIdentifierLastViewedEvent,
                                          nil];
    return (![unqualifiedGroupIdentifiers containsObject:mediaGroup.identifier]);
}

- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet set];
    
    return [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
}

/**
 Returns whether group (aka node) is populated with child group objects rather than real media objects.
 @discussion This default implementation returns NO.
 */
- (BOOL)shouldUseChildGroupsAsMediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet setWithObjects:
                                        kIMBApertureMediaGroupIdentifierFaces,
                                        nil];
    
    return [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
}

- (MLMediaObject *)keyMediaObjectForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSString *keyPhotoKey = mediaGroup.attributes[@"KeyPhotoKey"];
    
    if (keyPhotoKey) {
        return [self.mediaSource mediaObjectForIdentifier:keyPhotoKey];
    } else {
        return [super keyMediaObjectForMediaGroup:mediaGroup];
    }
    return nil;
}

- (NSString *)countFormatForGroup:(MLMediaGroup *)mediaGroup plural:(BOOL)plural
{
    NSDictionary *typeIdentifierToLocalizationKey =
    @{
      @"com.apple.Aperture.FacesAlbum" : @"IMBFaceObjectViewController.countFormat"
      };
    
    NSString *localizationKey = typeIdentifierToLocalizationKey[mediaGroup.typeIdentifier];
    NSString *localizationKeyPostfix = plural ? @"Plural" : @"Singular";
    
    if (localizationKey) {
        localizationKey = [localizationKey stringByAppendingString:localizationKeyPostfix];
        return NSLocalizedStringWithDefaultValue(localizationKey,
                                                 nil, IMBBundle(), nil,
                                                 @"Format string for object count");
    }
    return nil;
}

- (NSImage *)groupIconForTypeIdentifier:(NSString *)typeIdentifier highlight:(BOOL)highlight
{
    // Note that for icon types starting with "v3-" we havn't yet found a matching type identifier replacement
    
    static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
    {
        // Icon Type                        Application Icon Name            Fallback Icon Name
        {@"com.apple.Aperture.PhotoStreamAlbum",        @"SL-stream",                   @"folder",	nil,	nil},   // photo stream
        {@"com.apple.Aperture.FacesAlbum",              @"SL-faces",                    @"folder",	nil,	nil},   // faces
        {@"com.apple.Aperture.PlacesAlbum",             @"SL-places",                   @"folder",	nil,	nil},   // faces
        {@"com.apple.Aperture.MonthAlbum",              @"SL-customLast",               @"folder",	nil,	nil},   // faces
        {@"com.apple.Aperture.UserAlbum",               @"SL-album",					@"folder",	nil,	nil},	// album
        {@"com.apple.Aperture.LibraryAlbums",           @"SL-smartAlbum",				@"folder",	nil,	nil},	// smart album
        {@"com.apple.Aperture.UserSmartAlbum",          @"SL-smartAlbum",				@"folder",	nil,	nil},	// library **** ... 200X
        {@"com.apple.Aperture.ProjectAlbum",            @"SL-project",					@"folder",	nil,	nil},	// project
        {@"com.apple.Aperture.LastViewedEvent",         @"SL-project",					@"folder",	nil,	nil},	// project
        {@"com.apple.Aperture.AllProjects",             @"SL-allProjects",				@"folder",	nil,	nil},	// library (top level)
        {@"com.apple.Aperture.FolderAlbum",             @"SL-folder",					@"folder",	nil,	nil},	// folder
        {@"v3-7",	@"SL-folder",					@"folder",	nil,	nil},	// sub-folder of project
        {@"v3-8",	@"SL-book",                     @"folder",	nil,	nil},	// book
        {@"v3-9",	@"SL-webpage",					@"folder",	nil,	nil},	// web gallery
        {@"v3-9",	@"Project_I_WebGallery",		@"folder",	nil,	nil},	// web gallery (alternate image)
        {@"v3-10",	@"SL-webJournal",				@"folder",	nil,	nil},	// web journal
        {@"v3-11",	@"SL-lightTable",				@"folder",	nil,	nil},	// light table
        {@"v3-13",	@"sl-icon-small_webGallery",	@"folder",	nil,	nil},	// smart web gallery
        {@"v3-19",	@"SL-slideshow",				@"folder",	nil,	nil},	// slideshow
        {@"com.apple.Aperture.AllPhotos",               @"SL-photos",					@"folder",	nil,	nil},	// photos
        {@"com.apple.Aperture.Flagged",                 @"SL-flag",						@"folder",	nil,	nil},	// flagged
        {@"v3-96",	@"SL-smartLibrary",             @"folder",	nil,	nil},	// library albums
        {@"v3-97",	@"SL-allProjects",				@"folder",	nil,	nil},	// library
        {@"v3-98",	@"AppIcon.icns",				@"folder",	nil,	nil},	// library
        {@"v3-99",	@"List_Icons_Library",			@"folder",	nil,	nil},	// library (knot holding all images)
        {@"com.apple.Aperture.LastImportAlbum",         @"SL-LastImport",               @"folder",	nil,	nil},	// last import
    };
    static const IMBIconTypeMapping kIconTypeMapping =
    {
        sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
        kIconTypeMappingEntries,
        @"_S"
    };
    
//    // Since icons are different for different versions of Aperture, we are adding the prefix v2- or v3-
//    // to the album type so that we can store different icons (for each version) in the icon cache...
//    
//    NSString* type = [@"v3-" stringByAppendingString:typeIdentifier];
    return [[IMBIconCache sharedIconCache] iconForType:typeIdentifier
                                          fromBundleID:@"com.apple.Aperture"
                                      withMappingTable:&kIconTypeMapping
                                             highlight:highlight
                          considerGenericFallbackImage:NO];
}

- (NSImage *)thumbnailForObject:(IMBObject *)object baseThumbnail:(NSImage *)thumbnail
{
    if ([object isKindOfClass:[IMBNodeObject class]]) {
        NSString *parentGroupIdentifier = object.preliminaryMetadata[@"Parent"];
        if ([parentGroupIdentifier isEqualToString:kIMBApertureMediaGroupIdentifierFaces]) {
            return [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:255 fromImage:thumbnail];
        }
    }
    return thumbnail;
}

/**
 */
- (NSImage *)thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup baseThumbnail:(NSImage *)thumbnail
{
    NSString *groupTypeIdentifier = mediaGroup.typeIdentifier;
    CGFloat cornerRadius = 0;
    if ([groupTypeIdentifier isEqualToString:kIMBApertureMediaGroupTypeIdentifierFaces]) {
        cornerRadius = 255.0;
    }
    thumbnail = [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:cornerRadius fromImage:thumbnail];
    return thumbnail;
}

/**
 */
- (NSImage *)thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup
{
    MLMediaObject *keyMediaObject = [self keyMediaObjectForMediaGroup:mediaGroup];
    
    if (keyMediaObject) {
        NSImage *baseThumbnail = [self thumbnailForMediaObject:keyMediaObject];
        return [self thumbnailForMediaGroup:mediaGroup baseThumbnail:baseThumbnail];
    }
    return nil;
}

@end
