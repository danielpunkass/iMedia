//
//  IMBImageSelectionView.m
//  iMedia
//
//  Created by Daniel Jalkut on 2/11/19.
//

#import "IMBImageSelectionView.h"

@implementation IMBImageSelectionView

- (void) setSelected:(BOOL)selected
{
	_selected = selected;

	[self setNeedsDisplay:YES];
}

- (void)setHighlightState:(NSCollectionViewItemHighlightState)highlightState
{
	_highlightState = highlightState;

	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

	[[NSColor clearColor] set];
	NSRectFill(dirtyRect);

	// We just draw a single style of highlighting whether we're selected or proposed to be selected
	BOOL drawsHighlighted = ([self isSelected] || ([self highlightState] == NSCollectionViewItemHighlightForSelection));

	// If we're being deselected we also don't draw a highlight
	if ([self highlightState] == NSCollectionViewItemHighlightForDeselection)
	{
		drawsHighlighted = NO;
	}

	if (drawsHighlighted)
	{
		NSColor* selectionColor = [[NSColor lightGrayColor] colorWithAlphaComponent:0.5];
		[selectionColor set];

		NSRect selectionRect = [self bounds];
		NSBezierPath* selectionPath = [NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:8.0 yRadius:8.0];
		[selectionPath fill];
	}
}

// The combination of overriding hitTest to always return ourself, and
// and overriding acceptsFirstMouse:, allow us to support clicking and dragging
// an icon even when the media manager window is not active.
- (NSView *)hitTest:(NSPoint)point
{
	return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
	return YES;
}

@end
