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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import <iMedia/IMBObjectViewController.h>
#import <iMedia/IMBNodeViewController.h>
#import "IMBLibraryController.h"
#import "IMBAccessRightsViewController.h"
#import "IMBConfig.h"
#import <iMedia/IMBParserMessenger.h>
#import "IMBNode.h"
#import <iMedia/IMBObject.h>
#import <iMedia/IMBNodeObject.h>
#import "IMBProgressWindowController.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSPasteboard+iMedia.h"
#import "NSView+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSObject+iMedia.h"
#import <iMedia/IMBDynamicTableView.h>
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBButtonObject.h"
#import "IMBComboTableView.h"
#import "IMBComboTextCell.h"
#import "IMBObjectCollectionView.h"
#import "IMBObjectCollectionViewItem.h"
#import "IMBObjectCollectionViewIndexPathTransformer.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBObjectBadgesDidChangeNotification = @"IMBObjectBadgesDidChange";

static NSString* kArrangedObjectsKey = @"arrangedObjects";
static NSString* kImageRepresentationKeyPath = @"arrangedObjects.imageRepresentation";
static NSString* kIMBObjectImageRepresentationKey = @"imageRepresentation";
static NSString* kObjectCountStringKey = @"objectCountString";
static NSString* kGlobalViewTypeKey = @"globalViewType";

// Keys to be used by delegate

NSString* const IMBObjectViewControllerSegmentedControlKey = @"SegmentedControl";	/* Segmented control for object view selection */


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static NSMutableDictionary* sRegisteredObjectViewControllerClasses = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBObjectViewController ()

- (CALayer*) iconViewBackgroundLayer;
- (void) _configureIconView;
- (void) _configureListView;
- (void) _configureComboView;

- (NSMutableDictionary*) _preferences;
- (void) _setPreferences:(NSMutableDictionary*)inDict;
- (void) _saveStateToPreferences;
- (void) _loadStateFromPreferences;
- (void) _reloadIconView;
- (void) _reloadListView;
- (void) _reloadComboView;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectViewController

@synthesize libraryController = _libraryController;
@synthesize delegate = _delegate;
@synthesize currentNode = _currentNode;

@synthesize objectArrayController = ibObjectArrayController;
@synthesize tabView = ibTabView;
@synthesize iconView = ibIconView;
@synthesize listView = ibListView;
@synthesize comboView = ibComboView;
@synthesize viewType = _viewType;
@synthesize iconSize = _iconSize;

@synthesize objectCountFormatSingular = _objectCountFormatSingular;
@synthesize objectCountFormatPlural = _objectCountFormatPlural;
@synthesize clickedObject = _clickedObject;
//@synthesize progressWindowController = _progressWindowController;


#pragma mark Organic Setters/Getters

/**
 Sets the current node and resets the view's search field if current node changes
 
 @param currentNode the node that this instance's current node is set to (retained)

 @discussion
 Does not affect the delegate-based object filter (cf. badges)
 */
- (void) setCurrentNode:(IMBNode *)currentNode
{
    if (_currentNode != currentNode)
    {
        // Save current scroll position for "back" navigation
        [_currentNode release];
        _currentNode = [currentNode retain];
        
        [self resetSearchFilter];
        
        if (currentNode.objectCountFormatSingular != nil) {
            self.objectCountFormatSingular = currentNode.objectCountFormatSingular;
        } else {
            self.objectCountFormatSingular = [[self class] objectCountFormatSingular];
        }
        if (currentNode.objectCountFormatPlural != nil) {
            self.objectCountFormatPlural = currentNode.objectCountFormatPlural;
        } else {
            self.objectCountFormatPlural = [[self class] objectCountFormatPlural];
        }
    }
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Subclass Factory


// This is a central registry for for subclasses to register themselves for their +load method. That way they
// can make their existance known to the base class...

+ (void) registerObjectViewControllerClass:(Class)inObjectViewControllerClass forMediaType:(NSString*)inMediaType
{
	@synchronized ([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		if (sRegisteredObjectViewControllerClasses == nil)
		{
			sRegisteredObjectViewControllerClasses = [[NSMutableDictionary alloc] init];
		}
		
		[sRegisteredObjectViewControllerClasses setObject:inObjectViewControllerClass forKey:inMediaType];
		
		[pool drain];
	}
}


// This factory method relies of the registry above. It creates an IMBObjectViewController for the mediaType
// of the given IMBLibraryController. The class of the subview is automatically chosen by mediaType...

+ (IMBObjectViewController*) viewControllerForLibraryController:(IMBLibraryController*)inLibraryController delegate:(id<IMBObjectViewControllerDelegate>)inDelegate
{
	// Create a viewController of appropriate class type...
	
	NSString* mediaType = inLibraryController.mediaType;
	Class objectViewControllerClass = [sRegisteredObjectViewControllerClasses objectForKey:mediaType];

    NSString* nibName = [objectViewControllerClass nibName];
    NSBundle* bundle = [objectViewControllerClass bundle];
	IMBObjectViewController* objectViewController = [[[objectViewControllerClass alloc] initWithNibName:nibName bundle:bundle] autorelease];
    objectViewController.delegate = inDelegate;

	// Load the view *before* setting the libraryController, so that outlets are set before we load the preferences...
    
	[objectViewController view];										
	objectViewController.libraryController = inLibraryController;		
	return objectViewController;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Customize Subclasses

// The following methods must be overridden in subclasses to define the identity of a subclass...

+ (NSString*) mediaType
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) nibName
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSString*) objectCountFormatSingular
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


+ (NSString*) objectCountFormatPlural
{
	NSLog(@"%s Please use a custom subclass of IMBObjectViewController...",__FUNCTION__);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Please use a custom subclass of IMBObjectViewController" userInfo:nil] raise];
	
	return nil;
}


// The cell class to be used in the image browser view (if not provided by the library controller's delegate).
// You may overwrite this method in subclasses to provide your own view specific cell IKImageBrowserCell class...

+ (Class) iconViewCellClass
{
	return nil;
}


// You may subclass this method to provide a custom image browser background layer. Keep in mind   
// though that a custom background layer provided by the delegate will always overrule this one...

+ (CALayer*) iconViewBackgroundLayer
{
	return nil;
}


// Delay in seconds when view is reloaded after imageRepresentations of IMBObjects have changed.
// Longer delays cause fewer reloads of the view, but provide less direct feedback...

+ (double) iconViewReloadDelay
{
	return 0.05;	// Delay in seconds
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Object Lifecycle


- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	if (self = [super initWithNibName:inNibName bundle:inBundle])
	{
		self.objectCountFormatSingular = [[self class] objectCountFormatSingular];
		self.objectCountFormatPlural = [[self class] objectCountFormatPlural];
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) dealloc
{
    // Views from IB also have bindings with the object array controller and must be
    // unbound *before* the controller is deallocated
    
    [self unbindViews];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Cancel any scheduled messages...
	
	[NSObject cancelPreviousPerformRequestsWithTarget:ibIconView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibListView];
	[NSObject cancelPreviousPerformRequestsWithTarget:ibComboView];

	// Remove ourself from the QuickLook preview panel...
	
	QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanelExists] ? [QLPreviewPanel sharedPreviewPanel] : nil;
	if (panel.delegate == (id)self) panel.delegate = nil;
	if (panel.dataSource == (id)self) panel.dataSource = nil;
	
	// Stop observing the array...
	
	[ibObjectArrayController removeObserver:self forKeyPath:kImageRepresentationKeyPath];
	[ibObjectArrayController removeObserver:self forKeyPath:kArrangedObjectsKey];
	[ibObjectArrayController release];

	for (IMBObject* object in _observedVisibleItems)
	{
        if ([object isKindOfClass:[IMBObject class]])
		{
            [object removeObserver:self forKeyPath:kIMBObjectImageRepresentationKey];
        }
    }
	
    if ([IMBConfig useGlobalViewType]) [IMBConfig removeObserver:self forKeyPath:kGlobalViewTypeKey];
    
    IMBRelease(_observedVisibleItems);
	
	// Other cleanup...

	IMBRelease(_libraryController);
	IMBRelease(_currentNode);
	IMBRelease(_clickedObject);
//	IMBRelease(_progressWindowController);

	IMBRelease(_objectCountFormatPlural);
	IMBRelease(_objectCountFormatSingular);

	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	self.objectArrayController.delegate = self;
	
	// Configure the object views...
	
	[self _configureIconView];
	[self _configureListView];
	[self _configureComboView];
	
	// Just naming an image file '*Template' is not enough. So we explicitly make sure that all images in the
	// NSSegmentedControl are templates, so that they get correctly inverted when a segment is highlighted...
	
	NSInteger n = [ibSegments segmentCount];
	NSSegmentedCell *cell = [ibSegments cell];

	for (NSInteger i=0; i<n; i++)
	{
		[[ibSegments imageForSegment:i] setTemplate:YES];
	}
	
	// Set accessibilility description for each segment...

	for (NSInteger i=0; i<n; i++)
	{
		NSInteger tag = [cell tagForSegment:i];
		NSString *axDesc = nil;
		
		switch (tag)
		{
			case kIMBObjectViewTypeIcon:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.grid",
					nil,IMBBundle(),
					@"Grid",
					@"segmented cell accessibilility description");
				break;
				
			case kIMBObjectViewTypeList:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.list",
					nil,IMBBundle(),
					@"List",
					@"segmented cell accessibilility description");
				break;
				
			case kIMBObjectViewTypeCombo:
				axDesc = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.segment.combo",
					nil,IMBBundle(),
					@"Combination",
					@"segmented cell accessibilility description");
				break;
				
			default:
				axDesc = @"";
				break;
		}

		[[ibSegments imageForSegment:i] setAccessibilityDescription:axDesc];
	}
	
	// Observe changes to object array...
	
	[ibObjectArrayController retain];
	[ibObjectArrayController addObserver:self forKeyPath:kArrangedObjectsKey options:0 context:(void*)kArrangedObjectsKey];
	[ibObjectArrayController addObserver:self forKeyPath:kImageRepresentationKeyPath options:NSKeyValueObservingOptionNew context:(void*)kImageRepresentationKeyPath];

	// Bind selectionIndexPaths instead of selectionIndexes.
	// This works around an issue where the icon view scrolls to the top upon clicking an item to select it
	[ibIconView unbind:NSSelectionIndexesBinding];
	[ibIconView bind:NSSelectionIndexPathsBinding
			toObject:ibObjectArrayController
		 withKeyPath:@"selectionIndexes"
			 options:@{ NSValueTransformerBindingOption : [[IMBObjectCollectionViewIndexPathTransformer new] autorelease] }];

	// We need to save preferences before the app quits...
	
	[[NSNotificationCenter defaultCenter] 
		 addObserver:self 
		 selector:@selector(_saveStateToPreferences) 
		 name:NSApplicationWillTerminateNotification 
		 object:nil];
	
	// Observe changes by other controllers to global view type preference if we use global view type
	// so we can change our own view type accordingly
	
	if ([IMBConfig useGlobalViewType])
	{
		[IMBConfig addObserver:self forKeyPath:kGlobalViewTypeKey options:0 context:(void*)kGlobalViewTypeKey];
	}
	
    // If a badge filter is active on our object array controller we need to know when object badges change
    // so we can refresh our view accordingly.
    
	[[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(objectBadgesDidChange:)
     name:kIMBObjectBadgesDidChangeNotification
     object:nil];
	
	// Set up icon view to call up table view for "type select" key handling
	ibIconView.typeSelectTableView = ibListView;

	// After all has been said and done delegate may do additional setup on selected (sub)views
	
	if ([self.delegate respondsToSelector:@selector(objectViewController:didLoadViews:)])
	{
		NSDictionary* views = [NSDictionary dictionaryWithObjectsAndKeys:ibSegments, IMBObjectViewControllerSegmentedControlKey, nil];
		[self.delegate objectViewController:self didLoadViews:views];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Do not remove this method. It isn't called directly by the framework, but may be called by host applications...

- (void) unbindViews	
{
	// Tear down bindings *before* the window is closed. This avoids exceptions due to random deallocation order of 
	// top level objects in the nib file. Please note that we are unbinding ibIconView, ibListView, and ibComboView
	// separately in addition to self.view. This is necessary because NSTabView seems to be doing some kind of 
	// optimization where the views of invisible tabs are not really part of the window view hierarchy. However the 
	// view subtrees exist and do have bindings to the IMBObjectArrayController - which need to be torn down as well...
	
	[ibIconView imb_unbindViewHierarchy];
	[ibListView imb_unbindViewHierarchy];
	[ibComboView imb_unbindViewHierarchy];
	[self.view imb_unbindViewHierarchy];
	
    // Clear datasource and delegate, just in case views live longer than this controller...

    [ibIconView setDataSource:nil];
	[ibIconView setDelegate:nil];
	[ibIconView unbind:NSSelectionIndexPathsBinding];

	[ibListView setDataSource:nil];
    [ibListView setDelegate:nil];
	
    [ibComboView setDataSource:nil];
    [ibComboView setDelegate:nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Backend


- (void) setLibraryController:(IMBLibraryController*)inLibraryController
{
	id old = _libraryController;
	_libraryController = [inLibraryController retain];
	[old release];
	
	[self _loadStateFromPreferences];
}


// Returns the mediaType of our libraryController...

- (NSString*) mediaType
{
	return self.libraryController.mediaType;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Persistence 


- (NSMutableDictionary*) _preferences
{
	return [NSMutableDictionary dictionaryWithDictionary:[IMBConfig prefsForClass:self.class]];
}


- (void) _setPreferences:(NSMutableDictionary*)inDict
{
	[IMBConfig setPrefs:inDict forClass:self.class];
}


- (void) _saveStateToPreferences
{
	NSIndexSet* selectionIndexes = [ibObjectArrayController selectionIndexes];
	NSData* selectionData = [NSKeyedArchiver archivedDataWithRootObject:selectionIndexes];
	
	NSMutableDictionary* stateDict = [self _preferences];
	[stateDict setObject:[NSNumber numberWithUnsignedInteger:self.viewType] forKey:@"viewType"];
	[stateDict setObject:[NSNumber numberWithDouble:self.iconSize] forKey:@"iconSize"];
	[stateDict setObject:selectionData forKey:@"selectionData"];
	
	[self _setPreferences:stateDict];
}


- (void) _loadStateFromPreferences
{
	NSMutableDictionary* stateDict = [self _preferences];
	self.viewType = [[stateDict objectForKey:@"viewType"] unsignedIntegerValue];
	self.iconSize = [[stateDict objectForKey:@"iconSize"] doubleValue];
	
	//	NSData* selectionData = [stateDict objectForKey:@"selectionData"];
	//	NSIndexSet* selectionIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:selectionData];
	//	[ibObjectArrayController setSelectionIndexes:selectionIndexes];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) restoreState
{
	[self _loadStateFromPreferences];
}


- (void) saveState
{
	[self _saveStateToPreferences];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark User Interface

/**
 */
- (NSView *)selectedObjectView
{
    if (_viewType == kIMBObjectViewTypeIcon)
        return ibIconView;
    else if (_viewType == kIMBObjectViewTypeList)
        return ibListView;
    else if (_viewType == kIMBObjectViewTypeCombo)
        return ibComboView;
    
    return nil;
}

- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
	// If the array itself has changed then display the new object count...
	
	if (inContext == (void*)kArrangedObjectsKey)
	{
		[self willChangeValueForKey:kObjectCountStringKey];
		[self didChangeValueForKey:kObjectCountStringKey];
	}
	
	// If single thumbnails have changed (due to asynchronous loading) then trigger a reload of the icon or combo view...
	
	else if (inContext == (void*)kImageRepresentationKeyPath)
	{
		[self imb_performCoalescedSelector:@selector(_reloadIconView) withObject:nil afterDelay:[[self class] iconViewReloadDelay]];
        [self imb_performCoalescedSelector:@selector(_reloadComboView) withObject:nil afterDelay:0.1];
	}
	
	// The globally set view type in preferences was changed - adjust our own view type accordingly. Please note 
	// that we are not using setViewType: here as it would cause an endless recursion...
		
	else if (inContext == (void*)kGlobalViewTypeKey && [IMBConfig useGlobalViewType])
	{
		[self willChangeValueForKey:@"viewType"];
		_viewType = [[IMBConfig globalViewType] unsignedIntegerValue];
		[self didChangeValueForKey:@"viewType"];
	}
	
	// Find the row and reload it. Note that KVO notifications may be sent from a background thread (in this 
	// case, we know they will be) We should only update the UI on the main thread, and in addition, we use 
	// NSRunLoopCommonModes to make sure the UI updates when a modal window is up...
	//
	// This observation is only applicable to the ibComboView scenario. Should consolidate behavior
	// of observing image repressentation updates so it behaves the same for collection view and
	// table view.

	else if (inContext == (void*)kIMBObjectImageRepresentationKey)
	{
		NSInteger row = [(IMBObject*)inObject index];
		if (row == NSNotFound) row = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inObject];

		if (row != NSNotFound)
		{
			[ibComboView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		}
    }
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Subclasses can override these methods to configure or customize look & feel of the various object views...
//
// NOTE: Some features of the previous IKImageBrowser implementation have been thus far lost in the
// transition to NSCollectionView. If they are important to you, you might need to re-implement them
// on top of this new NSCollectionView-based infrastructure:
//
// 		- Custom background layers
//		- Skimmability
//
- (void) _configureIconView
{
	// Register the nib explicitly, because if an iMedia client subclasses IMBObjectViewController, it causes
	// NSCollectionView's default nib search to look in the bundle correspondiong to the SUBCLASS. To allow
	// client to subclass us without also providing redundant nibs, we are explicit about it here. Clients who
	// DO want to override the nibs can register the nib separately.
	NSNib* viewItemNib = [[NSNib alloc] initWithNibNamed:@"IMBObjectCollectionViewItem" bundle:[NSBundle bundleForClass:[IMBObjectViewController class]]];
	[ibIconView registerNib:viewItemNib forItemWithIdentifier:@"IMBObjectCollectionViewItem"];
	
	// Configure NSCollectionView to support dragging to other apps
	[ibIconView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

	[viewItemNib release];
}


- (void) _configureListView
{
	[ibListView setTarget:self];
	[ibListView setAction:@selector(tableViewWasClicked:)];
	[ibListView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
	
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];	// I think this was to work around a bug
    [ibListView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


- (void) _configureComboView
{
	[ibComboView setTarget:self];
	[ibComboView setAction:@selector(tableViewWasClicked:)];
	[ibComboView setDoubleAction:@selector(tableViewWasDoubleClicked:)];
	
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];	// I think this was to work around a bug
    [ibComboView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
}


// Give the library's delegate a chance to provide a custom background layer (>= 10.6 only)

- (CALayer*) iconViewBackgroundLayer
{
	if ([self.delegate respondsToSelector:@selector(imageBrowserBackgroundLayerForController:)])
	{
		return [self.delegate imageBrowserBackgroundLayerForController:self];
	}
	
	return [[self class] iconViewBackgroundLayer];
}


//----------------------------------------------------------------------------------------------------------------------


// Calculates the array of the icon in tableview...

- (NSRect) iconRectForTableView:(NSTableView*)inTableView row:(NSInteger)inRow inset:(CGFloat)inInset
{
	NSRect rect = [inTableView frameOfCellAtColumn:0 row:inRow];
	
	if ([inTableView isKindOfClass:[IMBComboTableView class]])
	{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		IMBComboTextCell* cell = (IMBComboTextCell*)[inTableView preparedCellAtColumn:0 row:inRow];
#pragma clang diagnostic pop
		rect = [cell imageRectForBounds:rect];
		rect = NSInsetRect(rect,inInset,inInset);
	}
	
	return rect;
}

- (BOOL) tableView:(NSTableView*)inTableView canDragRowsWithIndexes:(NSIndexSet *)rowIndexes
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];

	NSUInteger index = [rowIndexes firstIndex];

	while (index != NSNotFound)
	{
		IMBObject* object = [objects objectAtIndex:index];
		if ( !(object.isSelectable && object.isDraggable)) {
			return NO;
		}
		index = [rowIndexes indexGreaterThanIndex:index];
	}

	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) willShowView
{
	// To be overridden by subclass...
	
	[self willChangeValueForKey:@"viewType"];
	[self didChangeValueForKey:@"viewType"];
}


- (void) didShowView
{
	// To be overridden by subclass...
}


- (void) willHideView
{
	// To be overridden by subclass...
}


- (void) didHideView
{
	// To be overridden by subclass...
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

//----------------------------------------------------------------------------------------------------------------------


// Depending of the IMBConfig setting useGlobalViewType, the controller either uses a global state, or each
// controller keeps its own state. It is up to the application developer to choose a behavior...

- (void) setViewType:(NSUInteger)inViewType
{
	[self willChangeValueForKey:@"canUseIconSize"];
	_viewType = inViewType;
	[IMBConfig setGlobalViewType:[NSNumber numberWithUnsignedInteger:inViewType]];
	[self didChangeValueForKey:@"canUseIconSize"];
}


- (NSUInteger) viewType
{
	return _viewType;
}


// Availability of the icon size slide depends on the view type (e.g. not available in list view)...

- (BOOL) canUseIconSize
{
	return self.viewType != kIMBObjectViewTypeList;
}


//----------------------------------------------------------------------------------------------------------------------

- (void) updateCollectionViewForIconSize
{
	// From IKImageBrowserView, where we initially supported this value:
	// This value should be greater or equal to zero and less or equal than one. A zoom value of zero corresponds
	// to the minimum size (40x40 pixels), A zoom value of one means images fit the browser bounds. Other values are interpolated.

	// Despite the description above, it seems in practice iMedia previously maxed out at around 300.0,
	// not the full width of the view. Hardcoding minimum with and height to make it roughly match
	// the old minimum size.
	CGFloat minWidth = 60.0;
	CGFloat maxWidth = fmin(self.view.bounds.size.width, 300.0);

	CGFloat newMinWidth = minWidth;
	if ([self iconSize] > 0)
	{
		CGFloat widthSpread = maxWidth - minWidth;
		newMinWidth = minWidth + (widthSpread * [self iconSize]);
	}

	// Add to the interpolated width whatever the delta is for our non-image based view elements, such
	// as the selection view, label, and padding.
	CGFloat verticalNonImageHeightAdjustment = 20.0;
	CGFloat newMinHeight = newMinWidth + verticalNonImageHeightAdjustment;
	NSSize newItemSize = NSMakeSize(newMinWidth, newMinHeight);
	NSCollectionViewFlowLayout* gridLayout = (NSCollectionViewFlowLayout*)[ibIconView collectionViewLayout];
	gridLayout.itemSize = newItemSize;
}

- (void) setIconSize:(double)inIconSize
{
	// Get the row that seems most important in the combo view. Its either the selected row or the middle visible row...
	
	NSRange visibleRows = [ibComboView rowsInRect:[ibComboView visibleRect]];
	NSUInteger firstVisibleRow = visibleRows.location;
	NSUInteger lastVisibleRow = visibleRows.location + visibleRows.length;
	NSUInteger anchorRow = (firstVisibleRow + lastVisibleRow) / 2;
	
	NSIndexSet* selection = [ibObjectArrayController selectionIndexes];
	
	if (selection) 
	{
		NSUInteger firstSelectedRow = [selection firstIndex];
		NSUInteger lastSelectedRow = [selection lastIndex];

		if (firstSelectedRow != NSNotFound &&
			lastSelectedRow != NSNotFound &&
			firstSelectedRow >= firstVisibleRow && 
			lastSelectedRow <= lastVisibleRow)
		{
			anchorRow = (firstSelectedRow + lastSelectedRow) / 2;;
		}	
	}
	
	// Change the cell size of the icon view. Also notify the parser so it can update thumbnails if necessary...
	
	_iconSize = inIconSize;
	[IMBConfig setPrefsValue:[NSNumber numberWithDouble:inIconSize] forKey:@"globalIconSize"];
	
//	NSSize size = [ibIconView cellSize];
//	IMBParser* parser = self.currentNode.parser;
//	
//	if ([parser respondsToSelector:@selector(didChangeIconSize:objectView:)])
//	{
//		[parser didChangeIconSize:size objectView:ibIconView];
//	}

	// Update the views. The row height of the combo view needs to be adjusted accordingly...
	
	[self updateCollectionViewForIconSize];

	[ibComboView setNeedsDisplay:YES];

	CGFloat height = 60.0 + 100.0 * _iconSize;
	[ibComboView setRowHeight:height];
	
	// Scroll the combo view so that it appears to be anchored at the same image as before...
	
	NSRect cellFrame = [ibComboView frameOfCellAtColumn:0 row:anchorRow];
	NSRect viewFrame = [ibComboView  frame];
	NSRect superviewFrame = [[ibComboView superview] frame];
	
	CGFloat y = NSMidY(cellFrame) - 0.5 * NSHeight(superviewFrame);
	CGFloat ymax = NSHeight(viewFrame) - NSHeight(superviewFrame);
	if (y < 0.0) y = 0.0;
	if (y > ymax) y = ymax;
	
	NSClipView* clipview = (NSClipView*)[ibComboView superview];
	[clipview scrollToPoint:NSMakePoint(0.0,y)];
	[[ibComboView enclosingScrollView] reflectScrolledClipView:clipview];
}


- (double) iconSize
{
	if ([IMBConfig useGlobalViewType])
	{
		return [[IMBConfig prefsValueForKey:@"globalIconSize"] doubleValue];
	}
	
	return _iconSize;
}


//----------------------------------------------------------------------------------------------------------------------


// Return the object count for the currently selected node. Please note that we ask the node first. Only if the
// count is missing, we ask the NSArrayController. This way we can react to custom situations, like 3 images and 3 
// subfolders being reported as "3 images" instead of "6 images"...

- (NSString*) objectCountString
{
	IMBNode* node = [self currentNode];
	NSInteger count = node.displayedObjectCount;
	
	// If the node has an uninitialized count, or if we exist apart from a node view controller, or a search
	// is currently active, then consult our array controller directly...
	
	if ((count < 0) || node == nil || ibObjectArrayController.searchString.length > 0)
	{
		count = (NSInteger) [[ibObjectArrayController arrangedObjects] count];
	}
	
	NSString* format = count==1 ? self.objectCountFormatSingular : self.objectCountFormatPlural;
	return [NSString stringWithFormat:format,count];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) _reloadIconView
{
	if ([ibIconView.window isVisible])
	{
		// Remove all tool tips before we start the reload, because there is a narrow window during reload when we have
		// our old tooltips configured and they refer to OLD objects in the icon view. This is a window for crashing 
		// if the system attempts to communicate with the tooltip's owner which is being removed from the view...
		
		[ibIconView removeAllToolTips];

		// Try to save/restore selection to avoid unwanted deselection of an item that
		// is selected while thumbnails are still percolating
		NSIndexSet* savedSelection = [ibObjectArrayController selectionIndexes];

		// Only need to reload "visible" items because those are the ones collection view vouches
		// actually have image data associated with them.
		[ibIconView reloadItemsAtIndexPaths:[ibIconView indexPathsForVisibleItems]];

		[ibIconView setSelectionIndexes:savedSelection];
		
		// Items loading into the view will cause a change in the scroller's clip view, which will cause the tooltips
		// to be revised to suit only the current visible items...
	}
}


- (void) _reloadListView
{
	if ([ibListView.window isVisible])
	{
        [ibListView reloadData];
	}
}


- (void) _reloadComboView
{
	if ([ibComboView.window isVisible])
	{
        [ibComboView reloadData];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) objectBadgesDidChange:(NSNotification*)inNotification
{
	[self.objectArrayController rearrangeObjects];
	[self.view setNeedsDisplay:YES];
}


/**
 Resets the search field so that all objects of current node are shown
 
 @discussion
 Does not affect the delegate-based object filter (cf. badges)
 */
- (void) resetSearchFilter
{
    [self.objectArrayController resetSearch:self];
}

#pragma mark
#pragma mark NSCollectionViewDataSource

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return collectionView.content.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
	IMBObjectCollectionViewItem* thisItem = [collectionView makeItemWithIdentifier:@"IMBObjectCollectionViewItem" forIndexPath:indexPath];
	IMBObject* representedObject = [collectionView.content objectAtIndex:indexPath.item];
	if (representedObject != nil)
	{
		// Seems we have to call imageRepresentation first to get the thumbnail loaded, then
		// thumbnail returns it in NSImage format.
		(void) [representedObject imageRepresentation];
		thisItem.imageView.image = representedObject.thumbnail;

		thisItem.textField.stringValue = representedObject.imageTitle;
		thisItem.representedObject = representedObject;

		// Associate the tooltip with the container view
		thisItem.view.toolTip = representedObject.tooltipString;

		NSImage* badge = nil;

		if ([self.delegate respondsToSelector:@selector(objectViewController:badgeForObject:)])
		{
			badge = [self.delegate objectViewController:self badgeForObject:representedObject];
		}

		thisItem.badgeImageView.image = badge;

		thisItem.selected = [self.objectArrayController.selectedObjects containsObject:representedObject];
	}
	return thisItem;
}

- (nullable id <NSPasteboardWriting>)collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath
{
	// We only support one section for now, so we map the indexPath to an index set
	return [self pasteboardItemForDraggingObjectAtIndex:[indexPath indexAtPosition:1]];
}

- (void)collectionView:(NSCollectionView *)collectionView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	//	Prevent item from being hidden (creating a hole in the grid) while being dragged
	for (NSIndexPath *indexPath in indexPaths) {
		[[[collectionView itemAtIndexPath:indexPath] view] setHidden:NO];
	}

	session.animatesToStartingPositionsOnCancelOrFail = YES;
	session.draggingFormation = NSDraggingFormationDefault;

	// Provide the IMBObjects to a static variable of Pasteboard, which is the fast path shortcut for
	// intra application drags. These objects are released again in draggingSession:endedAtPoint:operation:
	// of our object views...

	NSMutableIndexSet *rowIndexes = [NSMutableIndexSet indexSet];

	for (NSIndexPath *indexPath in indexPaths) {
		[rowIndexes addIndex:indexPath.item];
	}

	NSIndexSet *indexes = [self filteredDraggingIndexes:rowIndexes];
	NSArray<IMBObject *> *draggedObjects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
	IMBParserMessenger *parserMessenger = draggedObjects.lastObject.parserMessenger;

	[NSPasteboard imb_setIMBObjects:draggedObjects];
	[NSPasteboard imb_setParserMessenger:parserMessenger];

//	[session enumerateDraggingItemsWithOptions:0 forView:self.view classes:[NSArray arrayWithObject:[NSURL class]] searchOptions:@{} usingBlock:^(NSDraggingItem * _Nonnull draggingItem, NSInteger idx, BOOL * _Nonnull stop) {
//		// Not sure whether we could do some useful stuff here. Maybe, adjust starting frame of
//		// dragging item in case of a single item drag? (It may currently be a little off the cursor position)
//		//NSLog(@"Hello, world!");
//	}];
}

- (void)collectionView:(NSCollectionView *)collectionView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint dragOperation:(NSDragOperation)operation
{
	[NSPasteboard imb_setIMBObjects:nil];
}

//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark NSCollectionViewDelegate

// Bindings from NSCollectionView to our array controller don't seem to work 100%. In particular changes
// to the selection via the UI are not perpetuated automatically to the array controller's selectionIndexes.
// To maintain consistency with the NSTableView for other views that rely upon the same array controller,
// we manually listen for changes and re-assert the selectionIndexes from the collection view to the
// array controller.
- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	[ibObjectArrayController setSelectionIndexes:[collectionView selectionIndexes]];

	// If a missing object was selected, then display an alert...
	if (self.viewType == kIMBObjectViewTypeIcon)
	{
		for (NSIndexPath* thisIndexPath in indexPaths)
		{
			IMBObject* thisObject = (IMBObject*)[[collectionView itemAtIndexPath:thisIndexPath] representedObject];
			if (thisObject != nil)
			{
				if (thisObject.accessibility == kIMBResourceDoesNotExist)
				{
					NSUInteger index = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:thisObject];
					NSRect rect = [collectionView frameForItemAtIndex:index];
					[IMBAccessRightsViewController showMissingResourceAlertForObject:thisObject view:collectionView relativeToRect:rect];
				}
				else if (thisObject.accessibility == kIMBResourceNoPermission)
				{
					[[IMBAccessRightsViewController sharedViewController]
					 imb_performCoalescedSelector:@selector(grantAccessRightsForObjectsOfNode:)
					 withObject:self.currentNode];
				}
			}
		}
	}

	[self udpateQuickLookPanel];
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	[ibObjectArrayController setSelectionIndexes:[collectionView selectionIndexes]];
	[self udpateQuickLookPanel];
}

// Disable selection of certain items
- (NSSet<NSIndexPath *> *) selectableItemsInCollectionView:(NSCollectionView *)collectionView atIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	NSMutableSet* filteredIndexPaths = [[indexPaths mutableCopy] autorelease];
	for (NSIndexPath* thisIndexPath in indexPaths)
	{
		IMBObject* thisObject = (IMBObject*)[collectionView.content objectAtIndex:thisIndexPath.item];

		if ([thisObject isSelectable] == NO)
		{
			[filteredIndexPaths removeObject:thisIndexPath];
		}
	}
	return filteredIndexPaths;
}

- (NSSet<NSIndexPath *> *)collectionView:(NSCollectionView *)collectionView shouldSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
	return [self selectableItemsInCollectionView:collectionView atIndexPaths:indexPaths];
}

- (NSSet<NSIndexPath *> *)collectionView:(NSCollectionView *)collectionView shouldChangeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths toHighlightState:(NSCollectionViewItemHighlightState)highlightState NS_AVAILABLE_MAC(10_11)
{
	// We allow non-selectable items to be highlighted because it gives some feedback to
	// users that the click happened, and more importantly gives NSCollectionView permission
	// to deselect whatever was previously selected. This ensures that for example when a
	// user goes to double-click on a folder item, which is not selectable, it will deselect
	// whatever was previously selected before passing along the double-click message to the client.
	return indexPaths;
}

- (BOOL)collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths withEvent:(NSEvent *)event
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];

	for (NSIndexPath* indexPath in indexPaths) {
		NSUInteger index = [indexPath item];
		IMBObject* object = [objects objectAtIndex:index];

		if (! (object.isSelectable && object.isDraggable)) {
			return NO;
		}
	}

	return YES;
}

#pragma mark
#pragma mark QuickLook

- (void) udpateQuickLookPanel
{
	// Notify the Quicklook panel of the selection change...
	
	QLPreviewPanel* panel = [QLPreviewPanel sharedPreviewPanelExists] ? [QLPreviewPanel sharedPreviewPanel] : nil;
	
	if (panel.dataSource == (id)self)
	{
		[panel reloadData];
		[panel refreshCurrentPreviewItem];
	}
}

- (NSMenu*) collectionView:(IMBObjectCollectionView*)collectionView wantsContextMenuForItem:(IMBObject*)theItem
{
	return [self menuForObject:theItem];
}

// First give the delegate a chance to handle the double click. It it chooses not to, then we will
// handle it ourself by simply opening the files (with their default app)...

- (void) collectionView:(IMBObjectCollectionView*)collectionView wasDoubleClickedOnItem:(IMBObject*)clickedItem
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;

	if ([delegate respondsToSelector:@selector(libraryController:didDoubleClickSelectedObjects:inNode:)])
	{
		IMBNode* node = self.currentNode;
		NSArray* objects = [ibObjectArrayController selectedObjects];
		didHandleEvent = [delegate libraryController:controller didDoubleClickSelectedObjects:objects inNode:node];
	}

	if (!didHandleEvent && (clickedItem != nil))
	{
		if ([clickedItem isKindOfClass:[IMBNodeObject class]])
		{
			IMBNodeObject* clickedNode = (IMBNodeObject *)clickedItem;
			[IMBNodeViewController revealNodeWithIdentifier:clickedNode.representedNodeIdentifier];
			[self expandNodeObject:clickedNode];
		}
		else if ([clickedItem isKindOfClass:[IMBButtonObject class]])
		{
			IMBButtonObject* clickedButton = (IMBButtonObject*)clickedItem;
			[clickedButton sendDoubleClickAction];
		}
		else
		{
			[self openSelectedObjects:collectionView];
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark NSTableViewDelegate


// If the object for the cell that we are about to display doesn't have any metadata yet, then load it lazily.
// Note: According to WWDC Session 110, this is called a LOT so it's not good for delayed loading...

- (void) tableView:(NSTableView*)inTableView willDisplayCell:(id)inCell forTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:inRow];
	NSString* columnIdentifier = [inTableColumn identifier];
	
	// If we are in combo view, then assign thumbnail, title, subd subtitle (metadataDescription). If they are
	// not available yet, then load them lazily (in that case we'll end up here again once they are available)...
	
	if ([inCell isKindOfClass:[IMBComboTextCell class]])
	{
		IMBComboTextCell* cell = (IMBComboTextCell*)inCell;
		cell.imageRepresentation = object.imageRepresentation;
		cell.imageRepresentationType = object.imageRepresentationType;
		cell.title = object.imageTitle;
		cell.subtitle = object.metadataDescription;
	}
	
	// If we are in list view and don't have metadata yet, then load it lazily. We'll end up here again once 
	// they are available...
	
	if ([columnIdentifier isEqualToString:@"size"] || [columnIdentifier isEqualToString:@"duration"])
	{
		if (object.metadata == nil && ![object isKindOfClass:[IMBNodeObject class]])
		{
			[object loadMetadata];
		}
	}
	
	// Host app delegate may provide badge image here. In the list view the icon will be replaced in the NSImageCell...
	
	NSImage* badge = nil;
	
	if ([self.delegate respondsToSelector:@selector(objectViewController:badgeForObject:)])
	{
		badge = [self.delegate objectViewController:self badgeForObject:object];
	}
			
	if ([inCell respondsToSelector:@selector(setBadge:)])
	{
		if (object.accessibility == kIMBResourceDoesNotExist)
		{
			[inCell setBadge:[NSImage imb_imageNamed:@"IMBStopIcon.icns"]];
		}
		else if (object.accessibility == kIMBResourceNoPermission)
		{
			[inCell setBadge:[NSImage imb_imageNamed:@"warning.tiff"]];
		}
		else 
		{
			[inCell setBadge:badge];
		}
	}

	if ([columnIdentifier isEqualToString:@"icon"] && [inCell isKindOfClass:[NSImageCell class]])
	{
		if (object.accessibility == kIMBResourceDoesNotExist)
		{
			[inCell setImage:[NSImage imb_imageNamed:@"IMBStopIcon.icns"]];
		}
		else if (object.accessibility == kIMBResourceNoPermission)
		{
			[inCell setImage:[NSImage imb_imageNamed:@"warning.tiff"]];
		}
		else if (badge)
		{
			[inCell setImage:badge];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// We do not allow any editing in the list or combo view...

- (BOOL) tableView:(NSTableView*)inTableView shouldEditTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}


// Check whether a particular row is selectable...

- (BOOL) tableView:(NSTableView*)inTableView shouldSelectRow:(NSInteger)inRow
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object isSelectable];
}


- (BOOL) tableView:(NSTableView*)inTableView shouldTrackCell:(NSCell*)inCell forTableColumn:(NSTableColumn*)inColumn row:(NSInteger)inRow
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object isSelectable];
}


//----------------------------------------------------------------------------------------------------------------------


// Provide a tooltip for the row...

- (NSString*) tableView:(NSTableView*)inTableView toolTipForCell:(NSCell*)inCell rect:(NSRectPointer)inRect tableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow mouseLocation:(NSPoint)inMouseLocation
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = [objects objectAtIndex:inRow];
	return [object tooltipString];
}


- (BOOL) tableView:(NSTableView*)inTableView shouldShowCellExpansionForTableColumn:(NSTableColumn*)inTableColumn row:(NSInteger)inRow
{
	return NO;
}

#pragma mark - NSTableViewDataSource

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
    session.animatesToStartingPositionsOnCancelOrFail = YES;
    session.draggingFormation = NSDraggingFormationDefault;
    
    // Provide the IMBObjects to a static variable of Pasteboard, which is the fast path shortcut for
    // intra application drags. These objects are released again in draggingSession:endedAtPoint:operation:
    // of our object views...
    
    NSIndexSet *indexes = [self filteredDraggingIndexes:rowIndexes];
    NSArray<IMBObject *> *draggedObjects = [[ibObjectArrayController arrangedObjects] objectsAtIndexes:indexes];
    IMBParserMessenger *parserMessenger = draggedObjects.lastObject.parserMessenger;
    
    [NSPasteboard imb_setIMBObjects:draggedObjects];
    [NSPasteboard imb_setParserMessenger:parserMessenger];
    
//    [session enumerateDraggingItemsWithOptions:0 forView:self.view classes:[NSArray arrayWithObject:[NSURL class]] searchOptions:@{} usingBlock:^(NSDraggingItem * _Nonnull draggingItem, NSInteger idx, BOOL * _Nonnull stop) {
//        // Not sure whether we could do some useful stuff here. Maybe, adjust starting frame of
//        // dragging item in case of a single item drag? (It may currently be a little off the cursor position)
//        //NSLog(@"Hello, world!");
//    }];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
	[NSPasteboard imb_setIMBObjects:nil];
}

/**
 This is crucial for correct multi-item drag. With this the NSTableView will ensure that
 each PasteboardItem is wrapped into a DraggingItem (as enforced with Xcode 10 and macOS 10.14).
 */
- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
    IMBObject* object = [[ibObjectArrayController arrangedObjects] objectAtIndex:row];

    if (object.isSelectable && (object.accessibility == kIMBResourceIsAccessible ||
                                object.accessibility == kIMBResourceIsAccessibleSecurityScoped))
    {
        NSPasteboardItem* item = [[NSPasteboardItem alloc] init];
        [item setDataProvider:object forTypes:[self draggingTypesForWritingToPasteboard]];
        
        return [item autorelease];
    }
    
    return nil;
}


#pragma mark -

// We pre-load the images in batches. Assumes that we only have one client table view.  If we were to add another 
// IMBDynamicTableView client, we would need to deal with this architecture a bit since we have ivars here about 
// which rows are visible...

- (void) dynamicTableView:(IMBDynamicTableView*)inTableView changedVisibleRowsFromRange:(NSRange)inOldVisibleRows toRange:(NSRange)inNewVisibleRows
{
	NSArray *newVisibleItems = [[ibObjectArrayController arrangedObjects] subarrayWithRange:inNewVisibleRows];
	NSMutableSet *newVisibleItemsSetRetained = [[NSMutableSet alloc] initWithArray:newVisibleItems];
	
	NSMutableSet *itemsNoLongerVisible	= [NSMutableSet set];
	NSMutableSet *itemsNewlyVisible		= [NSMutableSet set];
	
	[itemsNewlyVisible setSet:newVisibleItemsSetRetained];
	[itemsNewlyVisible minusSet:_observedVisibleItems];
	
	[itemsNoLongerVisible setSet:_observedVisibleItems];
	[itemsNoLongerVisible minusSet:newVisibleItemsSetRetained];

	// With items going away, stop observing...
	
    for (IMBObject* object in itemsNoLongerVisible)
	{
		[object removeObserver:self forKeyPath:kIMBObjectImageRepresentationKey];
    }
	
    // With newly visible items, start observing...
	
    for (IMBObject* object in itemsNewlyVisible)
	{
		[object addObserver:self forKeyPath:kIMBObjectImageRepresentationKey options:0 context:(void*)kIMBObjectImageRepresentationKey];
     }
	
	// Finally cache our old visible items set...
	
	[_observedVisibleItems release];
    _observedVisibleItems = newVisibleItemsSetRetained;
}


//----------------------------------------------------------------------------------------------------------------------


// Doubleclicking a row opens the selected items. This may trigger a download if the user selected remote objects.
// First give the delegate a chance to handle the double click. Please note that there are special cases for
// missing media files or missing access rights...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	IMBLibraryController* controller = self.libraryController;
	id delegate = controller.delegate;
	BOOL didHandleEvent = NO;
	
	NSTableView* view = (NSTableView*)inSender;
	NSUInteger row = [view clickedRow];
	NSRect rect = [self iconRectForTableView:view row:row inset:16.0];
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = row!=-1 ? [objects objectAtIndex:row] : nil;
		
    if (object != nil)
    {
		if (object.accessibility == kIMBResourceDoesNotExist)
		{
			[IMBAccessRightsViewController showMissingResourceAlertForObject:object view:view relativeToRect:rect];
		}
		else if (object.accessibility == kIMBResourceNoPermission)
		{
			[[IMBAccessRightsViewController sharedViewController]
				imb_performCoalescedSelector:@selector(grantAccessRightsForObjectsOfNode:)
				withObject:self.currentNode];
		}
		else 
		{
			if ([delegate respondsToSelector:@selector(libraryController:didDoubleClickSelectedObjects:inNode:)])
			{
				IMBNode* node = self.currentNode;
				objects = [ibObjectArrayController selectedObjects];
				didHandleEvent = [delegate libraryController:controller didDoubleClickSelectedObjects:objects inNode:node];
			}
			
			if (!didHandleEvent)
			{
				objects = [ibObjectArrayController arrangedObjects];
				object = row!=-1 ? [objects objectAtIndex:row] : nil;
				
				if ([object isKindOfClass:[IMBNodeObject class]])
				{
					[self expandNodeObject:(IMBNodeObject*)object];
				}
				else if ([object isKindOfClass:[IMBButtonObject class]])
				{
					[(IMBButtonObject*)object sendDoubleClickAction];
				}
				else
				{
					[self openSelectedObjects:inSender];
				}	
			}	
		}
    }
}


// Handle single clicks for IMBButtonObjects...

- (IBAction) tableViewWasClicked:(id)inSender
{
	// No-op; clicking is handled with more detail from the mouse operations.
	// However we want to make sure our window becomes key with a click.
	
	[[inSender window] makeKeyWindow];

	// If we do not have access right for the clicked object, then prompt the user to give us access...
	
	NSTableView* view = (NSTableView*)inSender;
	NSUInteger row = [view clickedRow];
	NSRect rect = [self iconRectForTableView:view row:row inset:16.0];
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = row!=-1 ? [objects objectAtIndex:row] : nil;
	
	if (object)
	{
		if (object.accessibility == kIMBResourceDoesNotExist)
		{
			[IMBAccessRightsViewController showMissingResourceAlertForObject:object view:view relativeToRect:rect];
		}
		else if (object.accessibility == kIMBResourceNoPermission)
		{
			[[IMBAccessRightsViewController sharedViewController]
				imb_performCoalescedSelector:@selector(grantAccessRightsForObjectsOfNode:)
				withObject:self.currentNode];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBObjectArrayControllerDelegate


- (BOOL) objectArrayController:(IMBObjectArrayController*)inController filterObject:(IMBObject*)inObject
{
	id <IMBObjectViewControllerDelegate> delegate = self.delegate;
	
	switch (_objectFilter)
	{
		case kIMBObjectFilterBadge:

			return ([delegate respondsToSelector:@selector(objectViewController:badgeForObject:)] &&
					[delegate objectViewController:self badgeForObject:inObject] != nil);
			
		case kIMBObjectFilterNoBadge:

			return ([delegate respondsToSelector:@selector(objectViewController:badgeForObject:)] &&
					[delegate objectViewController:self badgeForObject:inObject] == nil);

		case kIMBObjectFilterAll:
		default:
		
			return YES;
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Context Menu

- (NSMenu*) menuForObject:(IMBObject*)inObject
{
	// Create an empty menu that will be pouplated in several steps...
	
	NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"contextMenu"] autorelease];
	NSMenuItem* item = nil;
	NSString* title = nil;
	NSString* appPath = nil;;
	NSString* appName = nil;;
	NSString* type = nil;
	
	if (inObject)
	{
		// For node objects (folders) provide a menu item to drill down the hierarchy...
		
		if ([inObject isKindOfClass:[IMBNodeObject class]])
		{
			title = NSLocalizedStringWithDefaultValue(
				@"IMBObjectViewController.menuItem.open",
				nil,IMBBundle(),
				@"Open",
				@"Menu item in context menu of IMBObjectViewController");
			
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openSubNode:) keyEquivalent:@""];
			[item setRepresentedObject:[(IMBNodeObject*)inObject representedNodeIdentifier]];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
		}
		
		// For local file object (path or url) add menu items to open the file (in editor and/or viewer apps)...
			
		else
		{
            [inObject requestBookmarkWithError:nil];
			NSURL *location = [inObject URLByResolvingBookmark];
			if ([location isFileURL])
			{			
				if ([location checkResourceIsReachableAndReturnError:NULL])
				{
					// Open with editor app...
					
					if ((appPath = [IMBConfig editorAppForMediaType:self.mediaType]))
					{
						title = NSLocalizedStringWithDefaultValue(
							@"IMBObjectViewController.menuItem.openWithApp",
							nil,IMBBundle(),
							@"Open With %@",
							@"Menu item in context menu of IMBObjectViewController");
						
						NSFileManager *fileManager = [[NSFileManager alloc] init];
						appName = [fileManager displayNameAtPath:appPath];
						[fileManager release];
						title = [NSString stringWithFormat:title,appName];	

						item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInEditorApp:) keyEquivalent:@""];
						[item setRepresentedObject:inObject];
						[item setTarget:self];
						[menu addItem:item];
						[item release];
					}
					
					// Open with viewer app...
					
					if ((appPath = [IMBConfig viewerAppForMediaType:self.mediaType]))
					{
						title = NSLocalizedStringWithDefaultValue(
							@"IMBObjectViewController.menuItem.openWithApp",
							nil,IMBBundle(),
							@"Open With %@",
							@"Menu item in context menu of IMBObjectViewController");
						
						NSFileManager *fileManager = [[NSFileManager alloc] init];
						appName = [fileManager displayNameAtPath:appPath];
						[fileManager release];
						title = [NSString stringWithFormat:title,appName];	

						item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInViewerApp:) keyEquivalent:@""];
						[item setRepresentedObject:inObject];
						[item setTarget:self];
						[menu addItem:item];
						[item release];
					}
					
					// Open with default app determined by OS...
					
					else if ([[NSWorkspace imb_threadSafeWorkspace] getInfoForFile:[location path] application:&appPath type:&type])
					{
						title = NSLocalizedStringWithDefaultValue(
							@"IMBObjectViewController.menuItem.openWithFinder",
							nil,IMBBundle(),
							@"Open with Finder",
							@"Menu item in context menu of IMBObjectViewController");

						item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInApp:) keyEquivalent:@""];
						[item setRepresentedObject:inObject];
						[item setTarget:self];
						[menu addItem:item];
						[item release];
					}
					
					// Show in Finder...
					
					title = NSLocalizedStringWithDefaultValue(
						@"IMBObjectViewController.menuItem.revealInFinder",
						nil,IMBBundle(),
						@"Show in Finder",
						@"Menu item in context menu of IMBObjectViewController");
					
					item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
					[item setRepresentedObject:inObject];
					[item setTarget:self];
					[menu addItem:item];
					[item release];
				}
			}
			
			// Remote URL object can be downloaded or opened in a web browser...
			
			else
			{
				title = NSLocalizedStringWithDefaultValue(
                          @"IMBObjectViewController.menuItem.reload",
                          nil,IMBBundle(),
                          @"Reload",
                          @"Menu item in context menu of IMBObjectViewController");
				
				item = [[NSMenuItem alloc] initWithTitle:title action:@selector(reload:) keyEquivalent:@""];
				[item setRepresentedObject:inObject];
				[item setTarget:self];
				[menu addItem:item];
				[item release];
				
// Don't add the download: menu item because the download: method was commented out in
// commit c03e3effc3dd3c0d6fb044be4e8c765e64981760 ... need to figure out whether download
// works or not, and add the menu back only then?
//                title = NSLocalizedStringWithDefaultValue(
//                                                          @"IMBObjectViewController.menuItem.download",
//                                                          nil,IMBBundle(),
//                                                          @"Download",
//                                                          @"Menu item in context menu of IMBObjectViewController");
//                
//				item = [[NSMenuItem alloc] initWithTitle:title action:@selector(download:) keyEquivalent:@""];
//				[item setRepresentedObject:location];
//				[item setTarget:self];
//				[menu addItem:item];
//				[item release];

				title = NSLocalizedStringWithDefaultValue(
					@"IMBObjectViewController.menuItem.openInBrowser",
					nil,IMBBundle(),
					@"Open With Browser",
					@"Menu item in context menu of IMBObjectViewController");
				
				item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openInBrowser:) keyEquivalent:@""];
				[item setRepresentedObject:inObject];
				[item setTarget:self];
				[menu addItem:item];
				[item release];
			}
		}
	
		// QuickLook...
		
		if ([inObject isSelectable] && [inObject previewItemURL] != nil)
		{
			title = NSLocalizedStringWithDefaultValue(
				@"IMBObjectViewController.menuItem.quickLook",
				nil,IMBBundle(),
				@"Quick Look",
				@"Menu item in context menu of IMBObjectViewController");
				
			item = [[NSMenuItem alloc] initWithTitle:title action:@selector(quicklook:) keyEquivalent:@"y"];
			[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
			[item setRepresentedObject:inObject];
			[item setTarget:self];
			[menu addItem:item];
			[item release];
		}
	}
	
	// Badges filtering
	
	if ([self.delegate respondsToSelector:@selector(objectViewController:badgeForObject:)])
	{
		if ([menu numberOfItems] > 0)
		{
			[menu addItem:[NSMenuItem separatorItem]];
		}
			 
		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showAll",
			nil,IMBBundle(),
			@"Show All",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterAll];
		[item setTarget:self];
        [item setState: _objectFilter == kIMBObjectFilterAll ? NSControlStateValueOn : NSControlStateValueOff];
		[menu addItem:item];
		[item release];

		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showBadgedOnly",
			nil,IMBBundle(),
			@"Show Badged Only",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterBadge];
		[item setTarget:self];
        [item setState: _objectFilter == kIMBObjectFilterBadge ? NSControlStateValueOn : NSControlStateValueOff];
		[menu addItem:item];
		[item release];

		title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.showUnbadgedOnly",
			nil,IMBBundle(),
			@"Show Unbadged Only",
			@"Menu item in context menu of IMBObjectViewController");
			
		item = [[NSMenuItem alloc] initWithTitle:title action:@selector(showFiltered:) keyEquivalent:@""];
		[item setTag:kIMBObjectFilterNoBadge];
		[item setTarget:self];
        [item setState: _objectFilter == kIMBObjectFilterNoBadge ? NSControlStateValueOn : NSControlStateValueOff];
		[menu addItem:item];
		[item release];
	}
	
	// Give the IMBParserMessenger a chance to add menu items...
	
	IMBParserMessenger* parserMessenger = self.currentNode.parserMessenger;
	
	if ([parserMessenger respondsToSelector:@selector(willShowContextMenu:forObject:)])
	{
		[parserMessenger willShowContextMenu:menu forObject:inObject];
	}
	
	// Give delegate a chance to add custom menu items...
	
	id delegate = self.libraryController.delegate;
	
	if ([delegate respondsToSelector:@selector(libraryController:willShowContextMenu:forObject:)])
	{
		[delegate libraryController:self.libraryController willShowContextMenu:menu forObject:inObject];
	}
	
	// Return the menu...
	
	if ([menu numberOfItems] > 0)
	{
		return menu;
	}
	
	return nil;
}


- (IBAction) openInEditorApp:(id)inSender
{
	NSString* appPath = [IMBConfig editorAppForMediaType:self.mediaType];
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			
			if (url)
			{
				if (appPath) [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:appPath];
				else [[NSWorkspace sharedWorkspace] openURL:url];
			}
		}
	}];
}


- (IBAction) openInViewerApp:(id)inSender
{
	NSString* appPath = [IMBConfig viewerAppForMediaType:self.mediaType];
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			
			if (url)
			{
				if (appPath) [[NSWorkspace sharedWorkspace] openFile:url.path withApplication:appPath];
				else [[NSWorkspace sharedWorkspace] openURL:url];
			}
		}
	}];
}


- (IBAction) openInApp:(id)inSender
{
	IMBObject* object = (IMBObject*)[inSender representedObject];

	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			if (url) [[NSWorkspace sharedWorkspace] openURL:url];
		}
	}];
}


//- (IBAction) download:(id)inSender
//{
//	IMBParser* parser = self.currentNode.parser;
//	NSArray* objects = [ibObjectArrayController selectedObjects];
//	IMBObjectsPromise* promise = [parser objectPromiseWithObjects:objects];
//	[promise setDelegate:self completionSelector:@selector(_postProcessDownload:)];
//    [promise start];
//}


- (IBAction) reload:(id)inSender
{
	IMBObject* object = (IMBObject*)[inSender representedObject];
    object.needsImageRepresentation = YES;
	[object loadThumbnail];
}


- (IBAction) openInBrowser:(id)inSender
{
    IMBObject* object = (IMBObject*)[inSender representedObject];
    
    [object requestBookmarkWithCompletionBlock:^(NSError* inError)
     {
         if (inError)
         {
             [NSApp presentError:inError];
         }
         else
         {
             NSURL* url = [object URLByResolvingBookmark];
             if (url) [[NSWorkspace imb_threadSafeWorkspace] openURL:url];
         }
     }];
}


- (IBAction) revealInFinder:(id)inSender
{
	IMBObject* object = (IMBObject*)[inSender representedObject];
	[object requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		if (inError)
		{
			[NSApp presentError:inError];
		}
		else
		{
			NSURL* url = [object URLByResolvingBookmark];
			NSString* path = [url path];
			NSString* folder = [path stringByDeletingLastPathComponent];
			[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
		}
	}];
}


- (IBAction) openSubNode:(id)inSender
{
	NSString* identifier = (NSString*)[inSender representedObject];
	IMBNode* node = [[IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType] nodeWithIdentifier:identifier];

	NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
		self,@"objectViewController",
		node,@"node",
		nil];
			
	[[NSNotificationCenter defaultCenter] 
		postNotificationName:kIMBExpandAndSelectNodeWithIdentifierNotification 
		object:nil 
		userInfo:info];
}


- (IBAction) showFiltered:(id)inSender
{
	_objectFilter = (IMBObjectFilter)[inSender tag];
	[inSender setState:NSControlStateValueOn];
	[[self objectArrayController] rearrangeObjects];
	[self.view setNeedsDisplay:YES];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Dragging

- (NSArray*) draggingTypesForWritingToPasteboard
{
	return @[kIMBObjectPasteboardType,(NSString*)kUTTypeFileURL];
}

// Filter the dragged indexes to only include the selectable (and thus draggable) ones...

- (NSIndexSet*) filteredDraggingIndexes:(NSIndexSet*)inIndexes
{
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	
	NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
	NSUInteger index = [inIndexes firstIndex];
	
	while (index != NSNotFound)
	{
		IMBObject* object = [objects objectAtIndex:index];
		if (object.isSelectable && (object.accessibility == kIMBResourceIsAccessible ||
									object.accessibility == kIMBResourceIsAccessibleSecurityScoped)) {
            [indexes addIndex:index];
        }
		index = [inIndexes indexGreaterThanIndex:index];
	}
	
	return indexes;
}

- (NSPasteboardItem *) pasteboardItemForDraggingObjectAtIndex:(NSInteger)inIndex
{
	NSPasteboardItem* pasteboardItem = nil;
	NSArray* allObjects = [ibObjectArrayController arrangedObjects];
	if (inIndex < [allObjects count])
	{
		IMBObject* object = [allObjects objectAtIndex:inIndex];

		// We don't allow non-selectable objects to be dragged either
		if (object.isSelectable && (object.accessibility == kIMBResourceIsAccessible ||
									object.accessibility == kIMBResourceIsAccessibleSecurityScoped))
		{
			pasteboardItem = [[NSPasteboardItem alloc] init];
			[pasteboardItem setDataProvider:object forTypes:[self draggingTypesForWritingToPasteboard]];
		}
	}

	return [pasteboardItem autorelease];
}

#pragma mark - Open Media Files

// Double-clicking and IMBNodeObject (folder icon) in the object view expands and selects the represented node. 
// The result is that we are drilling into that "folder"...

- (void) expandNodeObject:(IMBNodeObject*)inNodeObject
{
	if ([inNodeObject isKindOfClass:[IMBNodeObject class]])
	{
		NSString* identifier = inNodeObject.representedNodeIdentifier;
		IMBNode* node = [self.libraryController nodeWithIdentifier:identifier];

		[[NSNotificationCenter defaultCenter] 
			postNotificationName:kIMBExpandAndSelectNodeWithIdentifierNotification 
			object:nil 
			userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				self,@"objectViewController",
				node,@"node",
				nil]];
	}
}


// Open the selected objects...

- (IBAction) openSelectedObjects:(id)inSender
{
	NSArray* objects = [ibObjectArrayController selectedObjects];
	[self openObjects:objects];
}


// Open the specified objects. Please note that in sandboxed applications (which usually do not have the necessary
// rights to access arbitrary media files) this requires an asynchronous round trip to an XPC service. Once we do
// get the bookmark, we can resolve it to a URL that we can access. Open it in the default app...
	
- (void) openObjects:(NSArray*)inObjects
{
	NSString* appPath = nil;
	if (appPath == nil) appPath = [IMBConfig editorAppForMediaType:self.mediaType];
	if (appPath == nil) appPath = [IMBConfig viewerAppForMediaType:self.mediaType];
	
	for (IMBObject* object in inObjects)
	{
		if (object.accessibility == kIMBResourceIsAccessible ||
            object.accessibility == kIMBResourceIsAccessibleSecurityScoped)
		{
			[object requestBookmarkWithCompletionBlock:^(NSError* inError)
			{
				if (inError)
				{
					[NSApp presentError:inError];
				}
				else
				{
					NSURL* url = [object URLByResolvingBookmark];
					
					if (url)
					{
						if (appPath != nil && [url isFileURL])
						{
							[[NSWorkspace imb_threadSafeWorkspace] openFile:url.path withApplication:appPath];
						}
						else
						{
							[[NSWorkspace imb_threadSafeWorkspace] openURL:url];
						}
					}
				}
			}];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QuickLook


// Toggle the visibility of the Quicklook panel...

- (IBAction) quicklook:(id)inSender
{
	if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
	{
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	}
	else
	{
        // Quick Look only works if app is active (may yet not be active if we triggered action through contextual menu)
        
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        [ibTabView.window makeKeyWindow];   // Important to make key event handling work correctly!
        
		QLPreviewPanel* QLPanel = [QLPreviewPanel sharedPreviewPanel];

        // Since app activation (see above) is not necessarily performed immediately
        // (Apple: "you should not assume the application will be active immediately after sending this message")
        // we perform subsequent method through the run loop with a little delay to try to keep execution order.
        // Note, that merely going through the runloop with delay of 0.0 did not cut it
        
        [QLPanel performSelector:@selector(orderFront:) withObject:nil afterDelay:0.05];
    }
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook datasource methods...

- (NSArray*) filteredSelectedObjects
{
	NSArray* objects = [ibObjectArrayController selectedObjects];
	NSMutableArray* filteredObjects = [NSMutableArray arrayWithCapacity:objects.count];
	
	for (IMBObject* object in objects)
	{
		if (object.accessibility == kIMBResourceIsAccessible ||
            object.accessibility == kIMBResourceIsAccessibleSecurityScoped) {
            [filteredObjects addObject:object];
        }
	}
	
	return (NSArray*)filteredObjects;
}


- (NSInteger) numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel*)inPanel
{
	NSArray* objects = [self filteredSelectedObjects];
	return objects.count;
}


- (id<QLPreviewItem>) previewPanel:(QLPreviewPanel*)inPanel previewItemAtIndex:(NSInteger)inIndex
{
	NSArray* objects = [self filteredSelectedObjects];

	if (inIndex >= 0 && inIndex < objects.count)
	{
		return [objects objectAtIndex:inIndex];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook delegate methods...

- (BOOL) previewPanel:(QLPreviewPanel*)inPanel handleEvent:(NSEvent *)inEvent
{
	NSView* view = [self selectedObjectView];
	
	if ([inEvent type] == NSEventTypeKeyDown)
	{
		[view keyDown:inEvent];
		return YES;
	}
	else if ([inEvent type] == NSEventTypeKeyUp)
	{
		[view keyUp:inEvent];
		return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSRect) previewPanel:(QLPreviewPanel*)inPanel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)inItem
{
	NSInteger index = [ibObjectArrayController.arrangedObjects indexOfObjectIdenticalTo:inItem];
	NSRect frame = NSZeroRect;
	NSView* view = nil;
	NSCell* cell = nil;
	
	if (index != NSNotFound)
	{
		if (_viewType == kIMBObjectViewTypeIcon)
		{
			frame = [ibIconView frameForItemAtIndex:index];
			view = ibIconView;
		}	
		else if (_viewType == kIMBObjectViewTypeList)
		{
			frame = [ibListView frameOfCellAtColumn:0 row:index];
			cell = [[[ibListView tableColumns] objectAtIndex:0] dataCellForRow:index];
			frame = [cell imageRectForBounds:frame];
			view = ibListView;
		}	
		else if (_viewType == kIMBObjectViewTypeCombo)
		{
			frame = [ibComboView frameOfCellAtColumn:0 row:index];
			cell = [[[ibComboView tableColumns] objectAtIndex:0] dataCellForRow:index];
			frame = [cell imageRectForBounds:frame];
			view = ibComboView;
		}	
	}

	if (view)
	{
		// The old convertRectToBase: and convertBaseToScreen: methods are deprecated and
		// the use of them here doesn't work correctly on a Retina screen (the calculated
		// frame is out of bounds of the target view).
		//
		// If we're building for a deployment of 10.6+ then we need to take care not to call
		// the 10.7+ methods that handle Retina conversion correctly. The good news is because
		// the first Retina Macs didn't run 10.6, we can safely assume that where competent
		// calculation of Retina-based frame is required, we will have the benefit of the
		// new convenience method on NSWindow.
#if (!defined(MAC_OS_X_VERSION_10_7) || (MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_7))
#define USE_OLD_CONVERT_METHOD 1
#else
#define USE_OLD_CONVERT_METHOD 0
#endif
#if USE_OLD_CONVERT_METHOD
		if (IMBRunningOnLionOrNewer() == NO)
		{
			frame = [view convertRectToBase:frame];
			frame.origin = [view.window convertBaseToScreen:frame.origin];
		}
		else
		{
#endif
		NSRect windowBasedRect = [view convertRect:frame toView:nil];
		frame = [view.window convertRectToScreen:windowBasedRect];
#if USE_OLD_CONVERT_METHOD
		}
#endif
	}

	return frame;
}


//----------------------------------------------------------------------------------------------------------------------

@end

