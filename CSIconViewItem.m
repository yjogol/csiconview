//
//  CSIconViewItem.m
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

#import "CSIconViewItem.h"
#import "NSColor+CSIconViewExtras.h"

@implementation CSIconViewItem

+ (CSIconViewItem *)iconViewItem
{
  return [[[CSIconViewItem alloc] init] autorelease];
}

+ (CSIconViewItem *)iconViewItemWithIcon:(CSIcon *)theIcon
				   title:(NSString *)theTitle
{
  return [[[CSIconViewItem alloc] initWithIcon:theIcon title:theTitle] 
    autorelease];
}

- (id)initWithIcon:(CSIcon *)theIcon
	     title:(NSString *)theTitle
{
  if ((self = [super init])) {
    [self setIcon:theIcon];
    [self setTitle:theTitle];
  }
  
  return self;
}

- (void)dealloc
{
  [icon release];
  [title release];
  [labelColor release];
  [labelShadeColor release];
  [super dealloc];
}

- (unsigned)index
{
  return index;
}

- (void)setIndex:(unsigned)ndx
{
  index = ndx;
}

- (CSIcon *)icon
{
  return icon;
}

- (void)setIcon:(CSIcon *)newIcon
{
  if (newIcon != icon) {
    CSIcon *oldIcon = icon;
    icon = [newIcon retain];
    [oldIcon release];
  }
}

- (NSString *)title
{
  return title;
}

- (void)setTitle:(NSString *)newTitle
{
  NSString *oldTitle = title;
  title = [newTitle copy];
  [oldTitle release];
}

- (id)representedObject
{
  return representedObject;
}

- (void)setRepresentedObject:(id)newObj
{
  if (representedObject != newObj) {
    id oldObj = representedObject;
    representedObject = [newObj retain];
    [oldObj release];
  }
}

- (NSPoint)position
{
  return position;
}

- (void)setPosition:(NSPoint)newPos
{
  position = newPos;
}

- (unsigned)state
{
  return state;
}

- (void)setState:(unsigned)newState
{
  state = newState;
}

- (void)select
{
  state |= kCSIVItemSelectedMask;
}
- (void)deselect
{
  state &= ~kCSIVItemSelectedMask;
}
- (void)toggle
{
  state ^= kCSIVItemSelectedMask;
}

- (void)removeFromCollectionIfDisabled:(id)collection
{
  if (state & kCSIVItemDisabledMask)
    [collection removeObject:self];
}

- (NSColor *)labelColor
{
  return labelColor;
}

- (void)setLabelColor:(NSColor *)newColor
{
  if (labelColor != newColor) {
    CGFloat L, a, b, alpha;
    
    NSColor *oldColor = labelColor;
    labelColor = [newColor retain];
    [oldColor release];
    
    /* We update the labelColorIsLight flag by computing the perceptual
       colour value 'L' from Lab space.  If this is >50, then it's a light
       colour.  If not, it isn't.  Note that this isn't the same as e.g.
       converting to HLS and looking at L; for instance, 100% yellow is a
       light colour, whereas 100% magenta or 100% blue are not. */
    [labelColor getL:&L a:&a b:&b alpha:&alpha];
    
    labelColorIsLight = L > 50;
  }
}

- (BOOL)labelColorIsLight
{
  return labelColorIsLight;
}

- (NSColor *)labelShadeColor
{
  return labelShadeColor;
}

- (void)setLabelShadeColor:(NSColor *)newColor
{
  if (labelShadeColor != newColor) {
    NSColor *oldColor = labelShadeColor;
    labelShadeColor = [newColor retain];
    [oldColor release];
  }
}

- (NSSize)customSize
{
  return customSize;
}

- (void)setCustomSize:(NSSize)size
{
  customSize = size;
}

- (NSSize)customIconSize
{
  return customIconSize;
}

- (void)setCustomIconSize:(NSSize)size
{
  customIconSize = size;
}

@end
