//
//  IMBObjectCollectionViewItem.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import "IMBObjectCollectionViewItem.h"
#import "IMBImageSelectionView.h"

@interface IMBObjectCollectionViewItem ()

@property (assign) IBOutlet IMBImageSelectionView* imageSelectionView;

@end


@implementation IMBObjectCollectionViewItem

- (void)setSelected:(BOOL)selected
{
	[super setSelected:selected];

	[self.imageSelectionView setSelected:selected];
}

- (void)setHighlightState:(NSCollectionViewItemHighlightState)highlightState
{
	[super setHighlightState:highlightState];

	[self.imageSelectionView setHighlightState:highlightState];
}

// Handle right-click by delegating to the collection view itself
- (NSMenu*) menuForEvent:(NSEvent *)event
{
	return [[self collectionView] menuForEvent:event];
}

@end
