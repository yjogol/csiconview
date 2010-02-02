//
//  CSIconViewItem.h
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
#import "CSIcon.h"

enum {
  kCSIVItemSelectedMask      = 0x0001,
  kCSIVItemLabelledMask      = 0x0002,
  kCSIVItemCustomSizeMask    = 0x0004,
  kCSIVItemOpenMask	     = 0x0008,
  kCSIVItemAcceptingDropMask = 0x0010,
  kCSIVItemDisabledMask	     = 0x0020,
};

@interface CSIconViewItem : NSObject
{
  unsigned     index;
  CSIcon       *icon;
  NSString     *title;
  id	       representedObject;
  
  NSPoint      position;
  
  unsigned     state;
  
  NSColor      *labelColor;
  NSColor      *labelShadeColor;
  BOOL	       labelColorIsLight;
  
  NSSize       customSize;
  NSSize       customIconSize;
}

+ (CSIconViewItem *)iconViewItem;
+ (CSIconViewItem *)iconViewItemWithIcon:(CSIcon *)icon
				   title:(NSString *)title;

- (id)initWithIcon:(CSIcon *)icon title:(NSString *)title;

- (unsigned)index;
- (void)setIndex:(unsigned)ndx;

- (CSIcon *)icon;
- (void)setIcon:(CSIcon *)newIcon;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;

- (id)representedObject;
- (void)setRepresentedObject:(id)newObj;

- (NSPoint)position;
- (void)setPosition:(NSPoint)position;

- (unsigned)state;
- (void)setState:(unsigned)newState;

- (void)select;
- (void)deselect;
- (void)toggle;
- (void)removeFromCollectionIfDisabled:(id)collection;

- (NSColor *)labelColor;
- (void)setLabelColor:(NSColor *)newColor;

- (NSColor *)labelShadeColor;
- (void)setLabelShadeColor:(NSColor *)newColor;

- (BOOL)labelColorIsLight;

- (NSSize)customSize;
- (void)setCustomSize:(NSSize)size;

- (NSSize)customIconSize;
- (void)setCustomIconSize:(NSSize)size;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
