//
//  IMBApplePhotosParserConfiguration.m
//  iMedia
//
//  Created by Jörg Jacobsen on 10.03.15.
//
//

#import "IMBApplePhotosParserConfiguration.h"
#import "IMBNodeObject.h"
#import "IMBImageProcessor.h"
#import "NSImage+iMedia.h"
#import "MLMediaGroup+iMedia.h"
#import "IMBAppleMediaLibraryPropertySynchronizer.h"

/**
 Reverse-engineered keys of the Photos app media source's attributes.
 
 Apple doesn't seem to yet publicly define these constants anywhere.
 */
/* Top Level Groups*/
NSString *kIMBPhotosMediaGroupTypeIdentifierRoot =   @"com.apple.Photos.RootGroup";
NSString *kIMBPhotosMediaGroupTypeIdentifierFolder = @"com.apple.Photos.Folder";
NSString *kIMBPhotosMediaGroupTypeIdentifierAlbum =  @"com.apple.Photos.Album";
NSString *kIMBPhotosMediaGroupTypeIdentifierFaces =  @"com.apple.Photos.FacesAlbum";    // Used for Faces and single face

NSString *kIMBPhotosMediaGroupIdentifierMoments = @"AllMomentsGroup";
NSString *kIMBPhotosMediaGroupIdentifierCollections = @"AllCollectionsGroup";
NSString *kIMBPhotosMediaGroupIdentifierYears = @"AllYearsGroup";
NSString *kIMBPhotosMediaGroupIdentifierPlaces = @"allPlacedPhotosAlbum";
NSString *kIMBPhotosMediaGroupIdentifierShared = @"com.apple.Photos.SharedGroup";
NSString *kIMBPhotosMediaGroupIdentifierAlbums = @"TopLevelAlbums";

/* Albums */
NSString *kIMBPhotosMediaGroupIdentifierAllPhotos = @"allPhotosAlbum";
NSString *kIMBPhotosMediaGroupIdentifierPeople= @"peopleAlbum";
NSString *kIMBPhotosMediaGroupIdentifierLastImport = @"lastImportAlbum";
NSString *kIMBPhotosMediaGroupIdentifierFavorites = @"favoritesAlbum";
NSString *kIMBPhotosMediaGroupIdentifierPanoramas = @"panoramaAlbum";
NSString *kIMBPhotosMediaGroupIdentifierVideos = @"videoAlbum";
NSString *kIMBPhotosMediaGroupIdentifierSloMos = @"videoSloMoAlbum";
NSString *kIMBPhotosMediaGroupIdentifierTimelapse = @"videoTimelapseAlbum";
NSString *kIMBPhotosMediaGroupIdentifierBursts = @"burstAlbum";

/**
 Parser configuration factory for Apple Photos app.
 */
IMBMLParserConfigurationFactory IMBMLPhotosParserConfigurationFactory =
^id<IMBAppleMediaLibraryParserDelegate>(MLMediaType mediaType)
{
    NSSet *identifiersOfNonUserCreatedGroups = [NSSet setWithObjects:
                                                kIMBPhotosMediaGroupIdentifierMoments,
                                                kIMBPhotosMediaGroupIdentifierCollections,
                                                kIMBPhotosMediaGroupIdentifierYears,
                                                kIMBPhotosMediaGroupIdentifierPlaces,
                                                kIMBPhotosMediaGroupIdentifierShared,
                                                kIMBPhotosMediaGroupIdentifierAlbums,
                                                
                                                kIMBPhotosMediaGroupIdentifierAllPhotos,
                                                kIMBPhotosMediaGroupIdentifierPeople,
                                                kIMBPhotosMediaGroupIdentifierLastImport,
                                                kIMBPhotosMediaGroupIdentifierFavorites,
                                                kIMBPhotosMediaGroupIdentifierPanoramas,
                                                kIMBPhotosMediaGroupIdentifierVideos,
                                                kIMBPhotosMediaGroupIdentifierSloMos,
                                                kIMBPhotosMediaGroupIdentifierTimelapse,
                                                kIMBPhotosMediaGroupIdentifierBursts,
                                                nil];
    
    
    return [[IMBApplePhotosParserConfiguration alloc] initWithMediaSourceIdentifier:MLMediaSourcePhotosIdentifier
                                                         AppleMediaLibraryMediaType:mediaType
                                                  identifiersOfNonUserCreatedGroups:identifiersOfNonUserCreatedGroups];
};

@implementation IMBApplePhotosParserConfiguration

/**
 */
- (NSDictionary *)metadataForMediaObject:(MLMediaObject *)mediaObject
{
    // Map metadata information from Photos library representation (MLMediaObject.attributes) to iMedia representation
    
    NSDictionary *internalMetadata = mediaObject.attributes;
    NSMutableDictionary* externalMetadata = [NSMutableDictionary dictionary];
    
    // Width, height
    
    NSString *resolutionString = internalMetadata[@"resolutionString"];
    if ([resolutionString isKindOfClass:[NSString class]]) {
        NSSize size = NSSizeFromString(resolutionString);
        externalMetadata[@"width"] = [NSString stringWithFormat:@"%d", (int)size.width];
        externalMetadata[@"height"] = [NSString stringWithFormat:@"%d", (int)size.height];
    }
    
    // Creation date and time
    
    id timeInterval = internalMetadata[@"DateAsTimerInterval"];
    NSString *timeIntervalString = nil;
    if ([timeInterval isKindOfClass:[NSNumber class]]) {
        timeIntervalString = [((NSNumber *)timeInterval) stringValue];
    } else if ([timeInterval isKindOfClass:[NSString class]]) {
        timeIntervalString = timeInterval;
    }
    if (timeIntervalString) {
        externalMetadata[@"dateTime"] = timeIntervalString;
    }
    
    return [NSDictionary dictionaryWithDictionary:externalMetadata];
}

/**
 */
- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *unqualifiedGroupIdentifiers = [NSSet setWithObjects:
                                          kIMBPhotosMediaGroupIdentifierMoments,
                                          kIMBPhotosMediaGroupIdentifierCollections,
                                          nil];
    switch (self.mediaType) {
        case MLMediaTypeImage:
            unqualifiedGroupIdentifiers = [unqualifiedGroupIdentifiers
                                           setByAddingObjectsFromSet:[NSSet setWithObjects:
                                                                      kIMBPhotosMediaGroupIdentifierSloMos,
                                                                      kIMBPhotosMediaGroupIdentifierTimelapse,
                                                                      kIMBPhotosMediaGroupIdentifierVideos,
                                                                      nil]];
            break;
            
        case MLMediaTypeMovie:
            unqualifiedGroupIdentifiers = [unqualifiedGroupIdentifiers
                                           setByAddingObjectsFromSet:[NSSet setWithObjects:
                                                                      kIMBPhotosMediaGroupIdentifierPanoramas,
                                                                      kIMBPhotosMediaGroupIdentifierBursts,
                                                                      nil]];
            break;
            
        default:
            break;
    }
    return (![unqualifiedGroupIdentifiers containsObject:mediaGroup.identifier]);
}

/**
 */
- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet setWithObjects:
                                        kIMBPhotosMediaGroupIdentifierMoments,
                                        kIMBPhotosMediaGroupIdentifierCollections,
                                        kIMBPhotosMediaGroupIdentifierYears,
                                        nil];
    
    return [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
}

/**
 Returns whether group (aka node) is populated with child group objects rather than real media objects.
 */
- (BOOL)shouldUseChildGroupsAsMediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSSet *qualifiedGroupIdentifiers = [NSSet setWithObjects:
                                        kIMBPhotosMediaGroupIdentifierAlbums,
                                        kIMBPhotosMediaGroupIdentifierPeople,
                                        kIMBPhotosMediaGroupIdentifierYears,
                                        nil];
    
    BOOL whiteListed =  [qualifiedGroupIdentifiers containsObject:mediaGroup.identifier];
    
    NSSet *unqualifiedGroupIdentifiers = [NSSet setWithObjects:
                                          kIMBPhotosMediaGroupTypeIdentifierRoot,
                                          nil];
    
    BOOL blackListed =  [unqualifiedGroupIdentifiers containsObject:mediaGroup.typeIdentifier];
    
    return (([[mediaGroup childGroups] count] > 0 && !blackListed) || whiteListed);
}

- (MLMediaObject *)keyMediaObjectForMediaGroup:(MLMediaGroup *)mediaGroup
{
    NSAssert(mediaGroup.identifier != nil, @"Identifier of media group %@ must not be nil",mediaGroup.name);
    
    NSString *keyPhotoKey = mediaGroup.attributes[@"KeyPhotoKey"];
    
    // Gee, was hard to find out that this does the trick to enrich contents of attributes dictionary
    if (!keyPhotoKey) {
        [IMBAppleMediaLibraryPropertySynchronizer mediaObjectsForMediaGroup:mediaGroup];
        mediaGroup = [self.mediaSource mediaGroupForIdentifier:mediaGroup.identifier];
        keyPhotoKey = mediaGroup.attributes[@"KeyPhotoKey"];
    }
    if (keyPhotoKey) {
        return [self.mediaSource mediaObjectForIdentifier:keyPhotoKey];
    } else {
//        NSLog(@"No key photo in media group %@", mediaGroup.attributes);
        
        return [super keyMediaObjectForMediaGroup:mediaGroup];
    }
}

/**
 */
- (NSImage *)thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup
{
    return [self _thumbnailForMediaGroup:mediaGroup mosaic:YES];
}
/**
 */
- (NSImage *)_thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup mosaic:(BOOL)mosaic
{
    if (mediaGroup == nil) {
        NSLog(@"OMG! media group is nil");
    }
    if ([self isEmptyFolderMediaGroup:mediaGroup])
    {
        return [NSImage imb_imageForResource:@"empty_folder" fromAppWithBundleIdentifier:@"com.apple.Photos" fallbackName:nil];
    }
    else if ([self isFolderMediaGroup:mediaGroup] || [self isFacesMediaGroup:mediaGroup])
    {
        NSArray *childGroups = [mediaGroup imb_childGroupsUptoMaxCount:9];  // Square of 3x3
        if (mosaic) {
            NSMutableArray *mosaicThumbnails = [NSMutableArray array];
            for (MLMediaGroup *childGroup in childGroups) {
                NSImage *thumbnail = [self _thumbnailForMediaGroup:childGroup mosaic:NO];
                if (thumbnail) [mosaicThumbnails addObject:thumbnail];
            }
            NSImage *folderBackground = nil;
            if (![self isFacesMediaGroup:mediaGroup]) {
                folderBackground = [NSImage imb_imageForResource:@"folder_background" fromAppWithBundleIdentifier:@"com.apple.Photos" fallbackName:nil];
            }
            return [[IMBImageProcessor sharedInstance] imageMosaicFromImages:mosaicThumbnails withBackgroundImage:folderBackground withCornerRadius:0.0];
        } else {
            return [self _thumbnailForMediaGroup:(MLMediaGroup *)[childGroups firstObject] mosaic:mosaic];
        }
    } else if (mediaGroup != nil) {
        // Media group is not a folder
        
        MLMediaObject *keyMediaObject = [self keyMediaObjectForMediaGroup:mediaGroup];
        
        if (keyMediaObject) {
            NSImage *baseThumbnail = [self thumbnailForMediaObject:keyMediaObject];
            return [self thumbnailForMediaGroup:mediaGroup baseThumbnail:baseThumbnail];
        } else {
            return [NSImage imb_imageForResource:@"empty_album" fromAppWithBundleIdentifier:@"com.apple.Photos" fallbackName:nil];
        }
    }
    return nil;
}

- (NSImage *)thumbnailForObject:(IMBObject *)object baseThumbnail:(NSImage *)thumbnail
{
    if ([object isKindOfClass:[IMBNodeObject class]]) {
        if (thumbnail == nil) {
            NSDictionary *mediaGroupTypeToResourceName =
            @{
              @"com.apple.Photos.Folder" : @"empty_folder",
              @"com.apple.Photos.Album"  : @"empty_album",
              };
            
            NSString *resourceName = mediaGroupTypeToResourceName[object.preliminaryMetadata[@"typeIdentifier"]];
            if (!resourceName) resourceName = @"empty_album";
            
            thumbnail = [NSImage imb_imageForResource:resourceName fromAppWithBundleIdentifier:@"com.apple.Photos" fallbackName:nil];
        }
        NSString *groupTypeIdentifier = object.preliminaryMetadata[@"typeIdentifier"];
        CGFloat cornerRadius = 0;
        if ([groupTypeIdentifier isEqualToString:@"com.apple.Photos.FacesAlbum"]) {
            cornerRadius = 255.0;
        }
        thumbnail = [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:cornerRadius fromImage:thumbnail];
    }
    return thumbnail;
}

- (NSImage *)thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup baseThumbnail:(NSImage *)thumbnail
{
    NSString *groupTypeIdentifier = mediaGroup.typeIdentifier;
    CGFloat cornerRadius = 0;
    if ([groupTypeIdentifier isEqualToString:@"com.apple.Photos.FacesAlbum"]) {
        cornerRadius = 255.0;
    }
    thumbnail = [[IMBImageProcessor sharedInstance] imageSquaredWithCornerRadius:cornerRadius fromImage:thumbnail];
    return thumbnail;
}

- (NSString *)countFormatForGroup: (MLMediaGroup *)mediaGroup plural:(BOOL)plural
{
    NSDictionary *typeIdentifierToLocalizationKey =
    @{
      @"com.apple.Photos.FacesAlbum" : @"IMBFaceObjectViewController.countFormat"
      };
    
    NSString *localizationKey = typeIdentifierToLocalizationKey[mediaGroup.typeIdentifier];
    
    if (localizationKey == nil && [self shouldUseChildGroupsAsMediaObjectsForMediaGroup:mediaGroup]) {
        localizationKey = @"IMBSkimmableObjectViewController.countFormat";
    }
    
    NSString *localizationKeyPostfix = plural ? @"Plural" : @"Singular";
    
    if (localizationKey) {
        localizationKey = [localizationKey stringByAppendingString:localizationKeyPostfix];
        return NSLocalizedStringWithDefaultValue(localizationKey,
                                                 nil, IMBBundle(), nil,
                                                 @"Format string for object count");
    }
    return nil;
}

#pragma mark - Utility

- (BOOL)isFolderMediaGroup:(MLMediaGroup *)mediaGroup
{
    return ([mediaGroup.typeIdentifier isEqualToString:kIMBPhotosMediaGroupTypeIdentifierFolder]);
}

- (BOOL)isFacesMediaGroup:(MLMediaGroup *)mediaGroup
{
    // Rule out all "face" media groups that have the same type as the "faces" media group
    return ([mediaGroup.typeIdentifier isEqualToString:kIMBPhotosMediaGroupTypeIdentifierFaces] &&
            [mediaGroup.childGroups count] > 0);
}

- (BOOL)isEmptyFolderMediaGroup:(MLMediaGroup *)mediaGroup
{
    return ([self isFolderMediaGroup:mediaGroup] && [[mediaGroup childGroups] count] == 0 );
}

- (BOOL)isEmptyButNotFolderMediaGroup:(MLMediaGroup *)mediaGroup
{
    return (![self isFolderMediaGroup:mediaGroup] && [[mediaGroup childGroups] count] == 0 );
}

@end
