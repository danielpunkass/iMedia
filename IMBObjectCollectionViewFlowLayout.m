//
//  IMBObjectCollectionViewFlowLayout.m
//  iMedia
//
//  Created by Pierre Bernard on 02.02.20.
//

#import "IMBObjectCollectionViewFlowLayout.h"


@interface IMBObjectCollectionViewFlowLayout ()

@end


@interface NSCollectionViewLayout (Private)

- (NSCollectionViewLayoutAttributes *)layoutAttributesForNextItemInDirection:(NSPoint)direction
															   fromIndexPath:(NSIndexPath *)indexPath
														   constrainedToRect:(NSRect)rect;

@end


@implementation IMBObjectCollectionViewFlowLayout

// NOTE: Apple private API
- (BOOL)_isSingleColumnOrRow
{
	// Enables shift-click range selections
	return YES;
}

// NOTE: Apple private API
- (NSCollectionViewLayoutAttributes *)layoutAttributesForNextItemInDirection:(NSPoint)direction
															   fromIndexPath:(NSIndexPath *)indexPath
														   constrainedToRect:(NSRect)rect
{
	// Allows right and left arrow key selection to wrap to the next / previous line
	if (direction.y == 0) {
		NSCollectionView *collectionView = self.collectionView;

		if (collectionView != nil) {
			NSCollectionViewLayoutAttributes *result = [super layoutAttributesForNextItemInDirection:direction
																					   fromIndexPath:indexPath
																				   constrainedToRect:[collectionView bounds]];

			if (result != nil) {
				return result;
			}

			NSUInteger numberOfSections = [collectionView numberOfSections];

			// hit edge of view
			NSInteger section = -1;
			NSInteger item = - 1;

			if (direction.x == 1) {
				// right
				section = indexPath.section;
				item = indexPath.item + 1;

				while ((section < numberOfSections) && (item >= [collectionView numberOfItemsInSection:section])) {
					item = 0;
					section += 1;
				}
			}
			else if (direction.x == -1) {
				// left
				section = indexPath.section;
				item = indexPath.item - 1;

				while (item < 0) {
					section -= 1;

					if (section < 0) {
						break;
					}

					item = [collectionView numberOfItemsInSection:section] - 1;
				}
			}

			if ((section > -1) && (item > -1) && (section < numberOfSections) && (item < [collectionView numberOfItemsInSection:section])) {
				NSIndexPath *nextIndexPath = [NSIndexPath indexPathForItem:item inSection:section];

				return [self layoutAttributesForItemAtIndexPath:nextIndexPath];
			}
		}
	}

	NSCollectionViewLayoutAttributes *result = [super layoutAttributesForNextItemInDirection:direction
																			   fromIndexPath:indexPath
																		   constrainedToRect:rect];

	return result;
}

@end
