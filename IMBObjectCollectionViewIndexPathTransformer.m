//
//  IMBObjectCollectionViewIndexPathTransformer.m
//  iMedia
//
//  Created by Pierre Bernard on 03.02.20.
//

#import "IMBObjectCollectionViewIndexPathTransformer.h"


@implementation IMBObjectCollectionViewIndexPathTransformer

- (instancetype)init
{
	self = [super init];

	if (self != nil) {
	}

	return self;
}

+ (Class)transformedValueClass
{
	return [NSSet class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSIndexSet class]]) {
		NSMutableSet<NSIndexPath *> *indexPaths = [NSMutableSet setWithCapacity:[(NSIndexSet *)value count]];

		[(NSIndexSet *)value enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
			NSIndexPath *indexPath = [self transformIndex:idx];

			if (indexPath != nil) {
				[indexPaths addObject:indexPath];
			}
		}];

		return indexPaths;
	}
	else if ([value isKindOfClass:[NSNumber class]]) {
		return [self transformIndex:[(NSNumber *)value unsignedIntegerValue]];
	}
	else {
		return nil;
	}
}

- (NSIndexPath *)transformIndex:(NSUInteger)index
{
	return [NSIndexPath indexPathForItem:index inSection:0];
}

- (id)reverseTransformedValue:(id)value
{
	if (![value isKindOfClass:[NSSet class]]) {
		return nil;
	}

	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];

	for (NSIndexPath *indexPath in (NSSet*)value) {
		if (![indexPath isKindOfClass:[NSIndexPath class]]) {
			return nil;
		}

		if (indexPath.length != 1) {
			return nil;
		}

		NSUInteger index = [indexPath indexAtPosition:0];

		[indexes addIndex:index];
	}

	return indexes;
}

@end
