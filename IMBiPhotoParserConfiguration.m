//
//  IMBiPhotoParserConfiguration.m
//  iMedia
//
//  Created by Jörg Jacobsen on 10.03.15.
//
//

#import "IMBiPhotoParserConfiguration.h"
#import "IMBAppleMediaLibraryParserMessenger.h"
#import "NSImage+iMedia.h"
#import "IMBIconCache.h"
#import <iMedia/IMBNodeObject.h>
#import "IMBImageProcessor.h"
#import "MLMediaGroup+iMedia.h"

/**
 Reverse-engineered values of the iPhoto app media group type identifiers.
 
 Apple doesn't seem to yet publicly define these constants anywhere.
 */
NSString *kIMBiPhotoMediaGroupTypeIdentifierEvents =  @"com.apple.iPhoto.RollAlbum";
NSString *kIMBiPhotoMediaGroupTypeIdentifierFaces =  @"com.apple.iPhoto.FacesAlbum";

/**
 Attribute keys supported by iPhoto media source (as of OS X 10.10.3)
 */
NSString *kIMBiPhotoMediaGroupIdentifierEvents = @"AllProjectsItem";
NSString *kIMBiPhotoMediaGroupIdentifierPhotos = @"allPhotosAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierFaces = @"peopleAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierPlaces = @"allPlacedPhotosAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierLast12Months = @"lastNMonthsAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierLastImport = @"lastImportAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierFlagged = @"flaggedAlbum";
NSString *kIMBiPhotoMediaGroupIdentifierEventFilterBar = @"eventFilterBarAlbum";

/**
 Parser configuration factory for Apple iPhoto app.
 */
IMBMLParserConfigurationFactory IMBMLiPhotoParserConfigurationFactory =
^id<IMBAppleMediaLibraryParserDelegate>(MLMediaType mediaType)
{
    NSSet *identifiersOfNonUserCreatedGroups = [NSSet setWithObjects:
                                                kIMBiPhotoMediaGroupIdentifierEvents,
                                                kIMBiPhotoMediaGroupIdentifierPhotos,
                                                kIMBiPhotoMediaGroupIdentifierFaces,
                                                kIMBiPhotoMediaGroupIdentifierPlaces,
                                                kIMBiPhotoMediaGroupIdentifierLast12Months,
                                                kIMBiPhotoMediaGroupIdentifierLastImport,
                                                kIMBiPhotoMediaGroupIdentifierFlagged,
                                                nil];
    
    return [[IMBiPhotoParserConfiguration alloc] initWithMediaSourceIdentifier:MLMediaSourceiPhotoIdentifier
                                                               AppleMediaLibraryMediaType:mediaType
                                                        identifiersOfNonUserCreatedGroups:identifiersOfNonUserCreatedGroups];
};

@implementation IMBiPhotoParserConfiguration

/**
 Hardcoded library name.
 */
- (NSString *)libraryName
{
    return @"iPhoto";
}

- (NSURL *)sourceURLForMediaGroup:(MLMediaGroup *)mediaGroup
{
    return mediaGroup.attributes[@"URL"];
}

- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *unqualifiedGroupIdentifiers = [NSSet setWithObjects:
                                          kIMBiPhotoMediaGroupIdentifierEventFilterBar,
                                          nil];
    return (![unqualifiedGroupIdentifiers containsObject:mediaGroup.identifier]);
}

- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet setWithObjects:
//                                        kIMBiPhotoMediaGroupIdentifierEvents,
                                        kIMBiPhotoMediaGroupIdentifierPhotos,
                                        nil];
    
    return [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
}

/**
 Returns whether group (aka node) is populated with child group objects rather than real media objects.
 */
- (BOOL)shouldUseChildGroupsAsMediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet setWithObjects:
                                        kIMBiPhotoMediaGroupIdentifierEvents,
                                        kIMBiPhotoMediaGroupIdentifierFaces,
                                        nil];
    
    return [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
}

/**
 @return Type of media group given unified across all supported media sources.
 */
- (IMBMLMediaGroupType *)typeForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSString *mediaGroupTypeIdentifier = mediaGroup.typeIdentifier;
    
    if ([mediaGroupTypeIdentifier isEqualToString:@"com.apple.iPhoto.EventsFolder"]) {
        return kIMBMLMediaGroupTypeEventsFolder;
    } else if ([mediaGroupTypeIdentifier isEqualToString:@"com.apple.iPhoto.FacesAlbum"]) {
        return kIMBMLMediaGroupTypeFacesFolder;
    }
    return [super typeForMediaGroup:mediaGroup];
}

- (NSString *)countFormatForGroup:(MLMediaGroup *)mediaGroup plural:(BOOL)plural
{
    NSDictionary *typeIdentifierToLocalizationKey =
    @{
      @"com.apple.iPhoto.EventsFolder" : @"IMBiPhotoEventObjectViewController.countFormat"
      ,@"com.apple.iPhoto.FacesAlbum" : @"IMBFaceObjectViewController.countFormat"
      };
    
    NSString *localizationKey = typeIdentifierToLocalizationKey[mediaGroup.typeIdentifier];
    NSString *localizationKeyPostfix = plural ? @"Plural" : @"Singular";
    
    if (localizationKey) {
        localizationKey = [localizationKey stringByAppendingString:localizationKeyPostfix];
        return NSLocalizedStringWithDefaultValue(localizationKey,
                                                 nil, IMBBundle(), nil,
                                                 @"Format string for object count");
    }
    return [super countFormatForGroup:mediaGroup plural:plural];
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

- (NSImage *)groupIconForTypeIdentifier:(NSString *)typeIdentifier highlight:(BOOL)highlight
{
    // Note that for icon types lacking a name space prefix we havn't yet found a matching type identifier replacement
    
    static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
    {
        // Icon Type                Application Icon Name            Fallback Icon Name
        
        {@"Book",					@"sl-icon-small_book",				@"folder",	nil,				nil},
        {@"Calendar",				@"sl-icon-small_calendar",			@"folder",	nil,				nil},
        {@"Card",					@"sl-icon-small_card",				@"folder",	nil,				nil},
        {@"com.apple.iPhoto.RollAlbum",					@"sl-icon-small_events",            @"folder",	nil,				nil},
        {@"com.apple.iPhoto.EventsFolder",              @"sl-icon-small_events",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.FacesAlbum",				@"sl-icon-small_people",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.PlacesAlbum",				@"sl-icon-small_places",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.FlaggedAlbum",				@"sl-icon-small_flag",				@"folder",	nil,				nil},
        {@"com.apple.iPhoto.FacebookProject",			@"sl-icon-small_facebook",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.FolderAlbum",				@"sl-icon-small_folder",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.PhotoStreamAlbum",			@"sl-icon-small_photostream",		@"folder",	nil,				nil},
        {@"Photocasts",				@"sl-icon-small_subscriptions",     @"folder",	nil,				nil},
        {@"com.apple.iPhoto.LibraryAlbum",				@"sl-icon-small_library",			@"folder",	nil,				nil},
        {@"com.apple.iPhoto.Album",                     @"sl-icon-small_album",             @"folder",	nil,				nil},
        {@"Roll",					@"sl-icon-small_roll",				@"folder",	nil,				nil},
        {@"Selected Event Album",	@"sl-icon-small_event",             @"folder",	nil,				nil},
        {@"Shelf",					@"sl-icon_flag",					@"folder",	nil,				nil},
        {@"com.apple.iPhoto.SlideShow",                 @"sl-icon-small_slideshow",         @"folder",	nil,				nil},
        {@"com.apple.iPhoto.SmartAlbum",				@"sl-icon-small_smartAlbum",		@"folder",	nil,				nil},
        {@"com.apple.iPhoto.MonthAlbum",                @"sl-icon-small_cal",				@"folder",	nil,				nil},
        {@"com.apple.iPhoto.SpecialAlbum",              @"sl-icon_lastImport",				@"folder",	nil,				nil},
        {@"Subscribed",				@"sl-icon-small_subscribedAlbum",	@"folder",	nil,				nil}
//        {@"Wildcard",				@"sl-icon-small_album",             @"folder",	nil,				nil}	// fallback image
    };
    
    static const IMBIconTypeMapping kIconTypeMapping =
    {
        sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
        kIconTypeMappingEntries,
        @"-sel"
    };
    
    return [[IMBIconCache sharedIconCache] iconForType:typeIdentifier
                                          fromBundleID:@"com.apple.iPhoto"
                                      withMappingTable:&kIconTypeMapping
                                             highlight:highlight
                          considerGenericFallbackImage:NO];
}

- (NSImage *)thumbnailForObject:(IMBObject *)object baseThumbnail:(NSImage *)thumbnail
{
    if ([object isKindOfClass:[IMBNodeObject class]]) {
        if (thumbnail != nil) {
            NSString *parentGroupIdentifier = object.preliminaryMetadata[@"Parent"];
            if ([parentGroupIdentifier isEqualToString:kIMBiPhotoMediaGroupIdentifierEvents]) {
                return [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:25 fromImage:thumbnail];
            } else if ([parentGroupIdentifier isEqualToString:kIMBiPhotoMediaGroupIdentifierFaces]) {
                return [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:255 fromImage:thumbnail];
            }
        } else {
            NSLog(@"No thumbnail for %@", object);
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
    if ([groupTypeIdentifier isEqualToString:kIMBiPhotoMediaGroupTypeIdentifierFaces]) {
        cornerRadius = 255.0;
    } else if ([groupTypeIdentifier isEqualToString:kIMBiPhotoMediaGroupTypeIdentifierEvents]) {
        cornerRadius = 25.0;
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
