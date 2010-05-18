//
//  CSIconView.h
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

#import <Cocoa/Cocoa.h>
#import "CSIconViewItem.h"
#import "CSIconRenderer.h"
#import "CSRectQuadTree.h"

@class CSIconView;

#define CSIconViewNoItem (~0u)

/* CSIconViewInternalDragData is an NSKeyedArchiver encoded NSDictionary
   with two keys:

     kCSIconView  (= [iconView iconViewUniqueID])
        Specifies the icon view that initiated this drag operation.
     kCSIconViewItems  (= [iconView selectedItemIndices])
        Specifies the indices of the icons being dragged.

   The default handling will automatically deal with internal drag-drops.
   If you implement -iconView:validateDrop:onItemWithIndex:, you should return
   NSDragOperationNone to indicate that you want the default handling.  If
   you return any other drag operation, you will be responsible for handling
   that operation in its entirety.  In such cases, if you determine that you
   simply wish to move the items in the view, you can call -handleSimpleDrag:
   to do so. */
extern NSString * const CSIconViewInternalDragData;
extern NSString * const kCSIconView;
extern NSString * const kCSIconViewItems;

@interface NSObject (CSIconViewDataSource)

- (unsigned)numberOfItemsInIconView:(CSIconView *)view;
- (CSIconViewItem *)iconView:(CSIconView *)view itemAtIndex:(unsigned)index;

- (void)iconView:(CSIconView *)view
    setItemTitle:(NSString *)title
	 atIndex:(unsigned)index;

- (BOOL)iconView:(CSIconView *)view
      acceptDrop:(id <NSDraggingInfo>)info
 onItemWithIndex:(unsigned)index;

- (NSDragOperation)iconView:(CSIconView *)view
	       validateDrop:(id <NSDraggingInfo>)info
            onItemWithIndex:(unsigned)index;

- (NSArray *)iconViewPasteboardTypesForDrag:(CSIconView *)view;
- (NSArray *)iconViewAcceptedPasteboardTypesForDrop:(CSIconView *)view;

- (BOOL)iconView:(CSIconView *)view
   writeItemData:(NSIndexSet *)itemIndices
    toPasteboard:(NSPasteboard *)pboard;

@end

extern NSString * const CSIconViewDidBeginEditingNotification;
extern NSString * const CSIconViewTextDidChangeNotification;
extern NSString * const CSIconViewDidEndEditingNotification;
extern NSString * const kCSIconViewFieldEditor;
extern NSString * const kCSIconViewItem;

@interface NSObject (CSIconViewDelegate)

- (BOOL)iconView:(CSIconView *)view shouldBeginEditingItem:(CSIconViewItem *)item;
- (BOOL)iconView:(CSIconView *)view shouldEndEditingItem:(CSIconViewItem *)item;

- (void)iconViewDidBeginEditing:(NSNotification *)aNotification;
- (void)iconViewTextDidChange:(NSNotification *)aNotification;
- (void)iconViewDidEndEditing:(NSNotification *)aNotification;

@end

typedef enum
{
  CSLabelPositionRight,
  CSLabelPositionBottom
} CSIconViewLabelPosition;

typedef enum {
  CSNoKeyboardMovement,
  CSHorizontalKeyboardMovement,
  CSVerticalKeyboardMovement
} CSKeyboardMovementDirection;

@interface CSIconView : NSControl <NSTextViewDelegate>
{
  NSSize                    maxDragImageSize;
  NSImage                   *dragImageFadeImage;
  
  NSSize		    gridSize;
  NSSize		    iconSize;
  CSIconViewLabelPosition   labelPosition;
  NSColor		    *backgroundColor;
  
  BOOL			    snapsToGrid;
  BOOL			    autoArrangesItems;
  BOOL			    allowsCustomSizes;
  BOOL                      allowsDragAndDrop;
  BOOL                      isDraggingBackToSelf;
  
  BOOL                      isEditing;
  BOOL                      didEdit;
  NSRect                    frameBeforeEditing;
  CSIconViewItem            *editingItem;
  NSRect                    keyboardFocusRect;
  
  NSUInteger                localDraggingSourceMask;
  NSUInteger                draggingSourceMask;

  NSMutableArray	    *items;
  CSRectQuadTree	    *quadTree;
  NSMutableSet		    *selectedItems;
  NSMutableIndexSet         *selectedItemIndices;

  CSIconRenderer	    *renderer;
  
  NSFont		    *font;
  
  NSMutableDictionary	    *darkTextAttributes;
  NSMutableDictionary	    *mediumTextAttributes;
  NSMutableDictionary	    *lightTextAttributes;
  
  NSPoint		    dragStartPoint;
  BOOL			    draggedFromIcon;
  BOOL			    dragging;
  NSEvent		    *dragStartEvent;
  NSRect		    dragRect;
  NSRect		    selRect;
  NSRect                    draggedImageRect;
  NSMutableSet		    *dragSelectedItems;
  NSMutableSet              *deselectOnMouseUp;
  CSIconViewItem            *editOnMouseUp;
  
  BOOL			    knowsSelectionBoundingRect;
  NSRect		    selectionBoundingRect;
  
  BOOL			    isOpaque;
  BOOL			    needsArrange;
  BOOL			    needsReload;
  BOOL			    doingArrange;
  BOOL			    drawOnlySelected;
  
  BOOL                      drawsFocusRing;
  CSIconViewItem            *focusedItem;
  
  CSKeyboardMovementDirection keyboardMovementDirection;
  NSRect                      keyboardMovementRect;
  
  unsigned		    gridWidth;
  
  IBOutlet id		    dataSource;
  IBOutlet id               delegate;
  
  IBOutlet id               target;
  SEL                       action;
  
  BOOL                      delegateSupportsDidBeginEditing;
  BOOL                      delegateSupportsTextDidChange;
  BOOL                      delegateSupportsDidEndEditing;
  
  NSTimer		    *autoscrollTimer;
}

- (NSSize)maxDragImageSize;
- (void)setMaxDragImageSize:(NSSize)newMaxDragImageSize;

- (NSSize)gridSize;
- (void)setGridSize:(NSSize)newSize;

- (NSSize)iconSize;
- (void)setIconSize:(NSSize)newSize;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

- (CSIconViewLabelPosition)labelPosition;
- (void)setLabelPosition:(CSIconViewLabelPosition)labelPosition;

- (BOOL)snapsToGrid;
- (void)setSnapsToGrid:(BOOL)shouldSnap;

- (BOOL)autoArrangesItems;
- (void)setAutoArrangesItems:(BOOL)shouldArrange;

- (BOOL)allowsCustomSizes;
- (void)setAllowsCustomSizes:(BOOL)allows;

- (BOOL)allowsDragAndDrop;
- (void)setAllowsDragAndDrop:(BOOL)allows;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)newColor;

- (BOOL)isOpaque;
- (void)setIsOpaque:(BOOL)isOpaque;

- (id)dataSource;
- (void)setDataSource:(id)newSource;

- (BOOL)needsArrange;
- (void)setNeedsArrange:(BOOL)needsArrange;

- (NSSet *)itemsInRect:(NSRect)rect;

- (void)reloadItemAtIndex:(unsigned)ndx;
- (void)reloadItems;
- (void)arrangeItems;

- (NSSet *)selectedItems;
- (NSIndexSet *)selectedItemIndices;
- (void)selectItem:(CSIconViewItem *)item;
- (void)selectItemAtIndex:(unsigned)ndx;
- (void)selectItems:(id)setOrArrayOfItemsOrIndexSet;
- (void)deselectItem:(CSIconViewItem *)item;
- (void)deselectItemAtIndex:(unsigned)ndx;
- (void)deselectItems:(id)setOrArrayOfItemsOrIndexSet;
- (void)deselectAll;

- (CSIconViewItem  *)focusedItem;
- (void)setFocusedItem:(CSIconViewItem *)item;
- (BOOL)drawsFocusRing;
- (void)setDrawsFocusRing:(BOOL)dfr;

- (void)autoscrollOnTimer:(NSTimer *)timer;

- (NSImage *)imageOfSelectedItems;
- (NSImage *)imageOfSelectedItemsInRect:(NSRect)selectionRect;
- (NSRect)boundingRectOfSelectedItems;
- (NSRect)boundingRectOfItem:(CSIconViewItem *)item;
- (NSRect)boundingRectOfItems:(id)collection;

- (NSString *)iconViewUniqueID;
- (BOOL)handleSimpleDrag:(id <NSDraggingInfo>)sender;

- (IBAction)scrollToTop:(id)sender;
- (IBAction)scrollToBottom:(id)sender;
- (IBAction)editFocusedItem:(id)sender;
- (IBAction)openFocusedItem:(id)sender;

// Resets the keyboard movement state, so that the arrow keys work as expected
- (void)resetKeyboardMovement;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
