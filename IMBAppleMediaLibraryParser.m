//
//  IMBAppleMediaLibraryParser.m
//  iMedia
//
//  Created by Jörg Jacobsen on 24.02.15.
//
//

#import "NSObject+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBConfig.h"
#import "IMBIconCache.h"
#import <iMedia/IMBNodeObject.h>
#import "IMBAppleMediaLibraryParser.h"
#import "IMBAppleMediaLibraryPropertySynchronizer.h"
#import "SBUtilities.h"

#define USE_PARSER_ANNOTATED_LIBRARY_NAME 0

// Keep in mind that concurrently creating media objects would require their sorting to date afterwards (niy)
#define CREATE_MEDIA_OBJECTS_CONCURRENTLY 0

#define MEASURE_EXECUTION_TIME 0

#if MEASURE_EXECUTION_TIME
    #define START_MEASURE(id) NSDate *start ## id = [NSDate date]
    #define STOP_MEASURE(id)  NSDate *stop ## id  = [NSDate date]
    #define LOG_MEASURED_TIME(id, ...) NSLog(@"Took %f secs to %@", [stop ## id timeIntervalSinceDate:start ## id], [NSString stringWithFormat: __VA_ARGS__])
#else
    #define START_MEASURE(id)
    #define STOP_MEASURE(id)
    #define LOG_MEASURED_TIME(id, ...)
#endif

NSString *kIMBMLMediaGroupAttributeKeyKeyPhotoKey = @"KeyPhotoKey";
NSString *kIMBMLMediaObjectAttributeKeyOriginalURL = @"originalURL";
NSString *kIMBMLMediaGroupTypeAlbum = @"Album";
NSString *kIMBMLMediaGroupTypeFolder = @"Folder";
NSString *kIMBMLMediaGroupTypeEventsFolder = @"EventsFolder";
NSString *kIMBMLMediaGroupTypeFacesFolder = @"FacesFolder";

@interface IMBAppleMediaLibraryParser ()

@property (assign) BOOL needsMojavePhotoAccessAuthorization;

@end


@implementation IMBAppleMediaLibraryParser

@synthesize AppleMediaLibrary = _AppleMediaLibrary;
@synthesize AppleMediaSource = _AppleMediaSource;
@synthesize configuration = _configuration;
@synthesize needsMojavePhotoAccessAuthorization = _needsMojavePhotoAccessAuthorization;

#pragma mark - Configuration

- (NSString *)identifier
{
    return [self.configuration mediaSourceIdentifier];
}

+ (MLMediaType)MLMediaTypeForIMBMediaType:(NSString *)mediaType
{
    if ([mediaType isEqualToString:kIMBMediaTypeImage]) {
        return MLMediaTypeImage;
    } else if ([mediaType isEqualToString:kIMBMediaTypeMovie]){
        return MLMediaTypeMovie;
    } else if ([mediaType isEqualToString:kIMBMediaTypeAudio]){
        return MLMediaTypeAudio;
    }
    return 0;
}

- (NSString *)mediaType
{
    switch ([self.configuration mediaType]) {
        case MLMediaTypeImage:
            return kIMBMediaTypeImage;
            break;
            
        case MLMediaTypeMovie:
            return kIMBMediaTypeMovie;
            break;
            
        case MLMediaTypeAudio:
            return kIMBMediaTypeAudio;
            break;
            
        default:
            return kIMBMediaTypeImage;
    }
}

/**
 Initializes Apple media library and media source for the receiver.
 @discussion
 Must be called in the initialization process of the receiver but must not be called before configuration of receiver is set.
 */
- (instancetype)initializeMediaLibrary
{
    START_MEASURE(4);
    NSDictionary *libraryOptions = @{MLMediaLoadIncludeSourcesKey : [NSArray arrayWithObject:[self.configuration mediaSourceIdentifier]]};
    self.AppleMediaLibrary = [[MLMediaLibrary alloc] initWithOptions:libraryOptions];
    STOP_MEASURE(4);
    LOG_MEASURED_TIME(4, @"create library object for %@", [self.configuration mediaSourceIdentifier]);
    
    START_MEASURE(5);
    NSDictionary *mediaSources = [IMBAppleMediaLibraryPropertySynchronizer mediaSourcesForMediaLibrary:self.AppleMediaLibrary];
    self.AppleMediaSource = mediaSources[[self.configuration mediaSourceIdentifier]];
    STOP_MEASURE(5);
    LOG_MEASURED_TIME(5, @"create media source for %@", [self.configuration mediaSourceIdentifier]);
    return self;
}

#pragma mark - Mandatory overrides from superclass

/**
 */
- (IMBNode *)unpopulatedTopLevelNode:(NSError **)outError
{
    NSError *error = nil;
    
    // Is there a matching media source?
    
	if (!self.AppleMediaSource) {
		// On macOS Mojave the media source may be missing because the user has denied access to the Photos library
		if ([MLMediaSourcePhotosIdentifier isEqualToString:[self.configuration mediaSourceIdentifier]] && IMBRunningOnMojaveOrNewer()) {
			BOOL photosLibraryExists = NO;

			CFDataRef systemLibraryURLBookmark = NULL;
			CFDictionaryRef wellKnownLibraryPathCache = SBPreferencesCopyAppValue((CFStringRef)@"WellKnownLibraryPathCache",
																				 (CFStringRef)@"com.apple.photolibraryd");

			if (wellKnownLibraryPathCache != NULL) {
				CFDictionaryRef cache = CFDictionaryGetValue(wellKnownLibraryPathCache, CFSTR("cache"));

				if (cache != NULL) {
					systemLibraryURLBookmark = CFDictionaryGetValue(cache, CFSTR("kRDLibraryKey_Canonical"));
				}

				if (systemLibraryURLBookmark != NULL) {
					CFRetain(systemLibraryURLBookmark);
				}

				CFRelease(wellKnownLibraryPathCache);
			}

			if (systemLibraryURLBookmark != NULL) {
				if (CFDataGetTypeID() == CFGetTypeID(systemLibraryURLBookmark)) {
					CFErrorRef resolveError = nil;
					CFURLRef systemLibraryURL = CFURLCreateByResolvingBookmarkData(kCFAllocatorDefault,
																				   systemLibraryURLBookmark,
																				   kCFURLBookmarkResolutionWithoutUIMask,
																				   NULL, NULL, NULL,
																				   &resolveError);

					if (systemLibraryURL != NULL) {
						NSFileManager *fileManager = [NSFileManager defaultManager];
						NSString *systemLibraryPath = [(__bridge NSURL *) systemLibraryURL path];

						if ([fileManager fileExistsAtPath:systemLibraryPath]) {
							photosLibraryExists = YES;
						}

						CFRelease(systemLibraryURL);
					}
					else {
						NSString *resolveErrorString = (NSString*)CFBridgingRelease(CFErrorCopyDescription(resolveError));

						NSLog(@"Could not decode kRDLibraryKey_Canonical value in com.apple.photolibraryd. Error: %@", resolveErrorString);
					}
				}

				self.needsMojavePhotoAccessAuthorization = photosLibraryExists;

				CFRelease(systemLibraryURLBookmark);
			}
		}
		else {
			return nil;
		}
	}

    //  create an empty root node (unpopulated and without subnodes)
    IMBNode *node = [[IMBNode alloc] initWithParser:self topLevel:YES];
    node.name = [self libraryName];
    node.groupType = kIMBGroupTypeLibrary;
    node.icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:[self iconPath]];
    node.isIncludedInPopup = YES;
    node.isLeafNode = NO;
    node.mediaSource = self.mediaSource;
    node.accessibility = self.mediaSource ? [self mediaSourceAccessibility] : kIMBResourceIsAccessible;
    node.isAccessRevocable = NO;
    node.identifier = [self nodeIdentifierForMediaGroupIdentifier:@""]; // Root node solely lives on identifier prefix
    
    if ([self mediaSourceAccessibility] == kIMBResourceIsAccessible) {
        node.watchedPath = [self.mediaSource path];
    }

	if (self.needsMojavePhotoAccessAuthorization) {
		node.accessibility = kIMBResourceNoPermission;
	}

    if (outError) {
        *outError = error;
    }
    return node;
}

- (IMBResourceAccessibility) mediaSourceAccessibility
{
	if ([self needsMojavePhotoAccessAuthorization]) {
		return kIMBResourceNoPermission;
	}

	return [super mediaSourceAccessibility];
}

- (NSError *)mediaSourceAccessibilityError
{
	if ([self needsMojavePhotoAccessAuthorization]) {
		NSString *errorString = NSLocalizedStringWithDefaultValue(@"IMBAppleMediaLibraryParser.Photos.privacyError.placeholderMessage", nil, IMBBundle(), @"IMBAppleMediaLibraryParser.Photos.privacyError.placeholderMessage", nil);

		NSString *recoveryURLLabel = NSLocalizedStringWithDefaultValue(@"IMBAppleMediaLibraryParser.Photos.privacyError.recoveryURLLabel", nil, IMBBundle(), @"IMBAppleMediaLibraryParser.Photos.privacyError.recoveryURLLabel", nil);

		NSURL *recoveryURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"];

		NSDictionary *recoveryURLs = [NSDictionary dictionaryWithObjectsAndKeys:
										 recoveryURL, recoveryURLLabel, nil];

		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  errorString, NSLocalizedDescriptionKey, recoveryURLs, @"recoveryURLs", nil];

		return [NSError errorWithDomain:kIMBErrorDomain code:-1 userInfo:userInfo];
	}

	return [super mediaSourceAccessibilityError];
}

/**
 */
- (BOOL) populateNode:(IMBNode *)inParentNode error:(NSError **)outError
{
    NSError *error = nil;
    START_MEASURE(6);
    MLMediaGroup *parentGroup = [self mediaGroupForNode:inParentNode];
    STOP_MEASURE(6);
    LOG_MEASURED_TIME(6, @"get handle on media group %@", parentGroup.name);
    NSArray *childGroups = [parentGroup childGroups];

    // Create the objects array on demand  - even if turns out to be empty after exiting this method, because without creating an array we would cause an endless loop...
    
    NSMutableArray* objects = [NSMutableArray array];
    
    BOOL shouldUseChildGroupsAsMediaObjects = [self.configuration shouldUseChildGroupsAsMediaObjectsForMediaGroup:parentGroup];
    
    if (!inParentNode.objects && ([childGroups count] == 0 || !shouldUseChildGroupsAsMediaObjects))
    {
        START_MEASURE(1);
        NSArray *mediaObjects = [IMBAppleMediaLibraryPropertySynchronizer mediaObjectsForMediaGroup:parentGroup];
        STOP_MEASURE(1);
        LOG_MEASURED_TIME(1, @"fetch media Objects for group %@", parentGroup.name);

#if CREATE_MEDIA_OBJECTS_CONCURRENTLY
        dispatch_group_t dispatchGroup = dispatch_group_create();
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(8);
#endif
        
        START_MEASURE(2);
        
        for (MLMediaObject *mediaObject in mediaObjects)
        {

#if CREATE_MEDIA_OBJECTS_CONCURRENTLY
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            dispatch_group_async(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#endif
                if ([self shouldUseMediaObject:mediaObject])
                {
                    
                    IMBObject *object = [self objectForMediaObject:mediaObject];
                    
                    @synchronized(objects) {
                        [objects addObject:object];
                    }
                }
#if CREATE_MEDIA_OBJECTS_CONCURRENTLY
                dispatch_semaphore_signal(semaphore);
            });
#endif
        }
#if CREATE_MEDIA_OBJECTS_CONCURRENTLY
        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
        // Only required for 10.7 deployment targets and earlier
        dispatch_release(dispatchGroup);
        dispatch_release(semaphore);
#endif
#endif

		// After loading the objects, update their indices to match their
		// position within the node
		NSInteger nodeIndex = 0;
		for (IMBObject* object in objects) {
			object.index = nodeIndex;
			nodeIndex += 1;
		}
		
        STOP_MEASURE(2);
        LOG_MEASURED_TIME(2, @"create IMBObjects for group %@", parentGroup.name);
    }
    
    NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
    
//    NSLog(@"Group %@ has %zd child groups", parentGroup.name, [childGroups count]);
    
    START_MEASURE(3);
    
    NSUInteger childGroupCount = 0;
    for (MLMediaGroup *mediaGroup in childGroups) {
        childGroupCount++;
        if ([self shouldUseMediaGroup:mediaGroup]) {
            // Create node for this album...
            
            IMBNode *childNode = [self nodeForMediaGroup:mediaGroup parentNode:inParentNode];
            
            // Optimization for subnodes that share the same media objects with their parent node
            
            if ([self shouldReuseMediaObjectsOfParentGroupForGroup:mediaGroup]) {
                childNode.objects = inParentNode.objects;
                [self populateNode:childNode error:&error];
            }
            
            // Add the new album node to its parent (inRootNode)...
            
            [subnodes addObject:childNode];
            
            if (shouldUseChildGroupsAsMediaObjects) {
                [objects addObject:[self nodeObjectForMediaGroup:mediaGroup]];
                
                // Preemptively load media objects for the first 9 groups so that we might get a key photo for those (crazy stuff)
                // (First 9 because these are the subgroup key images used in mosaic image)
                if (childGroupCount <= 9) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0), ^
                                   {
                                       if (!mediaGroup.attributes[kIMBMLMediaGroupAttributeKeyKeyPhotoKey]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-getter-return-value"
                                           mediaGroup.mediaObjects;     // May cause wanted side-effect of enriching media group's attributes dict
#pragma clang diagnostic pop
//                                           NSLog(@"Preemptively fetched media objects for media Group: %@", mediaGroup.name);
                                       }
                                   });
                }
            }
//            NSLog(@"Initializing subgroup: %@ (%@)", [mediaGroup name], [mediaGroup identifier]);
        }
    }
    if (!inParentNode.objects) inParentNode.objects = objects;

    STOP_MEASURE(3);
    LOG_MEASURED_TIME(3, @"create subnodes for group %@", parentGroup.name);
    
    if (*outError) *outError = error;
    return YES;
}

///**
// */
//- (id)thumbnailForObject:(IMBObject *)inObject error:(NSError **)outError
//{
//    NSError *error = nil;
//    NSURL *url = nil;
//    
//    MLMediaObject *mediaObject = [self mediaObjectForObject:inObject];
//    if (inObject.imageLocation)
//    {
//        if ([inObject.imageLocation isKindOfClass:[NSData class]]) {
//            url = [self URLForBookmark:(NSData *)inObject.imageLocation error:&error];
//        } else if ([inObject.imageLocation isKindOfClass:[NSURL class]]) {
//            url = inObject.imageLocation;
//        }
//    } else {
//        url = mediaObject.thumbnailURL;
//        inObject.imageLocation = url;
//    }
//    
//    NSImage *thumbnail = nil;
//    
//    if (url) {
//        NSAssert([inObject.imageRepresentationType isEqualToString:IKImageBrowserNSImageRepresentationType],
//                 @"Unsupported image representation type %@ found in %@. \
//                 Expecting IKImageBrowserNSImageRepresentationType", inObject.imageRepresentationType, inObject);
//        
//        thumbnail = [self.configuration thumbnailForMediaObject:mediaObject];
//     }
//    // Configuration may provide Thumbnail even if base thumbnail is nil
//    if ([self.configuration respondsToSelector:@selector(thumbnailForObject:baseThumbnail:)]) {
//        thumbnail = [self.configuration thumbnailForObject:inObject baseThumbnail:thumbnail];
//    }
//    return thumbnail;
//}

/**
 */
- (id)thumbnailForObject:(IMBObject *)inObject error:(NSError **)outError
{
    NSError *error = nil;
    
    if (*outError) *outError = error;
    
    if ([inObject isKindOfClass:[IMBNodeObject class]]) {
        MLMediaGroup *mediaGroup = [self mediaGroupForNodeObject:(IMBNodeObject *)inObject];
        return [self.configuration thumbnailForMediaGroup:mediaGroup];
    } else {
        MLMediaObject *mediaObject = [self mediaObjectForObject:inObject];
        return [self.configuration thumbnailForMediaObject:mediaObject];
    }
}

/**
 */
- (NSDictionary *)metadataForObject:(IMBObject *)inObject error:(NSError *__autoreleasing *)outError
{
    NSError *error = nil;
    NSDictionary *metadata = @{};
    
    if ([inObject isKindOfClass:[IMBNodeObject class]]) {
        if ([self.configuration respondsToSelector:@selector(metadataForMediaGroup:)])
        {
            MLMediaGroup *mediaGroup = [self mediaGroupForNodeObject:(IMBNodeObject *)inObject];
            metadata = [self.configuration metadataForMediaGroup:mediaGroup];
        }
    } else {
        if ([self.configuration respondsToSelector:@selector(metadataForMediaObject:)])
        {
            MLMediaObject *mediaObject = [self mediaObjectForObject:inObject];
            metadata = [self.configuration metadataForMediaObject:mediaObject];
        }
    }
    if (outError) *outError = error;

    return metadata;
}

/**
 */
- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
    NSError* error = nil;
    
    MLMediaObject *mediaObject = [self mediaObjectForObject:inObject];
    return[self bookmarkForURL:mediaObject.URL error:&error];
}

#pragma mark - Media Group

/**
 Converts an MLMediaLibrary group into iMedia's "native" IMBNode.
 */
- (IMBNode *)nodeForMediaGroup:(MLMediaGroup *)mediaGroup parentNode:(IMBNode *)parentNode
{
    IMBNode* node = [[IMBNode alloc] initWithParser:self topLevel:NO];
    
    node.isLeafNode = [[mediaGroup childGroups] count] == 0;
    
    NSImage *icon = nil, *highlightIcon = nil;
    if ([self.configuration respondsToSelector:@selector(groupIconForTypeIdentifier:highlight:)]) {
        icon = [self.configuration groupIconForTypeIdentifier:mediaGroup.typeIdentifier highlight:NO];
        highlightIcon = [self.configuration groupIconForTypeIdentifier:mediaGroup.typeIdentifier highlight:YES];
        
        if (icon == nil) {
            NSLog(@"Could not custom-load icon image for type identifier: %@ of group: %@. Loading group.icon instead.", mediaGroup.typeIdentifier, mediaGroup.name);
        }
    }
    if (icon == nil) {
        icon = [IMBAppleMediaLibraryPropertySynchronizer iconImageForMediaGroup:mediaGroup];
        
		// Hack: Photos group icons often fail to load on High Sierra
		if ((icon == nil) && [MLMediaSourcePhotosIdentifier isEqualToString:[self.configuration mediaSourceIdentifier]]) {
			NSString *typeIdentifier = mediaGroup.typeIdentifier;

			static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
			{
				// Icon Type,								Application Icon Name,		Fallback Icon Name, 	Alternate Icon Name, 	Alternate Bundle Path
				{@"com.apple.Photos.Album",							@"SidebarAlbum",			nil,					nil,					nil},
				{@"com.apple.Photos.AlbumsGroup",					@"SidebarOverview",			nil,					nil,					nil},
				{@"com.apple.Photos.AllCollectionsGroup",			@"SidebarOverview",			nil,					nil,					nil},
				{@"com.apple.Photos.AllMomentsGroup",				@"SidebarOverview",			nil,					nil,					nil},
				{@"com.apple.Photos.AllPhotosAlbum",				@"SidebarOverview",         nil,                    nil,                    nil},
				{@"com.apple.Photos.AllYearsGroup",         		@"SidebarOverview",         nil,                    nil,                    nil},
                {@"com.apple.Photos.AnimatedGroup",         		@"SidebarGIF",              nil,                    nil,                    nil},
                {@"com.apple.Photos.BurstGroup",            		@"SidebarBursts",           nil,                    nil,                    nil},
				{@"com.apple.Photos.CollectionGroup",				@"SidebarOverview",			nil,					nil,					nil},
                {@"com.apple.Photos.DepthEffectGroup",      		@"SidecarDepth",            nil,                    nil,                    nil},
				{@"com.apple.Photos.FacesAlbum",        			@"SidebarFaces",    	    nil,                    nil,                    nil},
				{@"com.apple.Photos.FavoritesGroup",        		@"SidecarFavorites",        nil,                    nil,                    nil},
                {@"com.apple.Photos.Folder",                		@"SidebarGenericFolder",    nil,                    nil,                    nil},
                {@"com.apple.Photos.FrontCameraGroup",      		@"SidebarSelfies",          nil,                    nil,                    nil},
				{@"com.apple.Photos.LastImportGroup",				@"SidebarLastImport",       nil,                    nil,                    nil},
                {@"com.apple.Photos.LivePhotosGroup",       		@"SidebarLivePhotos",       nil,                    nil,                    nil},
                {@"com.apple.Photos.LongExposureGroup",     		@"SidebarLivePhotos",       nil,                    nil,                    nil},
                {@"com.apple.Photos.MomentGroup",           		@"SidebarMemories",         nil,                    nil,                    nil},
				{@"com.apple.Photos.MyPhotoStream",					@"SidebariCloud",			nil,					nil,					nil},
				{@"com.apple.Photos.PanoramasGroup",				@"SidebarPanoramas",        nil,					nil,					nil},
				{@"com.apple.Photos.PlacesAlbum",					@"SidebarPlaces",			nil,					nil,					nil},
				{@"com.apple.Photos.PlacesCityAlbum",				@"SidebarPlaces",			nil,					nil,					nil},
				{@"com.apple.Photos.PlacesCountryAlbum",			@"SidebarPlaces",			nil,					nil,					nil},
				{@"com.apple.Photos.PlacesPointOfInterestAlbum",	@"SidebarPlaces",			nil,					nil,					nil},
				{@"com.apple.Photos.PlacesProvinceAlbum",			@"SidebarPlaces",			nil,					nil,					nil},
				{@"com.apple.Photos.PublishedAlbum",				@"SidebarAlbum",			nil,					nil,					nil},
				{@"com.apple.Photos.RootGroup",						@"SidebarOverview",			nil,					nil,					nil},
				{@"com.apple.Photos.ScreenshotGroup",				@"SidebarScreenshots",		nil,					nil,					nil},
				{@"com.apple.Photos.SharedGroup",					@"SidebarOverview",			nil,					nil,					nil},
				{@"com.apple.Photos.SharedPhotoStream",				@"SidebariCloud",			nil,					nil,					nil},
				{@"com.apple.Photos.SloMoGroup",					@"SidebarSloMo",			nil,					nil,					nil},
                {@"com.apple.Photos.SmartAlbum",					@"SidebarSmartAlbum",       nil,                    nil,                    nil},
				{@"com.apple.Photos.TimelapseGroup",				@"SidebarTimelapse",		nil,					nil,					nil},
				{@"com.apple.Photos.VideosGroup",					@"SidebarVideos",			nil,					nil,					nil},
				{@"com.apple.Photos.YearGroup",						@"SidebarOverview",			nil,					nil,					nil},

			};

			static const IMBIconTypeMapping kIconTypeMapping =
			{
				sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
				kIconTypeMappingEntries,
				nil
			};

			icon = [[IMBIconCache sharedIconCache] iconForType:typeIdentifier
												  fromBundleID:@"com.apple.Photos"
											  withMappingTable:&kIconTypeMapping
													 highlight:NO
								  considerGenericFallbackImage:NO];
		}
    }
	
    node.icon = icon;
    node.highlightIcon = highlightIcon;
    node.name = [self localizedNameForMediaGroup:mediaGroup];
    node.watchedPath = parentNode.watchedPath;	// These two lines are important to make file watching work for nested
    node.watcherType = kIMBWatcherTypeNone;     // subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
    
    node.identifier = [self nodeIdentifierForMediaGroupIdentifier:mediaGroup.identifier];
    node.attributes = @{ @"type" : [self.configuration typeForMediaGroup:mediaGroup] };
    
    if ([self.configuration respondsToSelector:@selector(countFormatForGroup:plural:)]) {
        node.objectCountFormatSingular = [self.configuration countFormatForGroup:mediaGroup plural:NO];
        node.objectCountFormatPlural = [self.configuration countFormatForGroup:mediaGroup plural:YES];
    }
    
//    NSLog(@"Group with name: %@ has type identifier: %@ and identifier: %@", mediaGroup.name, mediaGroup.typeIdentifier, mediaGroup.identifier);
    
    return node;
}

/**
 */
- (MLMediaGroup *)mediaGroupForNode:(IMBNode *)node
{
    return [self mediaGroupForNodeIdentifier:node.identifier];
}

/**
 */
- (IMBNodeObject *)nodeObjectForMediaGroup:(MLMediaGroup *)mediaGroup
{
    IMBNodeObject* object = [[IMBNodeObject alloc] init];
    object.identifier = [self nodeIdentifierForMediaGroupIdentifier:mediaGroup.identifier];
    object.representedNodeIdentifier = object.identifier;
//    object.location = url;
//    object.imageRepresentation = [IMBAppleMediaLibraryPropertySynchronizer iconImageForMediaGroup:[self mediaGroupForNode:node]];
//    object.needsImageRepresentation = NO;
    object.name = [self localizedNameForMediaGroup:mediaGroup];
    object.metadata = nil;
    object.parserIdentifier = self.identifier;
    object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
//    object.preliminaryMetadata = mediaGroup.attributes;       // We should not need this on the non-XPC side
    
    return object;
}

/**
 Fetches the media group from Apple's media library that corresponds to iMedia's "native" IMBNodeObject.
 */
- (MLMediaGroup *)mediaGroupForNodeObject:(IMBNodeObject *)nodeObject
{
    return [self mediaGroupForNodeIdentifier:nodeObject.representedNodeIdentifier];
}

/**
 Delegates the message to the receiver's parser configuration if it implements it. Otherwise returns YES.
 */
- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup
{
    if ([self.configuration respondsToSelector:@selector(shouldUseMediaGroup:)]) {
        return [self.configuration shouldUseMediaGroup:mediaGroup];
    }
    return YES;
}

/**
 Delegates the message to the receiver's parser configuration if it implements it. Otherwise returns NO.
 */
- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup
{
    if ([self.configuration respondsToSelector:@selector(shouldReuseMediaObjectsOfParentGroupForGroup:)]) {
        return [self.configuration shouldReuseMediaObjectsOfParentGroupForGroup:mediaGroup];
    }
    return NO;
}

/**
 Node identifier is derived from media group identifier by prefixing it with a name space identifier to make it unique throughout all nodes inserted into the outline view.
 */
- (NSString *)nodeIdentifierForMediaGroupIdentifier:(NSString *)mediaGroupIdentifier
{
    NSParameterAssert(mediaGroupIdentifier != nil);
    
    if (mediaGroupIdentifier) {
        NSString *concatenationSeparator = [mediaGroupIdentifier length] > 0 ? @"." : @"";
        return [NSString stringWithFormat:@"%@%@%@", [self identifierPrefix], concatenationSeparator, mediaGroupIdentifier];
    } else {
        NSLog(@"%s: cannot derive node identifier from media group identifier: %@", __FUNCTION__, mediaGroupIdentifier);
        return [self identifierPrefix];
    }
}

/**
 Media group identifier is derived from node identifier by stripping off an identifier prefix that serves as a name space in the context of an outline view where node is inserted into.
 */
- (MLMediaGroup *)mediaGroupForNodeIdentifier:(NSString *)nodeIdentifier
{
    NSInteger mediaGroupIdentifierStartIndex = [[self identifierPrefix] length]+1;  // +1 for concatenation separator
    
    NSString *mediaGroupIdentifier = @"";
    if ([nodeIdentifier validIndex:mediaGroupIdentifierStartIndex])
    {
        mediaGroupIdentifier = [nodeIdentifier substringFromIndex:mediaGroupIdentifierStartIndex];
        return [self.AppleMediaSource mediaGroupForIdentifier:mediaGroupIdentifier];
    } else {
        // Not a valid start index: Node identifier presumably consists only of identifier prefix plus a trailing ".".
        // This must be root media group.
        return [IMBAppleMediaLibraryPropertySynchronizer rootMediaGroupForMediaSource:self.AppleMediaSource];
    }
}

/**
 Returns whether a media group was created automatically by the app that owns the media library (and not by the user).
 */
- (BOOL)nonUserCreatedGroup:(MLMediaGroup *)mediaGroup
{
    return [[self.configuration identifiersOfNonUserCreatedGroups] containsObject:mediaGroup.identifier];
}

/**
 Although a media group's name property returns a localized name for non-user created groups we keep this level of indirection for now for fear of regression since this did not use to work for Apple Photos libraries */
- (NSString *)localizedNameForMediaGroup:(MLMediaGroup *)mediaGroup
{
//    if ([self nonUserCreatedGroup:mediaGroup]) {
//        NSString *localizationKey = [NSString stringWithFormat:@"%@.%@", [self.configuration mediaSourceIdentifier], mediaGroup.identifier];
//        return NSLocalizedStringWithDefaultValue(localizationKey, nil, IMBBundle(), nil, @"Localized string key must match media source identifier concatenated via dot with media group identifier");
//    }
//    else
    {
        return mediaGroup.name;
    }
}

#pragma mark - Media Object

/**
 Converts an MLMediaLibrary object into iMedia's "native" IMBObject.
 */
 - (IMBObject *)objectForMediaObject:(MLMediaObject *)mediaObject
{
    IMBObject *object = [[IMBObject alloc] init];
    
    object.identifier = mediaObject.identifier;
    object.parserIdentifier = [self identifier];
    object.name = [self nameForMediaObject:mediaObject];

    if ([IMBConfig clientAppCanHandleSecurityScopedBookmarks])
    {
        // In this case do not provide URL to framework because it will lose security scope anyway because of encode/decode dance
        object.accessibility = kIMBResourceIsAccessibleSecurityScoped;
    } else {
        object.location = mediaObject.URL;
        object.accessibility = [self accessibilityForObject:object];
    }
// Since the following two operations are expensive we postpone them to the point when we actually need the data
//    object.locationBookmark = [self bookmarkForURL:mediaObject.URL error:&error];
//    object.imageLocation = [self bookmarkForURL:mediaObject.thumbnailURL error:&error];
    
    object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
    object.preliminaryMetadata = mediaObject.attributes;
    
//    NSLog(@"Media object URL: %@", [object location]);
    return object;
}

/**
 Fetches the object from Apple's media library that corresponds to iMedia's "native" IMBObject.
 */
- (MLMediaObject *)mediaObjectForObject:(IMBObject *)object
{
    if ([object isKindOfClass:[IMBNodeObject class]]) {
        IMBNodeObject *nodeObject = (IMBNodeObject *)object;
        MLMediaGroup *mediaGroup = [self mediaGroupForNodeIdentifier:nodeObject.representedNodeIdentifier];
        return [self.configuration keyMediaObjectForMediaGroup:mediaGroup];
    } else {
        return [self.AppleMediaSource mediaObjectForIdentifier:object.identifier];
    }
}

/**
 */
- (BOOL)shouldUseMediaObject:(MLMediaObject *)mediaObject
{
    return ([self.configuration mediaType] == mediaObject.mediaType);
}

/**
 */
- (NSString *)nameForMediaObject:(MLMediaObject *)mediaObject
{
    if (mediaObject.name) {
        return mediaObject.name;
    }
    NSString *originalURL = mediaObject.attributes[kIMBMLMediaObjectAttributeKeyOriginalURL];
    if (originalURL) {
        return [[originalURL lastPathComponent] stringByDeletingPathExtension];
    }
    return [[mediaObject.URL lastPathComponent] stringByDeletingPathExtension];
}

/**
 Returns whether this object is hidden in Photos app (users can hide media objects in Photos app).
 @discussion
 Do not utilize this media object's property since media objects will already be treated by MediaLibrary framework according to their hidden status in Photos app. And hidden objects are not visible in Years/Collections/Moments but visible in albums by default.
 */
- (BOOL)hiddenMediaObject:(MLMediaObject *)mediaObject
{
    return [((NSNumber *)mediaObject.attributes[@"Hidden"]) boolValue];
}

/**
 Returns an identifier for the IMBObject that is valid across app sessions.
 
 Returns nil for IMBNodeObjects since computation of the identifier for those is potentially expensive and
 node objects are not provided to the client app anyhow.
 */
- (NSString *)persistentResourceIdentifierForObject:(IMBObject *)inObject
{
    if ([inObject isKindOfClass:[IMBNodeObject class]]) {
        return nil;
    }
    return [[self mediaObjectForObject:inObject].URL absoluteString];
}

#pragma mark - Utility

/**
 Returns path to app bundle associated with.
 */
- (NSString *) appPath
{
    return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:[self.configuration sourceAppBundleIdentifier]];
}

- (NSString *) iconPath
{
	NSString* identifier = [self.configuration sourceAppBundleIdentifier];
	
	// PB 14.10.2019: This is just a quick hack to get the correct icon for the Music library when running on Catalina.
	// Didn't have the time for proper refactoring of this code.
	if (NSAppKitVersionNumber > 1671.5 && [identifier isEqualToString:@"com.apple.iTunes"])
    {
		identifier = @"com.apple.Music";
    }

    return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
}

/**
 Returns the library name of the receiver or its qualified version.
 @discussion
 Usage of qualified library name is determined via preprocessor switch USE_QUALIFIED_LIBRARY_NAME.
 */
- (NSString *)libraryName
{
    NSString *libraryName = nil;
    if ([self.configuration respondsToSelector:@selector(libraryName)]) {
        libraryName = [self.configuration libraryName];
    } else {
        libraryName = [[NSBundle bundleWithPath:[self appPath]] localizedInfoDictionary][@"CFBundleDisplayName"];
    }
#if USE_PARSER_ANNOTATED_LIBRARY_NAME
    return [NSString stringWithFormat:@"%@ (Apple Media Library)", libraryName];
#else
    return libraryName;
#endif
}

- (NSString *)identifierPrefix
{
    NSString *mediaSourcePath = [self.mediaSource path];
    return mediaSourcePath ? mediaSourcePath : [NSString stringWithFormat:@"%@://%@",
                                                NSStringFromClass([self class]), [self.configuration mediaSourceIdentifier]];
}

/**
 Returns a read-only app-security-scoped bookmark for URL.
 */
- (NSData *)bookmarkForURL:(NSURL *)URL error:(NSError *__autoreleasing *)outError
{
    NSError *error = nil;
    
    [URL startAccessingSecurityScopedResource];
    NSData *bookmark = [URL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:&error];
    [URL stopAccessingSecurityScopedResource];
    
    if (outError) *outError = error;
    return bookmark;
}

/**
 Returns an app-security-scoped URL for bookmark.
 */
- (NSURL *)URLForBookmark:(NSData *)bookmark error:(NSError *__autoreleasing *)outError
{
    NSError *error = nil;
    BOOL stale = NO;
    
    NSURL *URL =[NSURL URLByResolvingBookmarkData:bookmark options:0 relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    
    if (outError) *outError = error;
    return URL;
}
@end
