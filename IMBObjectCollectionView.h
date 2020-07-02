//
//  IMBObjectCollectionView.h
//  iMedia
//
//  Created by Daniel Jalkut on 2/12/19.
//

#import <Cocoa/Cocoa.h>

@class IMBObjectCollectionView;
@class IMBObject;

NS_ASSUME_NONNULL_BEGIN

@protocol IMBObjectCollectionViewDelegate <NSCollectionViewDelegate>

- (NSMenu*) collectionView:(IMBObjectCollectionView*)collectionView wantsContextMenuForItem:(IMBObject*)itemIndex;

// If clickedItem is nil then the double-click occurred somewhere in the view but not directly on an
// item. The client may still want to handle the double click e.g. to open all selected items.
- (void) collectionView:(IMBObjectCollectionView*)collectionView wasDoubleClickedOnItem:(nullable IMBObject*)clickedItem;

@end

@interface IMBObjectCollectionView : NSCollectionView

// Delegate "type select" to table view
@property (nonatomic, strong, nullable) NSTableView *typeSelectTableView;

// If we are a skimmable view then we use this to track mouse movements
@property (nonatomic, strong, nullable) NSTrackingArea* skimmingTrackingArea;

- (void) enableSkimming;

@end

NS_ASSUME_NONNULL_END
