//
//  CSIconView.m
//  CSIconView
//
//  Created by Alastair Houghton on 22/08/2005.
//  Copyright (c) 2005-2010 Coriolis Systems Limited
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "CSIconView.h"
#import "NSColor+CSIconViewExtras.h"
#import "NSSet+CSSetOperations.h"
#import "NSMutableSet+CSSymmetricDifference.h"

#import <sys/types.h>
#import <unistd.h>

#define FADE_DISTANCE   128
#define UNUSED(x)       ((void)(x))

static NSDictionary *blackTextAttributes;
static NSDictionary *transparentTextAttributes;
static NSDictionary *whiteTextAttributes;
static NSDictionary *grayTextAttributes;
static NSParagraphStyle *centeredStyle;
static NSParagraphStyle *leftStyle;

NSString * const CSIconViewInternalDragData
  = @"CSIconViewInternalDragData";
NSString * const kCSIconView = @"kCSIconView";
NSString * const kCSIconViewItems = @"kCSIconViewItems";

NSString * const CSIconViewDidBeginEditingNotification
  = @"CSIconViewDidBeginEditingNotification";
NSString * const CSIconViewTextDidChangeNotification
  = @"CSIconViewTextDidChangeNotification";
NSString * const CSIconViewDidEndEditingNotification
  = @"CSIconViewDidEndEditingNotification";
NSString * const kCSIconViewFieldEditor
  = @"kCSIconViewFieldEditor";
NSString * const kCSIconViewItem
  = @"kCSIconViewItem";

@interface CSIconView (Internal)

- (void)reloadQuadTree;
- (NSImage *)dragImageFadeImage;
- (NSImage *)draggingImageForSelectedItemsAroundPoint:(NSPoint)point
                                      representedRect:(NSRect *)repRect;

- (void)unregisterDelegateNotifications;
- (void)registerDelegateNotifications;

@end

@implementation CSIconView

+ (void)initialize
{
  NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
  
  centeredStyle = [[NSMutableParagraphStyle alloc] init];
  leftStyle = [[NSMutableParagraphStyle alloc] init];
  [(NSMutableParagraphStyle *)centeredStyle setAlignment:NSCenterTextAlignment];
  [(NSMutableParagraphStyle *)leftStyle setAlignment:NSLeftTextAlignment];
  
  [shadow setShadowOffset:NSMakeSize (0.0, 1.0)];
  [shadow setShadowBlurRadius:0.2];
  
  blackTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSColor textColor], NSForegroundColorAttributeName,
    centeredStyle, NSParagraphStyleAttributeName,
    nil];
  transparentTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSColor whiteColor], NSForegroundColorAttributeName,
    shadow, NSShadowAttributeName,
    centeredStyle, NSParagraphStyleAttributeName,
    nil];
  whiteTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSColor whiteColor], NSForegroundColorAttributeName,
    centeredStyle, NSParagraphStyleAttributeName,
    nil];
  grayTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSColor disabledControlTextColor], NSForegroundColorAttributeName,
    centeredStyle, NSParagraphStyleAttributeName,
    nil];
  
  [blackTextAttributes retain];
  [transparentTextAttributes retain];
  [whiteTextAttributes retain];
  [grayTextAttributes retain];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    maxDragImageSize = NSMakeSize (512.0, 512.0);
    gridSize = NSMakeSize (120.0, 100.0);
    iconSize = NSMakeSize (48.0, 48.0);
    labelPosition = CSLabelPositionBottom;
    snapsToGrid = NO;
    autoArrangesItems = YES;
    allowsCustomSizes = YES;
    allowsDragAndDrop = YES;
    localDraggingSourceMask = NSDragOperationEvery;
    draggingSourceMask = NSDragOperationNone;
    [self registerForDraggedTypes:[NSArray arrayWithObjects:
                                    CSIconViewInternalDragData, nil]];
    [self setBackgroundColor:[NSColor controlBackgroundColor]];
    
    if ([self isOpaque])
      darkTextAttributes = [blackTextAttributes mutableCopy];
    else
      darkTextAttributes = [transparentTextAttributes mutableCopy];
    
    mediumTextAttributes = [grayTextAttributes mutableCopy];
    lightTextAttributes = [whiteTextAttributes mutableCopy];
    
    [self setFont:[NSFont systemFontOfSize:12]];
    
    items = [[NSMutableArray alloc] init];
    selectedItems = [[NSMutableSet alloc] init];
    selectedItemIndices = [[NSMutableIndexSet alloc] init];
    dragSelectedItems = [[NSMutableSet alloc] init];
    renderer = [[CSIconRenderer alloc] init];
    quadTree = [[CSRectQuadTree alloc] initWithBounds:NSMakeRect (0.0f, 0.0f,
								  128.0f, 
								  128.0f)];
    
    [quadTree resizeBoundsForRect:[self bounds]];
    
    needsReload = YES;
    needsArrange = YES;
    
    // Watch for system colour changes
    [[NSNotificationCenter defaultCenter] 
      addObserver:self
         selector:@selector(systemColorsChanged:)
             name:NSSystemColorsDidChangeNotification
           object:nil];
  }
  return self;
}

static NSString * const kMaxDragImageSize = @"kMaxDragImageSize";
static NSString * const kGridSize = @"kGridSize";
static NSString * const kIconSize = @"kIconSize";
static NSString * const kLabelPosition = @"kLabelPosition";
static NSString * const kSnapsToGrid = @"kSnapsToGrid";
static NSString * const kAutoArrangesItems = @"kAutoArrangesItems";
static NSString * const kAllowsCustomSizes = @"kAllowsCustomSizes";
static NSString * const kAllowsDragAndDrop = @"kAllowsDragAndDrop";
static NSString * const kLocalDraggingSourceMask = @"kLocalDraggingSourceMask";
static NSString * const kDraggingSourceMask = @"kDraggingSourceMask";
static NSString * const kBackgroundColor = @"kBackgroundColor";
static NSString * const kDarkTextAttributes = @"kDarkTextAttributes";
static NSString * const kMediumTextAttributes = @"kMediumTextAttributes";
static NSString * const kLightTextAttributes = @"kLightTextAttributes";
static NSString * const kFont = @"kFont";

- (id)initWithCoder:(NSCoder *)coder
{
  @try {
  if ((self = [super initWithCoder:coder])) {
    if ([coder allowsKeyedCoding]) {
      maxDragImageSize = [coder decodeSizeForKey:kMaxDragImageSize];
      gridSize = [coder decodeSizeForKey:kGridSize];
      iconSize = [coder decodeSizeForKey:kIconSize];
      labelPosition = [coder decodeIntForKey:kLabelPosition];
      snapsToGrid = [coder decodeBoolForKey:kSnapsToGrid];
      autoArrangesItems = [coder decodeBoolForKey:kAutoArrangesItems];
      allowsCustomSizes = [coder decodeBoolForKey:kAllowsCustomSizes];
      allowsDragAndDrop = [coder decodeBoolForKey:kAllowsDragAndDrop];
      localDraggingSourceMask = [coder decodeIntForKey:kLocalDraggingSourceMask];
      draggingSourceMask = [coder decodeIntForKey:kDraggingSourceMask];
      [self setBackgroundColor:[coder decodeObjectForKey:kBackgroundColor]];
      darkTextAttributes = [[coder decodeObjectForKey:kDarkTextAttributes]
                             mutableCopy];
      mediumTextAttributes = [[coder decodeObjectForKey:kMediumTextAttributes]
                               mutableCopy];
      lightTextAttributes = [[coder decodeObjectForKey:kLightTextAttributes]
                              mutableCopy];
      [self setFont:[coder decodeObjectForKey:kFont]];
    } else {
      int pos;

      maxDragImageSize = [coder decodeSize];
      gridSize = [coder decodeSize];
      iconSize = [coder decodeSize];
      [coder decodeValueOfObjCType:@encode(int) at:&pos];
      labelPosition = pos;
      [coder decodeValueOfObjCType:@encode(BOOL) at:&snapsToGrid];
      [coder decodeValueOfObjCType:@encode(BOOL) at:&autoArrangesItems];
      [coder decodeValueOfObjCType:@encode(BOOL) at:&allowsCustomSizes];
      [coder decodeValueOfObjCType:@encode(BOOL) at:&allowsDragAndDrop];
      [coder decodeValueOfObjCType:@encode(int)
                                at:&localDraggingSourceMask];
      [coder decodeValueOfObjCType:@encode(int)
                                at:&draggingSourceMask];
      [self setBackgroundColor:[coder decodeObject]];
      darkTextAttributes = [[coder decodeObject] mutableCopy];
      mediumTextAttributes = [[coder decodeObject] mutableCopy];
      lightTextAttributes = [[coder decodeObject] mutableCopy];
      [self setFont:[coder decodeObject]];
    }

    items = [[NSMutableArray alloc] init];
    selectedItems = [[NSMutableSet alloc] init];
    selectedItemIndices = [[NSMutableIndexSet alloc] init];
    dragSelectedItems = [[NSMutableSet alloc] init];
    renderer = [[CSIconRenderer alloc] init];
    quadTree = [[CSRectQuadTree alloc] initWithBounds:NSMakeRect (0.0f, 0.0f,
								  128.0f, 
								  128.0f)];
    
    [quadTree resizeBoundsForRect:[self bounds]];
    
    needsReload = YES;
    needsArrange = autoArrangesItems;

    // Watch for system colour changes
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(systemColorsChanged:)
     name:NSSystemColorsDidChangeNotification
     object:nil];
  }
  } @catch (id e) {
    NSLog (@"%@", e);
    @throw;
  }

  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];

  if ([coder allowsKeyedCoding]) {
    [coder encodeSize:maxDragImageSize forKey:kMaxDragImageSize];
    [coder encodeSize:gridSize forKey:kGridSize];
    [coder encodeSize:iconSize forKey:kIconSize];
    [coder encodeInt:labelPosition forKey:kLabelPosition];
    [coder encodeBool:snapsToGrid forKey:kSnapsToGrid];
    [coder encodeBool:autoArrangesItems forKey:kAutoArrangesItems];
    [coder encodeBool:allowsCustomSizes forKey:kAllowsCustomSizes];
    [coder encodeBool:allowsDragAndDrop forKey:kAllowsDragAndDrop];
    [coder encodeInt:localDraggingSourceMask forKey:kLocalDraggingSourceMask];
    [coder encodeInt:draggingSourceMask forKey:kDraggingSourceMask];
    [coder encodeObject:backgroundColor forKey:kBackgroundColor];
    [coder encodeObject:darkTextAttributes forKey:kDarkTextAttributes];
    [coder encodeObject:mediumTextAttributes forKey:kMediumTextAttributes];
    [coder encodeObject:lightTextAttributes forKey:kLightTextAttributes];
    [coder encodeObject:font forKey:kFont];
  } else {
    int pos = labelPosition;

    [coder encodeSize:maxDragImageSize];
    [coder encodeSize:gridSize];
    [coder encodeSize:iconSize];
    [coder encodeValueOfObjCType:@encode(int) at:&pos];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&snapsToGrid];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&autoArrangesItems];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&allowsCustomSizes];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&allowsDragAndDrop];
    [coder encodeValueOfObjCType:@encode(int) at:&localDraggingSourceMask];
    [coder encodeValueOfObjCType:@encode(int) at:&draggingSourceMask];
    [coder encodeObject:backgroundColor];
    [coder encodeObject:darkTextAttributes];
    [coder encodeObject:mediumTextAttributes];
    [coder encodeObject:lightTextAttributes];
    [coder encodeObject:font];
  }
}

- (void)dealloc
{
  [self unregisterDelegateNotifications];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [dragImageFadeImage release];
  [items release];
  [selectedItems release];
  [selectedItemIndices release];
  [dragSelectedItems release];
  [backgroundColor release];
  [renderer release];
  [font release];
  [darkTextAttributes release];
  [lightTextAttributes release];
  [quadTree release];
  [deselectOnMouseUp release];
  [editOnMouseUp release];
  [super dealloc];
}

- (void)unregisterDelegateNotifications
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  
  if (delegateSupportsDidBeginEditing) {
    [center removeObserver:delegate 
                      name:CSIconViewDidBeginEditingNotification
                    object:self];
  }
  if (delegateSupportsDidEndEditing) {
    [center removeObserver:delegate 
                      name:CSIconViewDidEndEditingNotification
                    object:self];
  }
  if (delegateSupportsTextDidChange) {
    [center removeObserver:delegate 
                      name:CSIconViewTextDidChangeNotification
                    object:self];
  }
}

- (void)registerDelegateNotifications
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  delegateSupportsDidBeginEditing 
    = [delegate respondsToSelector:@selector(iconViewDidBeginEditing:)];
  delegateSupportsDidEndEditing
    = [delegate respondsToSelector:@selector(iconViewDidEndEditing:)];
  delegateSupportsTextDidChange
    = [delegate respondsToSelector:@selector(iconViewTextDidChange:)];
  
  if (delegateSupportsDidBeginEditing) {
    [center addObserver:delegate
               selector:@selector(iconViewDidBeginEditing:)
                   name:CSIconViewDidBeginEditingNotification
                 object:self];
  }
  if (delegateSupportsDidEndEditing) {
    [center addObserver:delegate
               selector:@selector(iconViewDidEndEditing:)
                   name:CSIconViewDidEndEditingNotification
                 object:self];
  }
  if (delegateSupportsTextDidChange) {
    [center addObserver:delegate
               selector:@selector(iconViewTextDidChange:)
                   name:CSIconViewTextDidChangeNotification
                 object:self];
  }
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)dlg
{
  [self unregisterDelegateNotifications];
  
  delegate = dlg;

  [self registerDelegateNotifications];
}

- (id)target
{
  return target;
}

- (void)setTarget:(id)tgt
{
  // NO RETAIN
  target = tgt;
}

- (SEL)action
{
  return action;
}

- (void)setAction:(SEL)act
{
  action = act;
}

- (void)viewWillMoveToWindow:(NSWindow *)aWindow
{
  UNUSED (aWindow);
  
  NSWindow *oldWindow = [self window];
  
  if (oldWindow) {
    [[NSNotificationCenter defaultCenter] 
      removeObserver:self
                name:NSWindowDidBecomeKeyNotification
              object:oldWindow];
    [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSWindowDidResignKeyNotification
              object:oldWindow];
  }
}

- (void)viewDidMoveToWindow
{
  NSWindow *window = [self window];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(keyWindowChanged:)
           name:NSWindowDidBecomeKeyNotification
         object:window];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(keyWindowChanged:)
           name:NSWindowDidResignKeyNotification
         object:window];
}

- (void)keyWindowChanged:(NSNotification *)aNotification
{
  UNUSED (aNotification);
  
  [self setDrawsFocusRing:NO];
  [self setNeedsDisplay:YES];
}

- (void)systemColorsChanged:(NSNotification *)aNotification
{
  UNUSED (aNotification);
  
  [self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)updateSize
{
  NSRect superBounds = [[self superview] bounds];
  NSRect bounds = [quadTree objectBounds];
  NSSize newSize = NSMakeSize (NSMaxX (bounds), NSMaxY (bounds));

  if (newSize.width < NSWidth (superBounds)
      || autoArrangesItems)
    newSize.width = NSWidth (superBounds);
  if (newSize.height < NSHeight (superBounds))
    newSize.height = NSHeight (superBounds);

  [self setFrameSize:newSize];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
  UNUSED (oldSize);
  
  [self updateSize];
}

- (BOOL)needsArrange
{
  return needsArrange;
}

- (void)setNeedsArrange:(BOOL)newNeedsArrange
{
  needsArrange = newNeedsArrange;
}

- (void)setFrame:(NSRect)frame
{
  NSRect bounds;
  
  [super setFrame:frame];
  
  bounds = [self bounds];
  [quadTree resizeBoundsForRect:bounds];

  if ([self autoArrangesItems] && !doingArrange) {
    unsigned newGridWidth = floor (bounds.size.width / gridSize.width);
    
    if (newGridWidth < 1)
      newGridWidth = 1;
    
    if (newGridWidth != gridWidth)
      [self setNeedsArrange:YES];
  }
}

- (void)setFrameSize:(NSSize)frameSize
{
  NSRect bounds;
  
  [super setFrameSize:frameSize];
  
  bounds = [self bounds];
  [quadTree resizeBoundsForRect:bounds];
  
  if ([self autoArrangesItems] && !doingArrange) {
    unsigned newGridWidth = floor (bounds.size.width / gridSize.width);
    
    if (newGridWidth < 1)
      newGridWidth = 1;
    
    if (newGridWidth != gridWidth)
      [self setNeedsArrange:YES];
  }
}

- (void)drawRect:(NSRect)rect
{
  if (needsReload) {
    needsReload = NO;
    [self reloadItems];
  }
  
  if ([self needsArrange]) {
    [self arrangeItems];
    [self setNeedsArrange:NO];
    gridWidth = floor ([self bounds].size.width / gridSize.width);
    if (gridWidth < 1)
      gridWidth = 1;
  }
  
  NSSet *renderItems = [quadTree objectsIntersectingRect:rect];
  NSEnumerator *itemEnum = [renderItems objectEnumerator];
  CSIconViewItem *item;
  BOOL selected;
  BOOL isKeyView = ([[self window] isKeyWindow]
                    && [[self window] firstResponder] == self);
  
  [backgroundColor set];
  NSRectFill (rect);

  while ((item = [itemEnum nextObject])) {
    NSPoint pos = [item position];
    NSRect frame = NSMakeRect (pos.x, pos.y,
			       gridSize.width, gridSize.height);
    unsigned itemState = [item state];
    
    if (itemState & kCSIVItemLabelledMask) {
      NSColor *labelColor = [item labelColor];
      NSColor *labelShadeColor = [item labelShadeColor];
      
      if (!labelShadeColor) {
	labelShadeColor
	  = [labelColor blendedColorWithFraction:0.8
					 ofColor:[NSColor whiteColor]];
      }
      
      [renderer setLabelColor:labelColor];
      [renderer setLabelShadeColor:labelShadeColor];
    } else {
      [renderer setLabelColor:nil];
      [renderer setLabelShadeColor:nil];
    }
    
    if (allowsCustomSizes && (itemState & kCSIVItemCustomSizeMask)) {
      [renderer setIconSize:[item customIconSize]];
      frame.size = [item customSize];
    } else {
      [renderer setIconSize:iconSize];
    }
    
    [renderer setIcon:[item icon]];
    [renderer setTitle:[item title]];
    
    selected = (itemState & kCSIVItemSelectedMask) ? YES : NO;
    
    if (dragging && [dragSelectedItems containsObject:item])
      selected = !selected;
    
    if (drawOnlySelected && !selected)
      continue;
    
    if (itemState & kCSIVItemDisabledMask) {
      [renderer setTitleAttributes:mediumTextAttributes];
    } else if (itemState & kCSIVItemLabelledMask) {
      if ([item labelColorIsLight])
	[renderer setTitleAttributes:darkTextAttributes];
      else
	[renderer setTitleAttributes:lightTextAttributes];
    } else if (selected) {
      if (!isKeyView)
        [renderer setTitleAttributes:mediumTextAttributes];
      else
        [renderer setTitleAttributes:lightTextAttributes];
    } else {
      [renderer setTitleAttributes:darkTextAttributes];
    }
    
    if (itemState & kCSIVItemOpenMask)
      [renderer setVariant:kCSOpenIconVariant];
    else if (itemState & kCSIVItemAcceptingDropMask)
      [renderer setVariant:kCSDropIconVariant];
    else
      [renderer setVariant:kCSNormalIconVariant];
    
    [renderer drawWithFrame:frame
		    enabled:!(itemState & kCSIVItemDisabledMask)
		highlighted:selected
	    filledHighlight:[self isOpaque]
		textOnRight:[self labelPosition] == CSLabelPositionRight
                  inKeyView:isKeyView
                   withText:!isEditing || item != editingItem];
  }

  if (dragging) {
    [[[NSColor lightGrayColor] colorWithAlphaComponent:0.5] set];
    NSRectFillUsingOperation (dragRect, NSCompositeSourceOver);
    [[NSColor lightGrayColor] set];
    NSFrameRect (dragRect);
  }
  
  if (isKeyView && drawsFocusRing && focusedItem) {
    NSPoint itemPos = [focusedItem position];
    unsigned itemState = [focusedItem state];
    NSSize itemSize;
    NSRect focusRect;

    if (itemState & kCSIVItemCustomSizeMask)
      itemSize = [focusedItem customSize];
    else
      itemSize = gridSize;
    
    focusRect = NSMakeRect (itemPos.x, itemPos.y,
                            itemSize.width, itemSize.height);

    NSBezierPath *focusPath = [NSBezierPath bezierPath];
    const float focusRadius = 5.0;
    
    [focusPath moveToPoint:NSMakePoint (NSMinX (focusRect) + focusRadius,
                                        NSMinY (focusRect))];
    [focusPath appendBezierPathWithArcFromPoint:NSMakePoint (NSMaxX (focusRect),
                                                             NSMinY (focusRect))
                                        toPoint:NSMakePoint (NSMaxX (focusRect),
                                                             NSMinY (focusRect) + focusRadius)
                                         radius:focusRadius];
    [focusPath appendBezierPathWithArcFromPoint:NSMakePoint (NSMaxX (focusRect),
                                                             NSMaxY (focusRect))
                                        toPoint:NSMakePoint (NSMaxX (focusRect) - focusRadius,
                                                             NSMaxY (focusRect))
                                         radius:focusRadius];
    [focusPath appendBezierPathWithArcFromPoint:NSMakePoint (NSMinX (focusRect),
                                                             NSMaxY (focusRect))
                                        toPoint:NSMakePoint (NSMinX (focusRect),
                                                             NSMaxY (focusRect) - focusRadius)
                                         radius:focusRadius];
    [focusPath appendBezierPathWithArcFromPoint:NSMakePoint (NSMinX (focusRect),
                                                             NSMinY (focusRect))
                                        toPoint:NSMakePoint (NSMinX (focusRect) + focusRadius,
                                                             NSMinY (focusRect))
                                         radius:focusRadius];
    [focusPath closePath];
    
    [focusPath setLineWidth:4.0];
    
    [[NSColor selectedControlColor] set];
    [focusPath stroke];
  }
  
  // If we're editing, render the focus rect for the editor
  if (isEditing) {
    [NSGraphicsContext saveGraphicsState];
    NSSetFocusRingStyle(NSFocusRingBelow);
    [backgroundColor set];
    NSRectFill(keyboardFocusRect);
    [NSGraphicsContext restoreGraphicsState];
  }
  
  /* Uncomment this to see the quadtree */
  // [quadTree stroke];
}

- (NSSize)maxDragImageSize
{
  return maxDragImageSize;
}

- (void)setMaxDragImageSize:(NSSize)newSize
{
  if (newSize.width < 2 * FADE_DISTANCE)
    newSize.width = 2 * FADE_DISTANCE;
  if (newSize.height < 2 * FADE_DISTANCE)
    newSize.height = 2 * FADE_DISTANCE;
  
  maxDragImageSize = newSize;
}

- (NSSize)gridSize
{
  return gridSize;
}

- (void)setGridSize:(NSSize)newSize
{
  gridSize = newSize;
}

- (NSSize)iconSize
{
  return iconSize;
}

- (void)setIconSize:(NSSize)newSize
{
  iconSize = newSize;
}

- (NSFont *)font
{
  return font;
}

- (void)setFont:(NSFont *)newFont
{
  if (font != newFont) {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *boldFont;
    NSFont *oldFont = font;
    font = [newFont retain];
    [oldFont release];
    
    if (![self isOpaque]) {
      boldFont = [fontManager convertFont:font toHaveTrait:NSBoldFontMask];
      [darkTextAttributes setObject:boldFont forKey:NSFontAttributeName];
    } else {
      [darkTextAttributes setObject:font forKey:NSFontAttributeName];
    }
    
    [mediumTextAttributes setObject:font forKey:NSFontAttributeName];
    [lightTextAttributes setObject:font forKey:NSFontAttributeName];
  }
}

- (BOOL)isOpaque
{
  return isOpaque;
}

- (void)setIsOpaque:(BOOL)opaque
{
  if (isOpaque == opaque)
    return;
  
  isOpaque = opaque;
  
  if ([self isOpaque]) {
    [darkTextAttributes release];
    darkTextAttributes = [blackTextAttributes mutableCopy];
  } else {
    [darkTextAttributes release];
    darkTextAttributes = [transparentTextAttributes mutableCopy];
  }
  
  // Reset the extra attributes
  [self setFont:[self font]];
  [self setLabelPosition:[self labelPosition]];
}

- (CSIconViewLabelPosition)labelPosition
{
  return labelPosition;
}

- (void)setLabelPosition:(CSIconViewLabelPosition)newPosition
{
  labelPosition = newPosition;
  
  if (labelPosition == CSLabelPositionRight) {
    [darkTextAttributes setObject:leftStyle
			   forKey:NSParagraphStyleAttributeName];
    [mediumTextAttributes setObject:leftStyle
			     forKey:NSParagraphStyleAttributeName];
    [lightTextAttributes setObject:leftStyle
			    forKey:NSParagraphStyleAttributeName];
  } else {
    [darkTextAttributes setObject:centeredStyle
			   forKey:NSParagraphStyleAttributeName];
    [mediumTextAttributes setObject:centeredStyle
			     forKey:NSParagraphStyleAttributeName];
    [lightTextAttributes setObject:centeredStyle 
			    forKey:NSParagraphStyleAttributeName];
  }
}

- (BOOL)snapsToGrid
{
  return snapsToGrid;
}

- (void)setSnapsToGrid:(BOOL)shouldSnap
{
  snapsToGrid = shouldSnap;
}

- (BOOL)autoArrangesItems
{
  return autoArrangesItems;
}

- (void)setAutoArrangesItems:(BOOL)shouldArrange
{
  autoArrangesItems = shouldArrange;
  
  if (autoArrangesItems) {
    NSRect superBounds = [[self superview] bounds];
    
    [self setFrameSize:superBounds.size];
    [self setAutoresizingMask:NSViewWidthSizable];
    [self setNeedsArrange:YES];
    [self setNeedsDisplay:YES];
  }
}

- (BOOL)allowsCustomSizes
{
  return allowsCustomSizes;
}

- (void)setAllowsCustomSizes:(BOOL)allows
{
  allowsCustomSizes = allows;
}

- (void)updateDragAndDropTypeRegistration
{
  if (allowsDragAndDrop) {
    NSMutableArray *types = [NSMutableArray arrayWithObjects:
                              CSIconViewInternalDragData,
                              nil];

    if (dataSource && [dataSource respondsToSelector:
    @selector(iconViewAcceptedPasteboardTypesForDrop:)]) {
      [types addObjectsFromArray:
        [dataSource iconViewAcceptedPasteboardTypesForDrop:self]];
    }

    [self registerForDraggedTypes:types];
  } else {
    [self unregisterDraggedTypes];
  }
}

- (BOOL)allowsDragAndDrop
{
  return allowsDragAndDrop;
}

- (void)setAllowsDragAndDrop:(BOOL)allows
{
  if (allowsDragAndDrop == allows)
    return;

  allowsDragAndDrop = allows;
  
  [self updateDragAndDropTypeRegistration];
}

- (NSColor *)backgroundColor
{
  return backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)newColor
{
  if (newColor != backgroundColor) {
    NSColor *oldColor = backgroundColor;
    backgroundColor = newColor;
    [oldColor release];
    
    if ([backgroundColor alphaComponent] == 1.0f)
      [self setIsOpaque:YES];
    else
      [self setIsOpaque:NO];
  }
}

- (id)dataSource
{
  return dataSource;
}

- (void)setDataSource:(id)newSource
{
  // NO RETAIN!
  dataSource = newSource;

  [self updateDragAndDropTypeRegistration];
}

- (NSArray *)items
{
  return items;
}

- (void)reloadItems
{
  unsigned n, count = [dataSource numberOfItemsInIconView:self];
  
  [items removeAllObjects];
  [quadTree removeAllObjects];
  for (n = 0; n < count; ++n) {
    CSIconViewItem *item = [dataSource iconView:self itemAtIndex:n];
    NSPoint pos = [item position];
    NSRect itemFrame = NSMakeRect (pos.x, pos.y,
				   gridSize.width, gridSize.height);
    
    if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
      itemFrame.size = [item customSize];

    [item setIndex:n];
    [items addObject:item];
    [quadTree addObject:item withBounds:itemFrame];
  }

  if ([self autoArrangesItems])
    [self setNeedsArrange:YES];
  
  [self setNeedsDisplay:YES];
}

- (void)reloadQuadTree
{
  unsigned n, count = [items count];
  
  [quadTree removeAllObjects];
  for (n = 0; n < count; ++n) {
    CSIconViewItem *item = [items objectAtIndex:n];
    NSPoint pos = [item position];
    NSRect itemFrame = NSMakeRect (pos.x, pos.y,
				   gridSize.width, gridSize.height);
    
    if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
      itemFrame.size = [item customSize];
    
    [quadTree addObject:item withBounds:itemFrame];
  }  
}

- (void)arrangeItems
{
  unsigned n, count = [items count];
  NSRect bounds = [self bounds];
  NSPoint pos = NSMakePoint (NSMinX (bounds), NSMinY (bounds));
  
  doingArrange = YES;
  [self resetKeyboardMovement];

  [quadTree removeAllObjects];
  for (n = 0; n < count; ++n) {
    CSIconViewItem *item = [items objectAtIndex:n];
    NSRect itemFrame = NSMakeRect (pos.x, pos.y,
				   gridSize.width, gridSize.height);
    NSSize itemSize = gridSize;
    
    if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask)) {
      itemSize = [item customSize];
      itemFrame = NSMakeRect (pos.x, pos.y,
			      itemSize.width, itemSize.height);
    }
    
    if (allowsCustomSizes) {
      NSAutoreleasePool *pool = nil;
      NSSet *intersectingItems;
      unsigned count = 0;
      
      for (;;) {
	if (++count >= 100) {
	  count = 0;
	  [pool release];
	  pool = [[NSAutoreleasePool alloc] init];
	}

	intersectingItems = [quadTree objectsIntersectingRect:itemFrame];
	
	if (!intersectingItems || ![intersectingItems count])
	  break;
	
	pos.x += gridSize.width;
	
	if (pos.x + gridSize.width > NSMaxX (bounds)) {
	  pos.x = 0;
	  pos.y += gridSize.height;
	}

	itemFrame.origin = pos;
      }
      
      [pool release];
    }
    
    [item setPosition:pos];
    [quadTree addObject:item withBounds:itemFrame];
    
    do {
      pos.x += gridSize.width;
    } while (NSPointInRect (pos, itemFrame)
	     && pos.x + gridSize.width <= NSMaxX (bounds));
    
    if (pos.x + gridSize.width > NSMaxX (bounds)) {
      pos.x = 0;
      pos.y += gridSize.height;
    }
  }
  
  [self updateSize];
  
  doingArrange = NO;
}

- (NSSet *)itemsInRect:(NSRect)rect
{
  return [quadTree objectsInRect:rect];
}

#pragma mark Selection Handling

- (NSSet *)selectedItems
{
  return selectedItems;
}

- (NSIndexSet *)selectedItemIndices
{
  return selectedItemIndices;
}

- (void)deselectItem:(CSIconViewItem *)item
{
  NSPoint pos = [item position];
  NSSize size;
  NSRect itemRect;
  
  if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
    size = [item customSize];
  else
    size = gridSize;
  
  itemRect = NSMakeRect (pos.x, pos.y, size.width, size.height);
  
  [selectedItemIndices removeIndex:[item index]];
  [selectedItems removeObject:item];
  [item deselect];

  [self resetKeyboardMovement];
  
  [self setNeedsDisplayInRect:itemRect];
}

- (void)deselectItemAtIndex:(unsigned)ndx
{
  CSIconViewItem *item = [items objectAtIndex:ndx];
  [self deselectItem:item];

  [self resetKeyboardMovement];
}

- (void)deselectItems:(id)deselItems
{
  NSRect itemRect = [self boundingRectOfItems:deselItems];
  
  if ([deselItems respondsToSelector:@selector(objectEnumerator)]) {
    NSEnumerator *itemEnum = [deselItems objectEnumerator];
    CSIconViewItem *item;
    
    if ([deselItems respondsToSelector:
	  @selector(makeObjectsPerformSelector:)]) {
      [deselItems makeObjectsPerformSelector:@selector(deselect)];
      while ((item = [itemEnum nextObject])) {
	[selectedItems removeObject:item];
        [selectedItemIndices removeIndex:[item index]];
      }
    } else {
      while ((item = [itemEnum nextObject])) {
	[item deselect];
	[selectedItems removeObject:item];
        [selectedItemIndices removeIndex:[item index]];
      }
    }
  } else if ([deselItems isKindOfClass:[NSIndexSet class]]) {
    NSUInteger ndx;

    for (ndx = [deselItems firstIndex]; ndx != NSNotFound; 
         ndx = [deselItems indexGreaterThanIndex:ndx]) {
      CSIconViewItem *item = [items objectAtIndex:ndx];
      [item deselect];
      [selectedItems removeObject:item];
      [selectedItemIndices removeIndex:ndx];
    }
  } else {
    [NSException raise:@"CSBadArgumentException"
		format:@"Object passed into -deselectItems: must be a collection."];
  }
  
  [self resetKeyboardMovement];
  
  [self setNeedsDisplayInRect:itemRect];
}

- (void)selectItem:(CSIconViewItem *)item
{
  NSPoint pos = [item position];
  NSSize size;
  NSRect itemRect;
  
  if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
    size = [item customSize];
  else
    size = gridSize;
  
  itemRect = NSMakeRect (pos.x, pos.y, size.width, size.height);
  
  [selectedItems addObject:item];
  [selectedItemIndices addIndex:[item index]];
  [item select];
    
  [self resetKeyboardMovement];

  [self setNeedsDisplayInRect:itemRect];
}

- (void)selectItemAtIndex:(unsigned)ndx
{
  CSIconViewItem *item = [items objectAtIndex:ndx];
  [self selectItem:item];
  
  [self resetKeyboardMovement];
}

- (void)selectItems:(id)newItems
{
  NSRect itemRect = [self boundingRectOfItems:newItems];
  
  if ([newItems isKindOfClass:[NSArray class]]) {
    NSEnumerator *objEnum = [newItems objectEnumerator];
    CSIconViewItem *item;

    [newItems makeObjectsPerformSelector:@selector(select)];
    [selectedItems addObjectsFromArray:newItems];
    while ((item = [objEnum nextObject]))
      [selectedItemIndices addIndex:[item index]];
  } else if ([newItems isKindOfClass:[NSSet class]]) {
    NSEnumerator *objEnum = [newItems objectEnumerator];
    CSIconViewItem *item;

    [newItems makeObjectsPerformSelector:@selector(select)];
    [selectedItems unionSet:newItems];
    while ((item = [objEnum nextObject]))
      [selectedItemIndices addIndex:[item index]];
  } else if ([newItems respondsToSelector:@selector(objectEnumerator)]) {
    NSEnumerator *itemEnum = [newItems objectEnumerator];
    CSIconViewItem *item;
    
    if ([newItems respondsToSelector:@selector(makeObjectsPerformSelector:)]) {
      [newItems makeObjectsPerformSelector:@selector(select)];
      while ((item = [itemEnum nextObject])) {
	[selectedItems addObject:item];
        [selectedItemIndices addIndex:[item index]];
      }
    } else {
      while ((item = [itemEnum nextObject])) {
	[item select];
	[selectedItems addObject:item];
        [selectedItemIndices addIndex:[item index]];
      }
    }
  } else if ([newItems isKindOfClass:[NSIndexSet class]]) {
    NSUInteger ndx;

    for (ndx = [newItems firstIndex]; ndx != NSNotFound; 
         ndx = [newItems indexGreaterThanIndex:ndx]) {
      CSIconViewItem *item = [items objectAtIndex:ndx];
      [item select];
      [selectedItems addObject:item];
      [selectedItemIndices addIndex:ndx];
    }    
  } else {
    [NSException raise:@"CSBadArgumentException"
		format:@"Object passed into -selectItems: must be a collection."];
  }
  
  [self resetKeyboardMovement];
  
  [self setNeedsDisplayInRect:itemRect];
}

- (void)deselectAll
{
  NSRect rect = [self boundingRectOfSelectedItems];
  
  [selectedItems makeObjectsPerformSelector:@selector(deselect)];
  [selectedItems removeAllObjects];
  [selectedItemIndices removeAllIndexes];
  
  [self resetKeyboardMovement];
  
  [self setNeedsDisplayInRect:rect];
}

- (CSIconViewItem  *)focusedItem
{
  return focusedItem;
}

- (void)setFocusedItem:(CSIconViewItem *)item
{
  if (item != focusedItem) {
    CSIconViewItem *oldItem = focusedItem;
    focusedItem = [item retain];
    
    if (drawsFocusRing) {
      if (oldItem) {
        unsigned itemState = [oldItem state];
        NSPoint itemPos = [oldItem position];
        NSSize itemSize;
        NSRect itemRect;
        
        if (itemState & kCSIVItemCustomSizeMask)
          itemSize = [oldItem customSize];
        else
          itemSize = gridSize;
        
        itemRect = NSMakeRect (itemPos.x, itemPos.y,
                               itemSize.width, itemSize.height);
        
        [self setNeedsDisplayInRect:NSInsetRect (itemRect, -2.0, -2.0)];
      }
      
      if (item) {
        unsigned itemState = [item state];
        NSPoint itemPos = [item position];
        NSSize itemSize;
        NSRect itemRect;
        
        if (itemState & kCSIVItemCustomSizeMask)
          itemSize = [item customSize];
        else
          itemSize = gridSize;
        
        itemRect = NSMakeRect (itemPos.x, itemPos.y,
                               itemSize.width, itemSize.height);
        
        [self setNeedsDisplayInRect:NSInsetRect (itemRect, -2.0, -2.0)];
      }
    }
  }
}

- (BOOL)drawsFocusRing
{
  return drawsFocusRing;
}

- (void)setDrawsFocusRing:(BOOL)dfr
{
  BOOL changed = (drawsFocusRing != dfr);
  
  drawsFocusRing = dfr;

  if (changed && focusedItem) {
    unsigned itemState = [focusedItem state];
    NSPoint itemPos = [focusedItem position];
    NSSize itemSize;
    NSRect itemRect;
    
    if (itemState & kCSIVItemCustomSizeMask)
      itemSize = [focusedItem customSize];
    else
      itemSize = gridSize;
    
    itemRect = NSMakeRect (itemPos.x, itemPos.y,
                           itemSize.width, itemSize.height);
    
    [self setNeedsDisplayInRect:NSInsetRect (itemRect, -2.0, -2.0)];
  }
}

#pragma mark Mouse event handling

- (void)mouseDown:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    NSPoint pos = [self convertPoint:[event locationInWindow]
			    fromView:nil];
    NSPoint itemPos;
    NSRect frame;
    NSSet *itemsAtPoint = [quadTree objectsAtPoint:pos];
    NSEnumerator *itemEnum = [itemsAtPoint objectEnumerator];
    CSIconViewItem *item;
    BOOL foundItem = NO;

    if ([[self window] firstResponder] != self)
      [[self window] makeFirstResponder:self];
    
    // Remove the focus here (the focus is for keyboard selection)
    [self setFocusedItem:nil];
    
    while (!foundItem && (item = [itemEnum nextObject])) {
      unsigned state = [item state];

      if (state & kCSIVItemDisabledMask)
        continue;
      
      itemPos = [item position];
      frame = NSMakeRect (itemPos.x, itemPos.y, gridSize.width, gridSize.height);
    
      if (allowsCustomSizes && (state & kCSIVItemCustomSizeMask)) {
        [renderer setIconSize:[item customIconSize]];
        frame.size = [item customSize];
      } else {
        [renderer setIconSize:iconSize];
      }
    
      [renderer setIcon:[item icon]];
      [renderer setTitle:[item title]];
    
      if ([renderer intersectsWithRect:NSMakeRect (pos.x, pos.y, 1, 1)
                      ifDrawnWithFrame:frame
                           highlighted:state & kCSIVItemSelectedMask
                           textOnRight:([self labelPosition]
                                        == CSLabelPositionRight)]) {
        if ([event modifierFlags] & (NSShiftKeyMask | NSCommandKeyMask)) {
          if (state & kCSIVItemSelectedMask) {
            /* If we're deselecting something, we need to do it on mouse up,
               and we only deselect in any event if this doesn't become a
               drag. */
            if (!deselectOnMouseUp)
              deselectOnMouseUp = [[NSMutableSet alloc] init];
            else
              [deselectOnMouseUp removeAllObjects];
            
            [deselectOnMouseUp addObject:item];
          } else
            [self selectItem:item];
        } else if ([event modifierFlags] & NSAlternateKeyMask) {
          if (state & kCSIVItemSelectedMask) {
            /* If we're deselecting something, we need to do it on mouse up,
               and we only deselect in any event if this doesn't become a
               drag. */
            if (!deselectOnMouseUp)
              deselectOnMouseUp = [[NSMutableSet alloc] init];
            else
              [deselectOnMouseUp removeAllObjects];
            
            [deselectOnMouseUp addObject:item];
          }
        } else {
          if (!(state & kCSIVItemSelectedMask)) {
            NSRect selectionRect = [self boundingRectOfSelectedItems];
            [self deselectAll];
            [self setNeedsDisplayInRect:selectionRect];
          } else if ([renderer isPoint:pos
                     inTextIfDrawnWithFrame:frame
                     textOnRight:([self labelPosition]
                                  == CSLabelPositionRight)]
                     && [[self window] isKeyWindow]
                     && [[self window] firstResponder] == self) {
            [editOnMouseUp release];
            editOnMouseUp = [item retain];
          }
          [self selectItem:item];
        }
      
        [self setNeedsDisplayInRect:frame];
      
        [dragStartEvent release];
        dragStartEvent = [event retain];
        dragStartPoint = pos;
        draggedFromIcon = YES;
        foundItem = YES;
      }
    }
  
    if (!foundItem) {
      if (!([event modifierFlags] 
            & (NSShiftKeyMask | NSCommandKeyMask | NSAlternateKeyMask))) {
        NSRect selectionRect = [self boundingRectOfSelectedItems];
        [self deselectAll];
        [self setNeedsDisplayInRect:selectionRect];
      }
    
      dragStartPoint = pos;
      draggedFromIcon = NO;
    }
    
    // Double clicks send a message to the target
    if (foundItem && action && [event clickCount] == 2) {
      [deselectOnMouseUp removeAllObjects];
      [NSApp sendAction:action to:target from:self];
    }
  }
}

- (void)updateSelectionForDragAt:(NSPoint)pos
{
  NSRect newRect, newSelRect;
  NSMutableSet *itemsInside;
  NSSet *itemsOnEdge;
  NSEnumerator *itemEnum;
  CSIconViewItem *item;
  
  if (pos.x < dragStartPoint.x) {
    newRect.origin.x = pos.x;
    newRect.size.width = dragStartPoint.x - pos.x;
  } else {
    newRect.origin.x = dragStartPoint.x;
    newRect.size.width = pos.x - dragStartPoint.x;
  }
  
  if (pos.y < dragStartPoint.y) {
    newRect.origin.y = pos.y;
    newRect.size.height = dragStartPoint.y - pos.y;
  } else {
    newRect.origin.y = dragStartPoint.y;
    newRect.size.height = pos.y - dragStartPoint.y;
  }
  
  newSelRect = newRect;
  itemsInside = [quadTree objectsInRect:newRect];
  NSSet *enumerableItemsInside = [[itemsInside copy] autorelease];
  itemsOnEdge = [quadTree objectsIntersectingRectBoundary:newRect];
  itemEnum = [itemsOnEdge objectEnumerator];
  
  [dragSelectedItems removeAllObjects];
  [enumerableItemsInside
   makeObjectsPerformSelector:@selector(removeFromCollectionIfDisabled:)
   withObject:itemsInside];
  [dragSelectedItems unionSet:itemsInside];
  
  while ((item = [itemEnum nextObject])) {
    NSPoint itemPos;
    NSRect frame;
    unsigned state = [item state];
    
    if (state & kCSIVItemDisabledMask)
      continue;
    
    itemPos = [item position];
    frame = NSMakeRect (itemPos.x, itemPos.y, gridSize.width, gridSize.height);
    
    if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask)) {
      [renderer setIconSize:[item customIconSize]];
      frame.size = [item customSize];
    } else {
      [renderer setIconSize:iconSize];
    }
    
    [renderer setIcon:[item icon]];
    [renderer setTitle:[item title]];
    
    if ([renderer intersectsWithRect:newRect
                    ifDrawnWithFrame:frame
                         highlighted:state & kCSIVItemSelectedMask
                         textOnRight:([self labelPosition]
                                      == CSLabelPositionRight)]) {  
      [dragSelectedItems addObject:item];
      newSelRect = NSUnionRect (newSelRect, frame);
    }
  }
  
  if (dragging)
    [self setNeedsDisplayInRect:selRect];
  dragRect = newRect;
  selRect = newSelRect;
  dragging = YES;
  [self setNeedsDisplayInRect:newSelRect];
}

- (void)autoscrollOnTimer:(NSTimer *)theTimer
{
  [self autoscroll:[theTimer userInfo]];
  
  if (dragging && !draggedFromIcon) {
    NSPoint pos = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream]
                            fromView:nil];
    
    [self updateSelectionForDragAt:pos];
  }
}

- (NSString *)iconViewUniqueID
{
  return [NSString stringWithFormat:@"%d-%p", getpid(), self];
}

- (BOOL)startEditingItem:(CSIconViewItem *)item
{
  NSWindow *myWindow = [self window];
  if (![myWindow makeFirstResponder:myWindow])
    return NO;
  
  NSPoint itemPos = [item position];
  NSSize itemSize = gridSize;
  
  isEditing = YES;
  
  if (allowsCustomSizes && ([item state]
                            & kCSIVItemCustomSizeMask)) {
    itemSize = [item customSize];
  }
  
  NSRect frame = NSMakeRect (itemPos.x, itemPos.y,
                             itemSize.width, itemSize.height);
  NSRect textRect = [renderer textRectIfDrawnWithFrame:frame
                                           textOnRight:([self labelPosition]
                                                        == CSLabelPositionRight)];
  NSTextView *fieldEditor = (NSTextView *)[myWindow fieldEditor:YES
                                                      forObject:self];
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] 
                                    autorelease];
  
  [style setAlignment:NSCenterTextAlignment];
  [fieldEditor setTypingAttributes:
   [NSDictionary dictionaryWithObjectsAndKeys:
    [self font], NSFontAttributeName,
    style, NSParagraphStyleAttributeName,
    nil]];
  [fieldEditor setHorizontallyResizable:YES];
  [fieldEditor setVerticallyResizable:YES];
  [fieldEditor setString:[item title]];
  [fieldEditor selectAll:self];
  [fieldEditor setDelegate:self];
  [fieldEditor setFrame:textRect];
  [fieldEditor setMaxSize:NSMakeSize (NSWidth (textRect), 1e6)];
  [fieldEditor sizeToFit];
  [self addSubview:fieldEditor];
  [myWindow makeFirstResponder:fieldEditor];
  
  NSRect fieldEditorFrame = [fieldEditor frame];
  [fieldEditor setFrame:NSMakeRect (NSMinX (textRect)
                                    + 0.5 * (NSWidth (textRect) 
                                             - NSWidth (fieldEditorFrame)),
                                    NSMinY (textRect),
                                    NSWidth (fieldEditorFrame),
                                    NSHeight (fieldEditorFrame))];
  
  fieldEditorFrame = [fieldEditor frame];
  
  keyboardFocusRect = fieldEditorFrame;
  [self setKeyboardFocusRingNeedsDisplayInRect:keyboardFocusRect];
  
  frameBeforeEditing = [self frame];
  [self setFrame:NSUnionRect(fieldEditorFrame, frameBeforeEditing)];
  
  editingItem = [item retain];
  didEdit = NO;

  return YES;
}

- (void)mouseDragged:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDragged 
      && (!draggedFromIcon || [selectedItems count])) {
    NSPoint pos = [self convertPoint:[event locationInWindow]
			    fromView:nil];
    NSRect visibleRect = [self visibleRect];
    
    if (!NSPointInRect (pos, visibleRect)) {
      [self autoscroll:event];
      
      [autoscrollTimer invalidate];
      autoscrollTimer
	  = [NSTimer scheduledTimerWithTimeInterval:0.05
					     target:self
					   selector:@selector(autoscrollOnTimer:)
					   userInfo:event
					    repeats:YES];
    } else {
      [autoscrollTimer invalidate];
      autoscrollTimer = nil;
    }
    
    if (draggedFromIcon) {
      NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
      NSImage *draggingImage
        = [self draggingImageForSelectedItemsAroundPoint:dragStartPoint
                                         representedRect:&draggedImageRect];
      NSMutableArray *types = [NSMutableArray arrayWithObjects:
                                CSIconViewInternalDragData,
                                nil];
      NSDictionary *iconViewItemInfo =
        [NSDictionary dictionaryWithObjectsAndKeys:
          [self iconViewUniqueID], kCSIconView,
          [self selectedItemIndices], kCSIconViewItems,
          nil];
      NSData *iconViewItemData = 
        [NSKeyedArchiver archivedDataWithRootObject:iconViewItemInfo];

      if ([dataSource respondsToSelector:
@selector(iconViewPasteboardTypesForDrag:)]) {
        [types addObjectsFromArray:[dataSource
                                     iconViewPasteboardTypesForDrag:self]];
      }
      [pboard declareTypes:types owner:self];
      [pboard setData:iconViewItemData
              forType:CSIconViewInternalDragData];
      
      [self dragImage:draggingImage
		   at:NSMakePoint (NSMinX (draggedImageRect),
				   NSMaxY (draggedImageRect))
	       offset:NSMakeSize (pos.x - dragStartPoint.x,
				  pos.y - dragStartPoint.y)
		event:dragStartEvent
	   pasteboard:pboard
	       source:self
	    slideBack:YES];
    } else {
      [self updateSelectionForDragAt:pos];
    }
  }
}

- (void)mouseUp:(NSEvent *)theEvent
{
  UNUSED (theEvent);
  
  if (dragging) {
    NSSet *intersect = [selectedItems setByIntersectingWithSet:dragSelectedItems];
    NSSet *newItems = [dragSelectedItems setBySubtractingSet:selectedItems];
    NSEnumerator *objEnum = [intersect objectEnumerator];
    CSIconViewItem *item;

    while ((item = [objEnum nextObject])) {
      unsigned ndx = [item index];
      if ([selectedItemIndices containsIndex:ndx])
        [selectedItemIndices removeIndex:ndx];
      else
        [selectedItemIndices addIndex:ndx];
    }
    
    objEnum = [newItems objectEnumerator];
    while ((item = [objEnum nextObject]))
      [selectedItemIndices addIndex:[item index]];
    
    [dragSelectedItems makeObjectsPerformSelector:@selector(toggle)];
    
    [selectedItems differenceSet:dragSelectedItems];
    [dragSelectedItems removeAllObjects];
    
    [self setNeedsDisplayInRect:dragRect];
    dragging = NO;
  } else if ([selectedItems count] == 1) {
    [self setFocusedItem:[[selectedItems objectEnumerator] nextObject]];
  }
  
  if (deselectOnMouseUp && [deselectOnMouseUp count]) {
    if (!dragging)
      [self deselectItems:deselectOnMouseUp];
    [deselectOnMouseUp removeAllObjects];
  }
  
  if (editOnMouseUp) {
    if (!dragging)
      [self startEditingItem:editOnMouseUp];
    [editOnMouseUp release];
    editOnMouseUp = nil;
  }
  
  if (autoscrollTimer) {
    [autoscrollTimer invalidate];
    autoscrollTimer = nil;
  }
  
  if (dragStartEvent) {
    [dragStartEvent release];
    dragStartEvent = nil;
  }
}

#pragma mark Field editor delegate methods

- (BOOL)textView:(NSTextView *)editor doCommandBySelector:(SEL)selector
{
  UNUSED (editor);
  
  // This will cause the field editor to lose the focus if we hit Escape
  if (selector == @selector(cancelOperation:)) {
    didEdit = NO;
    [[self window] makeFirstResponder:self];
    return YES;
  }
  
  return NO;
}

- (void)textDidChange:(NSNotification *)notification
{
  NSTextView *fieldEditor = (NSTextView *)[notification object];
  NSRect fieldEditorFrame;
  NSRect ourFrame = [self frame];
  NSSize itemSize = gridSize;

  if (allowsCustomSizes && ([editingItem state]
                            & kCSIVItemCustomSizeMask)) {
    itemSize = [editingItem customSize];
  }
  
  NSPoint itemPos = [editingItem position];
  NSRect frame = NSMakeRect (itemPos.x, itemPos.y,
                             itemSize.width, itemSize.height);
  NSRect textRect = [renderer textRectIfDrawnWithFrame:frame
                                           textOnRight:([self labelPosition]
                                                        == CSLabelPositionRight)];
  
  [self setKeyboardFocusRingNeedsDisplayInRect:keyboardFocusRect];

  [fieldEditor setFrame:textRect];
  [fieldEditor setMaxSize:NSMakeSize (NSWidth (textRect), 1e6)];
  [fieldEditor sizeToFit];
  fieldEditorFrame = [fieldEditor frame];
  [fieldEditor setFrame:NSMakeRect (NSMinX (textRect)
                                    + 0.5 * (NSWidth (textRect) 
                                             - NSWidth (fieldEditorFrame)),
                                    NSMinY (textRect),
                                    NSWidth (fieldEditorFrame),
                                    NSHeight (fieldEditorFrame))];
  
  fieldEditorFrame = [fieldEditor frame];
  
  ourFrame = NSUnionRect(fieldEditorFrame, ourFrame);
  [self setFrame:ourFrame];
  
  keyboardFocusRect = fieldEditorFrame;
  [self setKeyboardFocusRingNeedsDisplayInRect:keyboardFocusRect];
  
  // Notify others that our text has changed
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:CSIconViewTextDidChangeNotification
                  object:self
                userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                          fieldEditor, kCSIconViewFieldEditor,
                          editingItem, kCSIconViewItem,
                          nil]];
}

- (BOOL)textShouldBeginEditing:(NSText *)textObject
{
  UNUSED (textObject);
  
  if ([delegate respondsToSelector:@selector(iconView:shouldBeginEditingItem:)])
    return [delegate iconView:self shouldBeginEditingItem:editingItem];
  
  return YES;
}

- (void)textDidBeginEditing:(NSNotification *)notification
{
  NSTextView *fieldEditor = (NSTextView *)[notification object];

  didEdit = YES;
  
  // Notify others that we're beginning to edit
  [[NSNotificationCenter defaultCenter]
   postNotificationName:CSIconViewDidBeginEditingNotification
                 object:self
               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                         fieldEditor, kCSIconViewFieldEditor,
                         editingItem, kCSIconViewItem,
                         nil]];
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
  UNUSED (textObject);
  
  if ([delegate respondsToSelector:@selector(iconView:shouldEndEditingItem:)])
    return [delegate iconView:self shouldEndEditingItem:editingItem];
  
  return YES;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
  NSTextView *fieldEditor = (NSTextView *)[notification object];
  NSRect fieldEditorFrame = [fieldEditor frame];
  
  if (didEdit)
    [editingItem setTitle:[fieldEditor string]];
  
  // Notify others that we're done editing
  [[NSNotificationCenter defaultCenter]
   postNotificationName:CSIconViewDidEndEditingNotification
                 object:self
               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                         fieldEditor, kCSIconViewFieldEditor,
                         editingItem, kCSIconViewItem,
                         nil]];
  
  [editingItem release];
  editingItem = nil;
  
  isEditing = NO;
  [fieldEditor removeFromSuperview];  
  [self setKeyboardFocusRingNeedsDisplayInRect:fieldEditorFrame];
  [[self window] makeFirstResponder:self];
  [self setFrame:frameBeforeEditing];
}

#pragma mark Drag & Drop

- (void)setDraggingSourceOperationMask:(unsigned)mask forLocal:(BOOL)isLocal
{
  if (isLocal)
    localDraggingSourceMask = mask;
  else
    draggingSourceMask = mask;
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  if (isLocal)
    return localDraggingSourceMask;
  return draggingSourceMask;
}

- (CSIconViewItem *)firstEnabledItemAtPoint:(NSPoint)point
{
  NSSet *itemsAtPoint = [quadTree objectsAtPoint:point];
  NSEnumerator *itemEnum = [itemsAtPoint objectEnumerator];
  CSIconViewItem *item;

  while ((item = [itemEnum nextObject])) {
    unsigned state = [item state];
    NSPoint itemPos;
    NSRect frame;

    if (state & kCSIVItemDisabledMask)
      continue;

    itemPos = [item position];
    frame = NSMakeRect (itemPos.x, itemPos.y, gridSize.width, gridSize.height);
    
    if (allowsCustomSizes && (state & kCSIVItemCustomSizeMask)) {
      [renderer setIconSize:[item customIconSize]];
      frame.size = [item customSize];
    } else {
      [renderer setIconSize:iconSize];
    }
    
    [renderer setIcon:[item icon]];
    [renderer setTitle:[item title]];

    if ([renderer intersectsWithRect:NSMakeRect (point.x, point.y, 1, 1)
                    ifDrawnWithFrame:frame
                         highlighted:state & kCSIVItemSelectedMask
                         textOnRight:([self labelPosition]
                                      == CSLabelPositionRight)]) {
      break;
    }      
  }

  return item;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard;
  NSDragOperation sourceDragMask;
  NSDragOperation op = NSDragOperationNone;

  sourceDragMask = [sender draggingSourceOperationMask];
  pboard = [sender draggingPasteboard];

  if ([dataSource respondsToSelector:
                  @selector(iconView:validateDrop:onItemWithIndex:)]) {
    NSPoint location = [self convertPoint:[sender draggingLocation]
                                 fromView:nil];
    CSIconViewItem *item = [self firstEnabledItemAtPoint:location];
    unsigned ndx = [item index];

    if (!item)
      ndx = CSIconViewNoItem;

    op = [dataSource iconView:self validateDrop:sender onItemWithIndex:ndx];

    if (op != NSDragOperationNone)
      return op;
  }

  if (op == NSDragOperationNone
      && [[pboard types] containsObject:CSIconViewInternalDragData]) {
    NSData *data = [pboard dataForType:CSIconViewInternalDragData];
    NSDictionary *result = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    isDraggingBackToSelf = YES;

    if ([[result objectForKey:kCSIconView] isEqualTo:[self iconViewUniqueID]]) {
      if (sourceDragMask & NSDragOperationMove)
        return NSDragOperationMove;
    }
  }

  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;

  sourceDragMask = [sender draggingSourceOperationMask];

  if (isDraggingBackToSelf) {
    if (sourceDragMask & NSDragOperationMove)
      return NSDragOperationMove;
  }

  if ([dataSource respondsToSelector:
                  @selector(iconView:validateDrop:onItemWithIndex:)]) {
    NSPoint location = [self convertPoint:[sender draggingLocation]
                                 fromView:nil];
    CSIconViewItem *item = [self firstEnabledItemAtPoint:location];
    unsigned ndx = [item index];

    if (!item)
      ndx = CSIconViewNoItem;

    return [dataSource iconView:self validateDrop:sender onItemWithIndex:ndx];
  }

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  UNUSED (sender);
  
  if (isDraggingBackToSelf)
    isDraggingBackToSelf = NO;
}

- (BOOL)handleSimpleDrag:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSData *data = [pboard dataForType:CSIconViewInternalDragData];
  NSDictionary *result = [NSKeyedUnarchiver unarchiveObjectWithData:data];

  if (!data || autoArrangesItems || !(sourceDragMask & NSDragOperationMove))
    return NO;

  NSIndexSet *indices = [result objectForKey:kCSIconViewItems];
  NSRect selectedItemRect = [self boundingRectOfSelectedItems];
  NSPoint location = [self convertPoint:[sender draggedImageLocation]
                               fromView:nil];
  NSPoint origLocation = NSMakePoint (NSMinX (draggedImageRect),
                                      NSMaxY (draggedImageRect));
  NSPoint offset = NSMakePoint (location.x - origLocation.x,
                                location.y - origLocation.y);
  NSRect newSelectedItemRect = NSOffsetRect (selectedItemRect,
                                             offset.x, offset.y);
  NSUInteger ndx;
  NSPoint globalOffset = NSZeroPoint;
  
  for (ndx = [indices firstIndex]; ndx != NSNotFound;
       ndx = [indices indexGreaterThanIndex:ndx]) {
    CSIconViewItem *item = [items objectAtIndex:ndx];
    NSRect itemFrame;
        
    itemFrame.origin = [item position];
    
    if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
      itemFrame.size = [item customSize];
    else
      itemFrame.size = gridSize;

    [quadTree removeObject:item];

    itemFrame.origin.x += offset.x;
    itemFrame.origin.y += offset.y;
        
    if (snapsToGrid) {
      itemFrame.origin.x = (rint (itemFrame.origin.x / gridSize.width) 
                            * gridSize.width);
      itemFrame.origin.y = (rint (itemFrame.origin.y / gridSize.height)
                            * gridSize.height);

      newSelectedItemRect = NSUnionRect (itemFrame, newSelectedItemRect);
    }

    if (itemFrame.origin.x < -globalOffset.x)
      globalOffset.x = -itemFrame.origin.x;
    if (itemFrame.origin.y < -globalOffset.y)
      globalOffset.y = -itemFrame.origin.y;
    
    [item setPosition:itemFrame.origin];
    [quadTree addObject:item withBounds:itemFrame];
  }

  /* If we tried to move items off the top or left of the view, offset all
     the other items instead */
  if (globalOffset.x != 0.0 || globalOffset.y != 0.0) {
    NSEnumerator *itemEnum = [items objectEnumerator];
    CSIconViewItem  *item;
    
    [quadTree removeAllObjects];
    
    while ((item = [itemEnum nextObject])) {
      NSRect itemFrame;
      itemFrame.origin = [item position];
      if (allowsCustomSizes && ([item state] & kCSIVItemCustomSizeMask))
        itemFrame.size = [item customSize];
      else
        itemFrame.size = gridSize;
      
      itemFrame.origin.x += globalOffset.x;
      itemFrame.origin.y += globalOffset.y;
      
      [item setPosition:itemFrame.origin];
      [quadTree addObject:item withBounds:itemFrame];
    }
    
    newSelectedItemRect = [self boundingRectOfSelectedItems];
    
    [self setNeedsDisplay:YES];
  }
  
  NSRect bounds = [quadTree objectBounds];
  NSSize newSize = NSMakeSize (NSMaxX (bounds), NSMaxY (bounds));
  NSScrollView *scrollView = [self enclosingScrollView];
      
  if (scrollView) {
    NSSize contentSize = [scrollView contentSize];

    if (newSize.width < contentSize.width)
      newSize.width = contentSize.width;
    if (newSize.height < contentSize.height)
      newSize.height = contentSize.height;
  }

  [self setFrameSize:newSize];

  [self setNeedsDisplayInRect:selectedItemRect];
  [self setNeedsDisplayInRect:newSelectedItemRect];

  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard;
  NSDragOperation sourceDragMask;

  sourceDragMask = [sender draggingSourceOperationMask];
  pboard = [sender draggingPasteboard];

  if (isDraggingBackToSelf) {
    isDraggingBackToSelf = NO;

    return [self handleSimpleDrag:sender];
  }

  if ([dataSource respondsToSelector:
                  @selector(iconView:acceptDrop:onItemWithIndex:)]) {
    NSPoint location = [self convertPoint:[sender draggingLocation]
                                 fromView:nil];
    CSIconViewItem *item = [self firstEnabledItemAtPoint:location];
    unsigned ndx = [item index];

    if (!item)
      ndx = CSIconViewNoItem;

    return [dataSource iconView:self acceptDrop:sender onItemWithIndex:ndx];
  }

  return NO;
}

- (NSRect)boundingRectOfItem:(CSIconViewItem *)item
{
  unsigned state = [item state];
  NSPoint pos = [item position];
  NSSize size;
  
  if (allowsCustomSizes && (state & kCSIVItemCustomSizeMask))
    size = [item customSize];
  else
    size = gridSize;
  
  return NSMakeRect (pos.x, pos.y, size.width, size.height);
}

- (NSRect)boundingRectOfItems:(id)collection
{
  NSRect itemRect = NSZeroRect;
  
  if ([collection respondsToSelector:@selector(objectEnumerator)]) {
    NSEnumerator *itemEnum = [collection objectEnumerator];
    CSIconViewItem *item;
    
    /* Compute a rectangle that surrounds all of the selected items
       in this view. */
    while ((item = [itemEnum nextObject])) {
      unsigned state = [item state];
      NSPoint pos = [item position];
      NSSize size;
      
      if (allowsCustomSizes && (state & kCSIVItemCustomSizeMask))
        size = [item customSize];
      else
        size = gridSize;
      
      itemRect = NSUnionRect (itemRect,
                                   NSMakeRect (pos.x, pos.y,
                                               size.width, size.height));
    }
  } else if ([collection isKindOfClass:[NSIndexSet class]]) {
    NSUInteger ndx;
    
    for (ndx = [collection firstIndex]; ndx != NSNotFound;
         ndx = [collection indexGreaterThanIndex:ndx]) {
      CSIconViewItem *item = [items objectAtIndex:ndx];
      
      unsigned state = [item state];
      NSPoint pos = [item position];
      NSSize size;
      
      if (allowsCustomSizes && (state & kCSIVItemCustomSizeMask))
        size = [item customSize];
      else
        size = gridSize;
      
      itemRect = NSUnionRect (itemRect,
                              NSMakeRect (pos.x, pos.y,
                                          size.width, size.height));
    }
  } else {
    [NSException raise:@"CSBadArgumentException"
                format:@"Object passed into -boundingRectOfItems: must be a collection."];
  }
  
  return itemRect;
}

- (NSRect)boundingRectOfSelectedItems
{
  return [self boundingRectOfItems:selectedItems];
}

- (NSImage *)imageOfSelectedItems
{
  return [self imageOfSelectedItemsInRect:[self boundingRectOfSelectedItems]];
}

- (NSImage *)imageOfSelectedItemsInRect:(NSRect)selectionRect
{
  NSImage *image;
  NSAffineTransform *transform;
  NSColor *realBackground = [self backgroundColor];
  
  transform = [NSAffineTransform transform];
  [transform translateXBy:-selectionRect.origin.x yBy:-selectionRect.origin.y];
  
  image = [[[NSImage alloc] initWithSize:selectionRect.size] autorelease];
  
  [image setFlipped:YES];
  [image lockFocus];
  
  backgroundColor = [NSColor clearColor];
  drawOnlySelected = YES;
  [transform concat];
  [self drawRect:selectionRect];
  
  [image unlockFocus];
  [image setFlipped:NO];

  backgroundColor = realBackground;
  drawOnlySelected = NO;
  
  return image;
}

/* Constructs an image with a transparency gradient in it; we use this to
   do the nice transparent edges on drag selections */
- (NSImage *)dragImageFadeImage
{
  if (dragImageFadeImage)
    return dragImageFadeImage;
  
  static uint32_t transparency[FADE_DISTANCE];
  static unsigned char *planes[] = { (unsigned char *)transparency };
  unsigned n;
    
  for (n = 0; n < FADE_DISTANCE; ++n) {
    uint8_t alpha = 0xff - ((0xff * n) / FADE_DISTANCE);
    transparency[n] = alpha << 24 | alpha << 16 | alpha << 8 | alpha;
  }
  
  NSBitmapImageRep *imageRep = [[[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:planes
                                  pixelsWide:FADE_DISTANCE
                                  pixelsHigh:1
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSDeviceRGBColorSpace
                                  bitmapFormat:0
                                  bytesPerRow:FADE_DISTANCE*4
                                  bitsPerPixel:32] autorelease];
  
  dragImageFadeImage = [[NSImage alloc] initWithSize:NSMakeSize(FADE_DISTANCE, 
                                                                1)];
  [dragImageFadeImage addRepresentation:imageRep];
  
  return dragImageFadeImage;
}

/* Constructs an image of the selected items for dragging */
- (NSImage *)draggingImageForSelectedItemsAroundPoint:(NSPoint)point
                                      representedRect:(NSRect *)repRect;
{
  NSRect selectedItemRect = [self boundingRectOfSelectedItems];
  bool fadeLeft = false, fadeRight = false, fadeTop = false, fadeBottom = false;
  
  if (selectedItemRect.size.width > maxDragImageSize.width) {
    float halfWidth = 0.5 * maxDragImageSize.width;
    if (point.x - NSMinX (selectedItemRect) > halfWidth) {
      fadeLeft = true;
      
      float newX = point.x - halfWidth;
      selectedItemRect.size.width -= newX - NSMinX (selectedItemRect);
      selectedItemRect.origin.x = newX;
    }
    
    if (NSMaxX (selectedItemRect) - point.x > halfWidth)
      fadeRight = true;
    else {
      selectedItemRect.origin.x = NSMaxX (selectedItemRect)
        - maxDragImageSize.width;
    }
    
    selectedItemRect.size.width = maxDragImageSize.width;
  }
  if (selectedItemRect.size.height > maxDragImageSize.height) {
    float halfHeight = 0.5 * maxDragImageSize.height;
    if (point.y - NSMinY (selectedItemRect) > halfHeight) {
      fadeTop = true;
      
      float newY = point.y - halfHeight;
      selectedItemRect.size.height -= newY - NSMinY (selectedItemRect);
      selectedItemRect.origin.y = newY;
    }
    
    if (NSMaxY (selectedItemRect) - point.y > halfHeight)
      fadeBottom = true;
    else {
      selectedItemRect.origin.y = NSMaxY (selectedItemRect)
        - maxDragImageSize.height;
    }
    
    selectedItemRect.size.height = maxDragImageSize.height;
  }
  
  NSImage *image = [self imageOfSelectedItemsInRect:selectedItemRect];
  NSSize imageSize = [image size];
  NSImage *fadeImage = [self dragImageFadeImage];
  NSImage *alphaImage = [[[NSImage alloc] initWithSize:imageSize]
                         autorelease];
  
  [alphaImage lockFocus];
  
  // First draw the icons with alpha 0.75
  [image dissolveToPoint:NSZeroPoint fraction:0.75];
  
  // Now fade the edges as necessary
  if (fadeRight) {
    // This is the easiest as our fade image is opaque on the left
    [fadeImage drawInRect:NSMakeRect (imageSize.width - FADE_DISTANCE,
                                      0.0,
                                      FADE_DISTANCE,
                                      imageSize.height)
                 fromRect:NSMakeRect (0.0, 0.0, FADE_DISTANCE, 1.0)
                operation:NSCompositeDestinationIn
                 fraction:1.0];
  }
  
  if (fadeLeft) {
    // To fade the left, we need to flip our co-ordinate system
    NSAffineTransform *flipTransform = [NSAffineTransform transform];
    NSAffineTransformStruct flipMatrix = {
      -1.0, 0.0,
       0.0, 1.0,
      imageSize.width, 0.0
    };
    [flipTransform setTransformStruct:flipMatrix];
    
    [NSGraphicsContext saveGraphicsState];
    [flipTransform concat];
    [fadeImage drawInRect:NSMakeRect (imageSize.width - FADE_DISTANCE,
                                      0.0,
                                      FADE_DISTANCE,
                                      imageSize.height)
                 fromRect:NSMakeRect (0.0, 0.0, FADE_DISTANCE, 1.0)
                operation:NSCompositeDestinationIn
                 fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
  }
  
  if (fadeTop) {
    // To fade the top, we need to rotate
    NSAffineTransform *rotateTransform = [NSAffineTransform transform];
    NSAffineTransformStruct rotateMatrix = {
      0.0, 1.0,
      1.0, 0.0,
      0.0, 0.0
    };
    [rotateTransform setTransformStruct:rotateMatrix];

    [NSGraphicsContext saveGraphicsState];
    [rotateTransform concat];
    [fadeImage drawInRect:NSMakeRect (imageSize.height - FADE_DISTANCE,
                                      0.0,
                                      FADE_DISTANCE,
                                      imageSize.width)
                 fromRect:NSMakeRect (0.0, 0.0, FADE_DISTANCE, 1.0)
                operation:NSCompositeDestinationIn
                 fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
  }
  
  if (fadeBottom) {
    // To fade the bottom, we also need to rotate
    NSAffineTransform *rotateTransform = [NSAffineTransform transform];
    NSAffineTransformStruct rotateMatrix = {
      0.0, -1.0,
      1.0, 0.0,
      0.0, imageSize.height
    };
    [rotateTransform setTransformStruct:rotateMatrix];
    
    [NSGraphicsContext saveGraphicsState];
    [rotateTransform concat];
    [fadeImage drawInRect:NSMakeRect (imageSize.height - FADE_DISTANCE,
                                      0.0,
                                      FADE_DISTANCE,
                                      imageSize.width)
                 fromRect:NSMakeRect (0.0, 0.0, FADE_DISTANCE, 1.0)
                operation:NSCompositeDestinationIn
                 fraction:1.0];
    [[NSColor redColor] set];
    [NSGraphicsContext restoreGraphicsState];    
  }
  
  [alphaImage unlockFocus];
  
  *repRect = selectedItemRect;
  
  return alphaImage;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self setDrawsFocusRing:NO];
  [self setNeedsDisplay:YES];
  return YES;
}

#pragma mark Keyboard handling

- (BOOL)canBecomeKeyView
{
  return YES;
}

- (void)resetKeyboardMovement
{
  keyboardMovementDirection = CSNoKeyboardMovement;
}

- (BOOL)performKeyEquivalent:(NSEvent *)evt
{
  NSString *chars = [evt charactersIgnoringModifiers];
  
  if ([evt type] == NSKeyDown && [chars length] >= 1) {
    unichar ch = [chars characterAtIndex:0];
    
    if (ch == NSHomeFunctionKey) {
      [self scrollToTop:self];
      return YES;
    } else if (ch == NSEndFunctionKey) {
      [self scrollToBottom:self];
      return YES;
    } else if (ch == '\r' || ch == '\n') {
      [self editFocusedItem:self];
      return YES;
    } else if (ch == ' ') {
      [self openFocusedItem:self];
      return YES;
    }
  }
  
  return [super performKeyEquivalent:evt];
}

- (IBAction)editFocusedItem:(id)sender
{
  UNUSED (sender);
  
  if (focusedItem) {
    [self startEditingItem:focusedItem];
  } else {
    NSBeep ();
  }
}

- (IBAction)openFocusedItem:(id)sender
{
  UNUSED (sender);
  
  if (focusedItem && action) {
    [NSApp sendAction:action to:target from:self];
  } else {
    NSBeep ();
  }
}

/* Given a collection and an edge, find the item we should select.
 
   Note that topmost is really "leftmost topmost", leftmost is really
   "topmost leftmost", rightmost is really "bottommost rightmost" and
   bottommost is really "rightmost bottommost".  To clarify:
 
                (1) *  *  *  *       1 - topmost
             (2) *  *  *  *  *       2 - leftmost
              *  *  *  *  *  *       3 - rightmost
              *  *  *  *  * (3)      4 - bottommost
              *  * (4)

   This is the kind of behaviour that users usually expect, even if they
   don't realise it. */
typedef enum {
  kTopmost, kLeftmost, kBottommost, kRightmost
} RelativePosition;

static CSIconViewItem *
findItemAtEdge (id collection, RelativePosition pos)
{
  NSPoint bestPos = NSZeroPoint;
  CSIconViewItem *bestItem = nil;
  NSEnumerator *itemEnum = [collection objectEnumerator];
  CSIconViewItem *item;
  
  while ((item = [itemEnum nextObject])) {
    if (!bestItem) {
      bestItem = item;
      bestPos = [item position];
    } else {
      NSPoint itemPos = [item position];
      BOOL isBest = NO;
      
      switch (pos) {
      case kTopmost:
        isBest = (itemPos.y < bestPos.y 
                  || (itemPos.y == bestPos.y && itemPos.x < bestPos.x));
        break;
      case kBottommost:
        isBest = (itemPos.y > bestPos.y
                  || (itemPos.y == bestPos.y && itemPos.x > bestPos.x));
        break;
      case kLeftmost:
        isBest = (itemPos.x < bestPos.x
                  || (itemPos.x == bestPos.x && itemPos.y < bestPos.y));
        break;
      case kRightmost:
        isBest = (itemPos.x > bestPos.x
                  || (itemPos.x == bestPos.x && itemPos.y > bestPos.y));
        break;
      }
      
      if (isBest) {
        bestItem = item;
        bestPos = itemPos;
      }
    }
  }
  
  return bestItem;
}

/* Given a rectangle and a direction, find the next item in that direction */
typedef enum {
  kLeft, kRight, kUp, kDown
} Direction;

static CSIconViewItem *
findItemInDirectionFromRect (CSRectQuadTree *quadTree,
                             NSRect rect,
                             Direction direction)
{
  NSRect bounds = [quadTree bounds];
  NSPoint origPos = rect.origin;
  
  switch (direction) {
  case kUp:
    rect.size.height = NSMinY (rect) - NSMinY (bounds);
    rect.origin.y = NSMinY (bounds);
    break;
  case kDown:
    rect.size.height = NSMaxY (bounds) - rect.origin.y;
    break;
  case kLeft:
    rect.size.width = NSMinX (rect) - NSMinX (bounds);
    rect.origin.x = NSMinX (bounds);
    break;
  case kRight:
    rect.size.width = NSMaxY (bounds) - rect.origin.x;
    break; 
  }
  
  NSSet *possibleItems = [quadTree objectsIntersectingRect:rect];
  NSEnumerator *itemEnum = [possibleItems objectEnumerator];
  CSIconViewItem *bestItem = nil, *item;
  NSPoint bestPos = NSZeroPoint;
  
  /* Find the item closest to being next to the selected item.  We break
     ties in the upward/leftward direction. */
  while ((item = [itemEnum nextObject])) {
    NSPoint itemPos = [item position];
    
    // Ignore disabled items
    if ([item state] & kCSIVItemDisabledMask)
      continue;
    
    // Make sure we actually move
    switch (direction) {
    case kUp:
      if (itemPos.y >= origPos.y)
        continue;
      break;
    case kDown:
      if (itemPos.y <= origPos.y)
        continue;
      break;
    case kLeft:
      if (itemPos.x >= origPos.x)
        continue;
      break;
    case kRight:
      if (itemPos.x <= origPos.x)
        continue;
      break;
    }
    
    if (!bestItem) {
      bestPos = itemPos;
      bestItem = item;
    } else {
      BOOL isBest = NO;
      
      switch (direction) {
      case kUp:
        isBest = itemPos.y > bestPos.y || (itemPos.y == bestPos.y
                                           && itemPos.x < bestPos.x);
        break;
      case kDown:
        isBest = itemPos.y < bestPos.y || (itemPos.y == bestPos.y
                                           && itemPos.x < bestPos.x);
        break;
      case kLeft:
        isBest = itemPos.x > bestPos.x || (itemPos.x == bestPos.x
                                           && itemPos.y < bestPos.y);
        break;
      case kRight:
        isBest = itemPos.x < bestPos.x || (itemPos.x == bestPos.x
                                           && itemPos.y < bestPos.y);
        break;
      }
      
      if (isBest) {
        bestPos = itemPos;
        bestItem = item;
      }
    }
  }
  
  return bestItem;
}

- (void)moveDown:(id)sender
{
  if ([[NSApp currentEvent] modifierFlags] 
      & (NSShiftKeyMask | NSCommandKeyMask)) {
    [self moveDownAndModifySelection:sender];
    return;
  }
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    if (count > 1) {
      nextItem = findItemAtEdge (selected, kBottommost);
      [self resetKeyboardMovement];
    } else {
      NSRect rect = [self boundingRectOfItems:selected];

      if (keyboardMovementDirection == CSVerticalKeyboardMovement) {
        rect.origin.x = keyboardMovementRect.origin.x;
        rect.size.width = keyboardMovementRect.size.width;
      } else {
        keyboardMovementRect = rect;
        keyboardMovementDirection = CSVerticalKeyboardMovement;
      }
      
      nextItem = findItemInDirectionFromRect (quadTree, rect, kDown);
    }
  } else {
    nextItem = findItemAtEdge (items, kTopmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSVerticalKeyboardMovement)
      keyboardMovementRect = itemRect;

    // These will reset the keyboard movement direction...
    [self deselectAll];
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];

    // ...so set it again
    keyboardMovementDirection = CSVerticalKeyboardMovement;
  }
}

- (void)moveDownAndModifySelection:(id)sender
{
  UNUSED (sender);
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    NSRect rect;
    
    if (!focusedItem) {
      // If we have no focused item, focus one first
      nextItem = findItemAtEdge (selected, kBottommost);
      [self setFocusedItem:nextItem];
      [self resetKeyboardMovement];
      return;
    }
    
    if (keyboardMovementDirection == CSVerticalKeyboardMovement) {
      rect = [self boundingRectOfItem:focusedItem];
      
      rect.origin.x = keyboardMovementRect.origin.x;
      rect.size.width = keyboardMovementRect.size.width;
    } else {
      rect = keyboardMovementRect = [self boundingRectOfItem:focusedItem];
      keyboardMovementDirection = CSVerticalKeyboardMovement;
    }
    
    nextItem = findItemInDirectionFromRect (quadTree, rect, kDown);
  } else {
    nextItem = findItemAtEdge (items, kTopmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSVerticalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSVerticalKeyboardMovement;
  }
}

- (void)moveUp:(id)sender
{
  if ([[NSApp currentEvent] modifierFlags] 
      & (NSShiftKeyMask | NSCommandKeyMask)) {
    [self moveUpAndModifySelection:sender];
    return;
  }
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    if (count > 1) {
      nextItem = findItemAtEdge (selected, kTopmost);
      [self resetKeyboardMovement];
    } else {
      NSRect rect = [self boundingRectOfItems:selected];

      if (keyboardMovementDirection == CSVerticalKeyboardMovement) {
        rect.origin.x = keyboardMovementRect.origin.x;
        rect.size.width = keyboardMovementRect.size.width;
      } else {
        keyboardMovementRect = rect;
        keyboardMovementDirection = CSVerticalKeyboardMovement;
      }
      
      nextItem = findItemInDirectionFromRect (quadTree, rect, kUp);     
    }
  } else {
    nextItem = findItemAtEdge (items, kBottommost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSVerticalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self deselectAll];
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSVerticalKeyboardMovement;
  }
}

- (void)moveUpAndModifySelection:(id)sender
{
  UNUSED (sender);
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;

  if (count) {
    NSRect rect;
    
    if (!focusedItem) {
      // If we have no focused item, focus one first
      nextItem = findItemAtEdge (selected, kTopmost);
      [self setFocusedItem:nextItem];
      [self resetKeyboardMovement];
      return;
    }
    
    if (keyboardMovementDirection == CSVerticalKeyboardMovement) {
      rect = [self boundingRectOfItem:focusedItem];
      
      rect.origin.x = keyboardMovementRect.origin.x;
      rect.size.width = keyboardMovementRect.size.width;
    } else {
      rect = keyboardMovementRect = [self boundingRectOfItem:focusedItem];
      keyboardMovementDirection = CSVerticalKeyboardMovement;
    }
    
    nextItem = findItemInDirectionFromRect (quadTree, rect, kUp);
  } else {
    nextItem = findItemAtEdge (items, kBottommost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSVerticalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSVerticalKeyboardMovement;
  }
}

- (void)moveLeft:(id)sender
{
  if ([[NSApp currentEvent] modifierFlags] 
      & (NSShiftKeyMask | NSCommandKeyMask)) {
    [self moveLeftAndModifySelection:sender];
    return;
  }
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    if (count > 1) {
      nextItem = findItemAtEdge (selected, kLeftmost);
      [self resetKeyboardMovement];
    } else {
      NSRect rect = [self boundingRectOfItems:selected];

      if (keyboardMovementDirection == CSHorizontalKeyboardMovement) {
        rect.origin.y = keyboardMovementRect.origin.y;
        rect.size.height = keyboardMovementRect.size.height;
      } else {
        keyboardMovementRect = rect;
        keyboardMovementDirection = CSHorizontalKeyboardMovement;
      }
      
      nextItem = findItemInDirectionFromRect (quadTree, rect, kLeft);      
    }
  } else {
    nextItem = findItemAtEdge (items, kRightmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSHorizontalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self deselectAll];
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSHorizontalKeyboardMovement;
  }
}

- (void)moveLeftAndModifySelection:(id)sender
{
  UNUSED (sender);
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    NSRect rect;
    
    if (!focusedItem) {
      // If we have no focused item, focus one first
      nextItem = findItemAtEdge (selected, kLeftmost);
      [self setFocusedItem:nextItem];
      [self resetKeyboardMovement];
      return;
    }
    
    if (keyboardMovementDirection == CSHorizontalKeyboardMovement) {
      rect = [self boundingRectOfItem:focusedItem];
      
      rect.origin.y = keyboardMovementRect.origin.y;
      rect.size.height = keyboardMovementRect.size.height;
    } else {
      rect = keyboardMovementRect = [self boundingRectOfItem:focusedItem];
      keyboardMovementDirection = CSHorizontalKeyboardMovement;
    }
    
    nextItem = findItemInDirectionFromRect (quadTree, rect, kLeft);
  } else {
    nextItem = findItemAtEdge (items, kRightmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSHorizontalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSHorizontalKeyboardMovement;
  }
}

- (void)moveRight:(id)sender
{
  if ([[NSApp currentEvent] modifierFlags] 
      & (NSShiftKeyMask | NSCommandKeyMask)) {
    [self moveRightAndModifySelection:sender];
    return;
  }

  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    if (count > 1) {
      nextItem = findItemAtEdge (selected, kRightmost);
      [self resetKeyboardMovement];
    } else {
      NSRect rect = [self boundingRectOfItems:selected];

      if (keyboardMovementDirection == CSHorizontalKeyboardMovement) {
        rect.origin.y = keyboardMovementRect.origin.y;
        rect.size.height = keyboardMovementRect.size.height;
      } else {
        keyboardMovementRect = rect;
        keyboardMovementDirection = CSHorizontalKeyboardMovement;
      }
      
      nextItem = findItemInDirectionFromRect (quadTree, rect, kRight);      
    }
  } else {
    nextItem = findItemAtEdge (items, kLeftmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSHorizontalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self deselectAll];
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSHorizontalKeyboardMovement;
  }
}

- (void)moveRightAndModifySelection:(id)sender
{
  UNUSED (sender);
  
  NSSet *selected = [self selectedItems];
  unsigned count = [selected count];
  CSIconViewItem *nextItem;
  
  if (count) {
    NSRect rect;
    
    if (!focusedItem) {
      // If we have no focused item, focus one first
      nextItem = findItemAtEdge (selected, kRightmost);
      [self setFocusedItem:nextItem];
      [self resetKeyboardMovement];
      return;
    }
    
    if (keyboardMovementDirection == CSHorizontalKeyboardMovement) {
      rect = [self boundingRectOfItem:focusedItem];
      
      rect.origin.y = keyboardMovementRect.origin.y;
      rect.size.height = keyboardMovementRect.size.height;
    } else {
      rect = keyboardMovementRect = [self boundingRectOfItem:focusedItem];
      keyboardMovementDirection = CSHorizontalKeyboardMovement;
    }
    
    nextItem = findItemInDirectionFromRect (quadTree, rect, kRight);
  } else {
    nextItem = findItemAtEdge (items, kLeftmost);
  }
  
  if (!nextItem) {
    NSBeep ();
    [self resetKeyboardMovement];
  } else {
    NSRect itemRect = [self boundingRectOfItem:nextItem];
    
    if (keyboardMovementDirection != CSHorizontalKeyboardMovement)
      keyboardMovementRect = itemRect;
    
    // These will reset the keyboard movement direction...
    [self selectItem:nextItem];
    [self setFocusedItem:nextItem];
    [self scrollRectToVisible:itemRect];
    
    // ...so set it again
    keyboardMovementDirection = CSHorizontalKeyboardMovement;
  }
}

- (void)scrollToTop:(id)sender
{
  UNUSED (sender);
  
  [self scrollPoint:NSZeroPoint];
}

- (void)scrollToBottom:(id)sender
{
  UNUSED (sender);
  
  NSRect bounds = [self bounds];
  [self scrollRectToVisible:NSMakeRect (NSMaxX (bounds) - 1,
                                        NSMaxY (bounds) - 1,
                                        1, 1)];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
  if ([theEvent modifierFlags] & NSShiftKeyMask) {
    [self setDrawsFocusRing:YES];
  } else {
    [self setDrawsFocusRing:NO];
  }
}

@end
