//
//  IMBAppleMediaLibraryParser.h
//  iMedia
//
//  Created by Jörg Jacobsen on 24.02.15.
//
//

#import <MediaLibrary/MediaLibrary.h>
#import <iMedia/iMedia.h>

#import <iMedia/IMBParser.h>

typedef NSString IMBMLMediaGroupType;

// Eligible IMBMLMediaGroupType values
extern NSString *kIMBMLMediaGroupTypeAlbum;
extern NSString *kIMBMLMediaGroupTypeFolder;
extern NSString *kIMBMLMediaGroupTypeEventsFolder;
extern NSString *kIMBMLMediaGroupTypeFacesFolder;

#pragma mark -

@protocol IMBAppleMediaLibraryParserDelegate <NSObject>

#pragma mark Mandatory

/**
 */
- (void) setMediaSource:(MLMediaSource *)mediaSource;

/**
 Returns the identifier for the app that is associated with sources handled by the parser. Must be subclassed.
 
 @see MLMediaLibrary media source identifiers
 */
- (NSString *)mediaSourceIdentifier;

/**
 Internal media type is specific to Apple Media Library based parsers and not to be confused with kIMBMediaTypeImage and its siblings.
 */
- (MLMediaType)mediaType;

/**
 Returns the identifier for the app that is associated with sources handled by the parser.
 */
- (NSString *)sourceAppBundleIdentifier;

/**
 Returns a set of group identifiers identifying all groups that were automatically created by the app that owns the media library.
 */
- (NSSet *)identifiersOfNonUserCreatedGroups;

/**
 @return Type of media group provided unified across all possible media sources.
 @discussion Default return value is kIMBMLMediaGroupTypeAlbum.
 */
- (IMBMLMediaGroupType *)typeForMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns whether group (aka node) is populated with child group objects rather than real media objects.
 */
- (BOOL)shouldUseChildGroupsAsMediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 */
- (MLMediaObject *)keyMediaObjectForMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 */
- (NSImage *)thumbnailForMediaObject:(MLMediaObject *)mediaObject;

/**
 */
- (NSImage *)thumbnailForMediaGroup:(MLMediaGroup *)mediaGroup;

#pragma mark Optional

@optional

/**
 @return A thumbnail to be used as the image representation of object.
 @parameter thumbnail The original thumbnail of the media object used by default
 */
- (NSImage *)thumbnailForObject:(IMBObject *)object baseThumbnail:(NSImage *)thumbnail;

/**
 The name of the library used for display.
 @discussion Default is the localized bundle name of the source app.
 @see sourceAppBundleIdentifier
 */
- (NSString *)libraryName;

/**
 Returns the URL denoting the actual media source on disk.
 
 @discussion
 If the URL is not accessible to a concrete parser it may return nil but implications of doing so are not yet fully understood.
 */
- (NSURL *)sourceURLForMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns a dictionary of metadata for mediaObject.
 @discussion Keys must conform to what's used in -...
 */
- (NSDictionary *)metadataForMediaObject:(MLMediaObject *)mediaObject;

/**
 Returns a dictionary of metadata for mediaGroup.
 @discussion Keys must conform to what's used in -...
 */
- (NSDictionary *)metadataForMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns whether a media group should be displayed or not. Default is YES.
 */
- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns whether a media group should reuse the media objects of its parent group or not. Default is No.
 @discussion Reusing media objects may result in substantial performance increase when populating a node.
 */
- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns customized group icon for group type specified by typeIdentifier.
 @discussion
 If you don't implement this method or it returns nil then -[MLMediaGroup icon] will be utilized instead.
 */
- (NSImage *)groupIconForTypeIdentifier:(NSString *)typeIdentifier highlight:(BOOL)highlight;

/**
 */
- (NSString *)countFormatForGroup: (MLMediaGroup *)mediaGroup plural:(BOOL)plural;

@end

#pragma mark -

/**
 Base class for parser classes that access their libraries through Apple's MediaLibrary framework. May be used as is. Must be configured through delegate.
 */
@interface IMBAppleMediaLibraryParser : IMBParser
{
    MLMediaLibrary *_AppleMediaLibrary;
    MLMediaSource *_AppleMediaSource;
    id<IMBAppleMediaLibraryParserDelegate> _configuration;
}

/**
 The root library object (providing possibly multiple media sources from different apps).
 */
@property (strong) MLMediaLibrary *AppleMediaLibrary;

/**
 An MLMediaSource (an app's library) in Apple speak is not a mediaSource (a library's URL) in iMedia speak.
 */
@property (strong) MLMediaSource *AppleMediaSource;

@property (strong) id<IMBAppleMediaLibraryParserDelegate> configuration;

/**
 Initializes Apple media library and media source for the receiver.
 @discussion
 Must be called in the initialization process of the receiver but must not be called before configuration of receiver is set.
 */
- (instancetype)initializeMediaLibrary;

/**
 Converts from IMB media type to Apple Media Library media type.
 */
+ (MLMediaType)MLMediaTypeForIMBMediaType:(NSString *)mediaType;

/**
 Returns whether the node given should be shown in the node hierarchy.
 
 @discussion
 This implementation always returns YES. You are welcome to override in your subclass parser.
 */

- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup;

/**
 Returns whether the group given should use the same media objects as its parent.
 
 @discussion
 This implementation always returns NO. You are welcome to override in your subclass parser (will boost performance).
 */
- (BOOL)shouldReuseMediaObjectsOfParentGroupForGroup:(MLMediaGroup *)mediaGroup;

@end
