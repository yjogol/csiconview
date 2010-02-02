//
//  CSIconRenderer.m
//  CSIconView
//
//  Created by Alastair Houghton on 29/07/2005.
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

#import "CSIconRenderer.h"
#import "CSShading.h"

// A Finder-like icon cell class
@implementation CSIconRenderer

- (id)init
{
  if ((self = [super init])) {
    layoutManager = [[NSLayoutManager alloc] init];
    textContainer = [[NSTextContainer alloc] init];
    textStorage = [[NSTextStorage alloc] init];
    [self setVariant:kCSNormalIconVariant];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
  }
  
  return self;
}

- (void)dealloc
{
  [textStorage release];
  [layoutManager release];
  [textContainer release];
  [labelColor release];
  [labelShadeColor release];
  [icon release];
  [variant release];
  [super dealloc];
}

- (CSIcon *)icon
{
  return icon;
}

- (void)setIcon:(CSIcon *)theIcon
{
  if (icon != theIcon) {
    CSIcon *oldIcon = icon;
    icon = [theIcon retain];
    [oldIcon release];
  }
}

- (NSString *)variant
{
  return variant;
}

- (void)setVariant:(NSString *)newVariant
{
  if (variant != newVariant) {
    NSString *oldVariant = variant;
    variant = [newVariant retain];
    [oldVariant release];
  }
}

- (NSString *)title
{
  return [textStorage string];
}

- (void)setTitle:(NSString *)newTitle
{
  if (!newTitle)
    newTitle = @"";
  
  [textStorage replaceCharactersInRange:NSMakeRange (0, [textStorage length])
			     withString:newTitle];
  needLayout = YES;
}

- (void)setTitleAttributes:(NSDictionary *)newAttributes
{
  [textStorage setAttributes:newAttributes
		       range:NSMakeRange (0, [textStorage length])];
}

- (NSAttributedString *)attributedTitle
{
  return textStorage;
}

- (void)setAttributedTitle:(NSAttributedString *)newTitle
{
  [textStorage replaceCharactersInRange:NSMakeRange (0, [textStorage length])
		   withAttributedString:newTitle];
  needLayout = YES;
}

- (NSColor *)labelColor
{
  return labelColor;
}

- (void)setLabelColor:(NSColor *)newColor
{
  if (newColor != labelColor) {
    NSColor *oldColor = labelColor;
    labelColor = [newColor retain];
    [oldColor release];
  }
}

- (NSColor *)labelShadeColor
{
  return labelShadeColor;
}

- (void)setLabelShadeColor:(NSColor *)newColor
{
  if (newColor != labelShadeColor) {
    NSColor *oldColor = labelShadeColor;
    labelShadeColor = [newColor retain];
    [oldColor release];
  }
}

- (NSSize)iconSize
{
  return iconSize;
}

- (void)setIconSize:(NSSize)newSize
{
  iconSize = newSize;
}

/* Assumes the rectangles are all centred. */
- (NSBezierPath *)bezierPathSurroundingRects:(NSMutableArray *)rectArray
				      radius:(float)r
				     padding:(float)padding
{
  BOOL changed1, changed2;
  unsigned count = [rectArray count];
  float a = M_SQRT1_2 * r;
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSRect prevRect, rect;
  float x[4], y[4];
  unsigned n;
    
  if (!count)
    return path;
  
  /* First check if there are any rectangles that are too close in size
     to draw smooth curves between them.  If so, expand the smaller ones
     to match the size of the larger ones. */
  changed1 = changed2 = NO;

  do {
    for (n = 0; n + 1 < count; ++n) {
      NSRect r1, r2;
      float xdiff;
      
      changed1 = changed2 = NO;
      r1 = [[rectArray objectAtIndex:n] rectValue];
      r2 = [[rectArray objectAtIndex:n + 1] rectValue];
      
      xdiff = NSMinX (r1) - NSMinX (r2);
      if (xdiff != 0.0f && fabs (xdiff) < r) {
	if (xdiff < 0.0f) {
	  r2.origin.x = r1.origin.x;
	  r2.size.width -= xdiff;
	  changed2 = YES;
	} else {
	  r1.origin.x = r2.origin.x;
	  r1.size.width += xdiff;
	  changed1 = YES;
	}
      }
      
      xdiff = NSMaxX (r1) - NSMaxX (r2);
      if (xdiff != 0.0f && fabs (xdiff) < r) {
	if (xdiff < 0.0f) {
	  r1.size.width -= xdiff;
	  changed1 = YES;
	} else {
	  r2.size.width += xdiff;
	  changed2 = YES;
	}
      }

      if (changed1) {
	[rectArray replaceObjectAtIndex:n 
			     withObject:[NSValue valueWithRect:r1]];
      }
      if (changed2) {
	[rectArray replaceObjectAtIndex:n + 1
			     withObject:[NSValue valueWithRect:r2]];
      }
    }
  } while (changed1 || changed2);
  
  // Do the top part of the top element
  rect = [[rectArray objectAtIndex:0] rectValue];
  x[0] = NSMinX (rect) - padding;
  x[1] = NSMinX (rect) + a - padding;
  x[2] = NSMaxX (rect) + padding;
  y[0] = NSMaxY (rect) + padding;
  y[1] = NSMaxY (rect) - a + padding;
  
  [path moveToPoint:NSMakePoint (x[0], y[1])];
  [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				 toPoint:NSMakePoint (x[1], y[0])
				  radius:r];
  [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				 toPoint:NSMakePoint (x[2], y[1])
				  radius:r];
  
  // Now go down the right hand side
  for (n = 1; n < count; ++n) {
    float prevX, thisX;
    
    prevRect = rect;
    rect = [[rectArray objectAtIndex:n] rectValue];
    
    prevX = NSMaxX (prevRect);
    thisX = NSMaxX (rect);
    
    if (prevX > thisX) {
      x[0] = NSMaxX (prevRect) + padding;
      x[1] = NSMaxX (prevRect) - a + padding;
      x[2] = NSMaxX (rect) + padding;
      y[0] = NSMinY (prevRect) - padding;
      y[1] = NSMaxY (rect) - M_SQRT1_2 * a - padding;
      
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				     toPoint:NSMakePoint (x[1], y[0])
				      radius:r];
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				     toPoint:NSMakePoint (x[2], y[1])
				      radius:0.6 * r];
    } else if (prevX < thisX) {
      x[0] = NSMaxX (prevRect) + padding;
      x[1] = NSMaxX (prevRect) + M_SQRT1_2 * a + padding;
      x[2] = NSMaxX (rect) + padding;
      y[0] = NSMinY (prevRect) + padding;
      y[1] = NSMaxY (rect) - a + padding;
      
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				     toPoint:NSMakePoint (x[1], y[0])
				      radius:0.6 * r];
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				     toPoint:NSMakePoint (x[2], y[1])
				      radius:r];
    } else {
      [path lineToPoint:NSMakePoint (NSMaxX (rect) + padding, NSMaxY (rect))];
    }
  }
  
  // Do the bottom part of the bottom element
  rect = [[rectArray objectAtIndex:count - 1] rectValue];
  x[0] = NSMaxX (rect) + padding;
  x[1] = NSMaxX (rect) - a + padding;
  x[2] = NSMinX (rect) - padding;
  y[0] = NSMinY (rect) - padding;
  y[1] = NSMinY (rect) + a - padding;
  
  [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				 toPoint:NSMakePoint (x[1], y[0])
				  radius:r];
  [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				 toPoint:NSMakePoint (x[2], y[1])
				  radius:r];
  
  // Now go up the left hand side
  for (n = count - 1; n > 0; --n) {
    float prevX, thisX;
    
    prevRect = rect;
    rect = [[rectArray objectAtIndex:n - 1] rectValue];

    prevX = NSMinX (prevRect);
    thisX = NSMinX (rect);
    
    if (prevX < thisX) {
      x[0] = NSMinX (prevRect) - padding;
      x[1] = NSMinX (prevRect) + a - padding;
      x[2] = NSMinX (rect) - padding;
      y[0] = NSMaxY (prevRect) + padding;
      y[1] = NSMinY (rect) + M_SQRT1_2 * a + padding;
      
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				     toPoint:NSMakePoint (x[1], y[0])
				      radius:r];
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				     toPoint:NSMakePoint (x[2], y[1])
				      radius:0.6 * r];
    } else if (prevX > thisX) {
      x[0] = NSMinX (prevRect) - padding;
      x[1] = NSMinX (prevRect) - M_SQRT1_2 * a - padding;
      x[2] = NSMinX (rect) - padding;
      y[0] = NSMaxY (prevRect) - padding;
      y[1] = NSMinY (rect) + a - padding;
      
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[0], y[0])
				     toPoint:NSMakePoint (x[1], y[0])
				      radius:0.6 * r];
      [path appendBezierPathWithArcFromPoint:NSMakePoint (x[2], y[0])
				     toPoint:NSMakePoint (x[2], y[1])
				      radius:r];
    } else {
      [path lineToPoint:NSMakePoint (NSMinX (rect) - padding, NSMinY (rect))];
    }
  }

  // Close the path
  [path closePath];
  
  return path;
}

/* If the string has changed, update the text storage object with the new
   string to render.  We might have to replace some of the characters with
   an ellipsis if they won't fit. */
- (void)updateTextStorage
{
  if (needLayout) {
    NSRange glyphRange;
    NSRect lineRect;
    NSRange realRange;
    float fraction;
    unsigned character;
    const unichar ellipsis = 0x2026;
    NSString *ellipsisString = [NSString stringWithCharacters:&ellipsis
						       length:1];
    unsigned numberOfGlyphs, glyph;

    needLayout = NO;
    
    numberOfGlyphs = [layoutManager numberOfGlyphs];
    
    glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
    if (glyphRange.length
	&& glyphRange.length < numberOfGlyphs) {
      lineRect = [layoutManager 
	  lineFragmentUsedRectForGlyphAtIndex:glyphRange.length - 1
			       effectiveRange:&realRange];
      
      glyph = [layoutManager glyphIndexForPoint:
	NSMakePoint(0.5 * (NSMinX (lineRect) + NSMaxX (lineRect)),
		    0.5 * (NSMinY (lineRect) + NSMaxY (lineRect)))
				inTextContainer:textContainer
		 fractionOfDistanceThroughGlyph:&fraction];
      
      character = [layoutManager characterIndexForGlyphAtIndex:glyph];
      
      while (glyphRange.length < numberOfGlyphs
	     && [textStorage length] > character + 1) {      
	[textStorage replaceCharactersInRange:NSMakeRange (character, 2)
				   withString:ellipsisString];
	glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
	numberOfGlyphs = [layoutManager numberOfGlyphs];
      }
    }
  }
}

- (NSMutableArray *)iconTitleRectsInRect:(NSRect)rect
{
  NSRange glyphRange;
  unsigned glyph, numberOfGlyphs;
  NSMutableArray *rectArray = [NSMutableArray array];

  [self updateTextStorage];
  glyph = 0;
  numberOfGlyphs = [layoutManager numberOfGlyphs];
  
  while (glyph < numberOfGlyphs) {
    NSRect lineRect;
    
    lineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyph
						   effectiveRange:&glyphRange];
    
    // Subtract the width of a trailing space character
    if (glyphRange.length) {
      unsigned characterIndex = [layoutManager characterIndexForGlyphAtIndex:
	glyphRange.location + glyphRange.length - 1];
      unichar ch = [[textStorage string] characterAtIndex:characterIndex];
      
      if (ch == ' ') {
	unsigned rectCount;
	NSRectArray rectArray
	  = [layoutManager rectArrayForGlyphRange:
	    NSMakeRange (glyphRange.location + glyphRange.length - 1, 1)
			 withinSelectedGlyphRange:NSMakeRange (NSNotFound, 0)
				  inTextContainer:textContainer
					rectCount:&rectCount];
	float width;
	
	while (rectCount--) {
	  width += NSWidth (rectArray[rectCount]);
	}
	
	lineRect.size.width -= width;
      }
    }
    
    lineRect.origin.x += rect.origin.x;
    lineRect.origin.y += rect.origin.y;
    
    [rectArray insertObject:[NSValue valueWithRect:lineRect]
		    atIndex:0];
    
    glyph = glyphRange.location + glyphRange.length;
  }
  
  return rectArray;
}

- (float)heightOfTitleInRect:(NSRect)rect
{
  NSSize currentSize = [textContainer containerSize];
  NSRectArray rects;
  unsigned rectCount, n;
  float height = 0.0;
  
  if (currentSize.height != rect.size.height
      || currentSize.width != rect.size.width) {
    [textContainer setContainerSize:rect.size];
    needLayout = YES;
  }
  
  [self updateTextStorage];
 
  rects = [layoutManager rectArrayForGlyphRange:
    [layoutManager glyphRangeForTextContainer:textContainer]
		       withinSelectedGlyphRange:NSMakeRange (NSNotFound, 0)
				inTextContainer:textContainer
				      rectCount:&rectCount];
  
  for (n = 0; n < rectCount; ++n) {
    if (height < NSMaxY (rects[n]))
      height = NSMaxY (rects[n]);
  }
  
  return height;
}

- (NSArray *)titleRectArrayInRect:(NSRect)rect
{
  NSSize currentSize = [textContainer containerSize];
  
  if (currentSize.height != rect.size.height
      || currentSize.width != rect.size.width) {
    [textContainer setContainerSize:rect.size];
    needLayout = YES;
  }

  return [self iconTitleRectsInRect:rect];
}

- (void)renderIconTitleInRect:(NSRect)rect
	       withBackground:(BOOL)background
		 andFocusRing:(BOOL)focusRing
                    inKeyView:(BOOL)inKeyView
{
  NSRange glyphRange;
  NSSize currentSize = [textContainer containerSize];
  
  if (currentSize.height != rect.size.height
      || currentSize.width != rect.size.width) {
    [textContainer setContainerSize:rect.size];
    needLayout = YES;
  }
  
  [self updateTextStorage];

  if (background) {
    NSMutableArray *rectArray = [self iconTitleRectsInRect:rect];
    float height = NSHeight ([[rectArray objectAtIndex:0] rectValue]);
    NSBezierPath *backgroundPath = [self bezierPathSurroundingRects:rectArray
							     radius:0.5 * height
							    padding:1.0];
    
    if (!labelColor) {
      if (inKeyView)
        [[NSColor alternateSelectedControlColor] set];
      else
        [[NSColor secondarySelectedControlColor] set];
      
      [backgroundPath fill];
    } else if (!labelShadeColor) {
      [labelColor set];
      [backgroundPath fill];
    } else {
      CSShadingColor colors[] = {
	0.0, labelColor,
	1.0, labelShadeColor
      };
      CSShadingColorArray colorArray = { 2, colors };
      NSRect bounds = [backgroundPath bounds];
      NSPoint top = NSMakePoint (0.0, NSMinY (bounds));
      NSPoint bottom = NSMakePoint (0.0, NSMaxY (bounds));
      CSShading *shading
	= [CSShading axialShadingFromPoint:bottom
				   toPoint:top
				withColors:colorArray
				     flags:CSShadingDefaultFlags];
      
      [shading set];
      [backgroundPath shade];
    }
    
    if (focusRing) {
      [NSGraphicsContext saveGraphicsState];
      NSSetFocusRingStyle (NSFocusRingOnly);
      [backgroundPath fill];
      [NSGraphicsContext restoreGraphicsState];
    }
  }
  
  glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];

  [layoutManager drawGlyphsForGlyphRange:glyphRange
				 atPoint:rect.origin];
}

- (void)drawWithFrame:(NSRect)iconFrame
	      enabled:(BOOL)enabled
	  highlighted:(BOOL)highlighted
      filledHighlight:(BOOL)filledHighlight
	  textOnRight:(BOOL)textOnRight
            inKeyView:(BOOL)inKeyView
             withText:(BOOL)withText
{
  NSRect iconRect;
  NSPoint iconPos;
  NSRect textRect;

  iconFrame = NSInsetRect (iconFrame, 2.0, 2.0);
  
  if (textOnRight) {
    iconPos = NSMakePoint (NSMinX (iconFrame) + 2.0,
			   NSMinY (iconFrame) 
			   + 0.5 * (NSHeight (iconFrame) + iconSize.height));
  } else {
    iconPos = NSMakePoint (NSMinX (iconFrame)
			   + 0.5 * (NSWidth (iconFrame) - iconSize.width),
			   NSMinY (iconFrame) + iconSize.height + 2.0);
  }
  
  iconRect = NSMakeRect (iconPos.x - 2.0, iconPos.y - iconSize.height - 2.0,
			 iconSize.width + 4.0, iconSize.height + 4.0);
  
  if (enabled) {    
    NSRect drawRect = NSMakeRect (iconPos.x, iconPos.y - iconSize.height,
				  iconSize.width, iconSize.height);

    if (highlighted) {
      NSBezierPath *path = [NSBezierPath bezierPath];
      
      [[NSColor secondarySelectedControlColor] set];
      [path appendBezierPathWithRoundedRect:iconRect xRadius:4.0 yRadius:4.0];
      
      if (filledHighlight)
	[path fill];
      else {
	[path setLineWidth:2.0];
	[path stroke];
      }
    }
    
    if (icon) {
      [icon drawVariant:variant inRect:drawRect 
	      operation:NSCompositeSourceOver fraction:1.0]; 
    } else {
      NSBezierPath *path = [NSBezierPath bezierPath];
      float dash[2] = { 5.0, 2.0 };
      
      if (highlighted)
	[[[NSColor secondarySelectedControlColor]
	  blendedColorWithFraction:0.3
			   ofColor:[NSColor blackColor]] set];
      else
	[[NSColor secondarySelectedControlColor] set];
      
      [path appendBezierPathWithRoundedRect:iconRect xRadius:4.0 yRadius:4.0];

      [path setLineWidth:2.0];
      [path setLineDash:dash count:2 phase:0.0f];
      [path stroke];
    }    
  } else {
    NSRect drawRect = NSMakeRect (iconPos.x, iconPos.y - iconSize.height,
				  iconSize.width, iconSize.height);

    if (icon) {
      [icon drawVariant:variant inRect:drawRect
	      operation:NSCompositeSourceOver fraction:0.5];
    } else {
      NSBezierPath *path = [NSBezierPath bezierPath];
      float dash[2] = { 5.0, 2.0 };
      
      [[[NSColor secondarySelectedControlColor] colorWithAlphaComponent:0.5]
	set];
      [path appendBezierPathWithRoundedRect:iconRect xRadius:4.0 yRadius:4.0];
      
      [path setLineWidth:2.0];
      [path setLineDash:dash count:2 phase:0];
      [path stroke];
    }
  }
  
  if (withText) {
    if (textOnRight) {
      float height;
      
      textRect.origin.x = iconPos.x + iconSize.width + 6.0;
      textRect.origin.y = 0.0f;
      textRect.size.width = NSMaxX (iconFrame) - textRect.origin.x - 4.0;
      textRect.size.height = NSHeight (iconFrame);
      
      height = [self heightOfTitleInRect:textRect];
      
      textRect.origin.y = (NSMinY (iconFrame)
                           + 0.5 * (NSHeight (iconFrame) - height));
    } else {
      textRect.origin.x = iconFrame.origin.x + 2.0;
      textRect.size.width = iconFrame.size.width - 4.0;
      textRect.origin.y = iconPos.y + 6.0;
      textRect.size.height = NSMaxY (iconFrame) - textRect.origin.y - 4.0;
    }
    
    [self renderIconTitleInRect:textRect
                 withBackground:(enabled && highlighted) || labelColor
                   andFocusRing:highlighted && labelShadeColor
                      inKeyView:inKeyView];
  }
}

- (NSRect)textRectIfDrawnWithFrame:(NSRect)iconFrame
                       textOnRight:(BOOL)textOnRight
{
  NSRect iconRect;
  NSPoint iconPos;
  NSRect textRect;
  
  iconFrame = NSInsetRect (iconFrame, 2.0, 2.0);
  
  if (textOnRight) {
    iconPos = NSMakePoint (NSMinX (iconFrame) + 2.0,
			   NSMinY (iconFrame) 
			   + 0.5 * (NSHeight (iconFrame) + iconSize.height));
  } else {
    iconPos = NSMakePoint (NSMinX (iconFrame)
			   + 0.5 * (NSWidth (iconFrame) - iconSize.width),
			   NSMinY (iconFrame) + iconSize.height + 2.0);
  }
  
  iconRect = NSMakeRect (iconPos.x - 2.0, iconPos.y - iconSize.height - 2.0,
			 iconSize.width + 4.0, iconSize.height + 4.0);
    
  if (textOnRight) {
    float height;
    
    textRect.origin.x = iconPos.x + iconSize.width + 6.0;
    textRect.origin.y = 0.0f;
    textRect.size.width = NSMaxX (iconFrame) - textRect.origin.x - 4.0;
    textRect.size.height = NSHeight (iconFrame);
    
    height = [self heightOfTitleInRect:textRect];
    
    textRect.origin.y = (NSMinY (iconFrame)
			 + 0.5 * (NSHeight (iconFrame) - height));
  } else {
    textRect.origin.x = iconFrame.origin.x + 2.0;
    textRect.size.width = iconFrame.size.width - 4.0;
    textRect.origin.y = iconPos.y + 6.0;
    textRect.size.height = NSMaxY (iconFrame) - textRect.origin.y - 4.0;
  }
  
  return textRect;
}

- (BOOL)isPoint:(NSPoint)pt
  inTextIfDrawnWithFrame:(NSRect)iconFrame
             textOnRight:(BOOL)textOnRight
{
  NSRect iconRect;
  NSPoint iconPos;
  NSRect textRect;
  NSArray *rectArray;
  unsigned n, count;
  
  iconFrame = NSInsetRect (iconFrame, 2.0, 2.0);
  
  if (textOnRight) {
    iconPos = NSMakePoint (NSMinX (iconFrame) + 2.0,
			   NSMinY (iconFrame) 
			   + 0.5 * (NSHeight (iconFrame) + iconSize.height));
  } else {
    iconPos = NSMakePoint (NSMinX (iconFrame)
			   + 0.5 * (NSWidth (iconFrame) - iconSize.width),
			   NSMinY (iconFrame) + iconSize.height + 2.0);
  }
  
  iconRect = NSMakeRect (iconPos.x - 2.0, iconPos.y - iconSize.height - 2.0,
			 iconSize.width + 4.0, iconSize.height + 4.0);
  
  if (NSPointInRect (pt, iconRect))
    return NO;
  
  if (textOnRight) {
    float height;
    
    textRect.origin.x = iconPos.x + iconSize.width + 6.0;
    textRect.origin.y = 0.0f;
    textRect.size.width = NSMaxX (iconFrame) - textRect.origin.x - 4.0;
    textRect.size.height = NSHeight (iconFrame);
    
    height = [self heightOfTitleInRect:textRect];
    
    textRect.origin.y = (NSMinY (iconFrame)
			 + 0.5 * (NSHeight (iconFrame) - height));
  } else {
    textRect.origin.x = iconFrame.origin.x + 2.0;
    textRect.size.width = iconFrame.size.width - 4.0;
    textRect.origin.y = iconPos.y + 6.0;
    textRect.size.height = NSMaxY (iconFrame) - textRect.origin.y - 4.0;
  }
  
  rectArray = [self titleRectArrayInRect:textRect];
  count = [rectArray count];
  for (n = 0; n < count; ++n) {
    if (NSPointInRect (pt, [[rectArray objectAtIndex:n] rectValue]))
      return YES;
  }
  
  return NO;  
}

- (BOOL)intersectsWithRect:(NSRect)rect
	  ifDrawnWithFrame:(NSRect)iconFrame
	       highlighted:(BOOL)highlighted
	       textOnRight:(BOOL)textOnRight
{
  NSRect iconRect;
  NSPoint iconPos;
  NSRect textRect;
  NSRect drawRect;
  NSArray *rectArray;
  unsigned n, count;
  
  iconFrame = NSInsetRect (iconFrame, 2.0, 2.0);
  
  if (textOnRight) {
    iconPos = NSMakePoint (NSMinX (iconFrame) + 2.0,
			   NSMinY (iconFrame) 
			   + 0.5 * (NSHeight (iconFrame) + iconSize.height));
  } else {
    iconPos = NSMakePoint (NSMinX (iconFrame)
			   + 0.5 * (NSWidth (iconFrame) - iconSize.width),
			   NSMinY (iconFrame) + iconSize.height + 2.0);
  }
  
  iconRect = NSMakeRect (iconPos.x - 2.0, iconPos.y - iconSize.height - 2.0,
			 iconSize.width + 4.0, iconSize.height + 4.0);
  drawRect = NSMakeRect (iconPos.x, iconPos.y - iconSize.height,
			 iconSize.width, iconSize.height);

  if (icon && !highlighted) {
    if ([icon variant:variant wouldIntersectRect:rect
	ifDrawnInRect:drawRect])
      return YES;
  } else if (highlighted && NSIntersectsRect (rect, iconRect))
    return YES;
  else if (NSIntersectsRect (rect, drawRect))
    return YES;
  
  if (textOnRight) {
    float height;
    
    textRect.origin.x = iconPos.x + iconSize.width + 6.0;
    textRect.origin.y = 0.0f;
    textRect.size.width = NSMaxX (iconFrame) - textRect.origin.x - 4.0;
    textRect.size.height = NSHeight (iconFrame);
    
    height = [self heightOfTitleInRect:textRect];
    
    textRect.origin.y = (NSMinY (iconFrame)
			 + 0.5 * (NSHeight (iconFrame) - height));
  } else {
    textRect.origin.x = iconFrame.origin.x + 2.0;
    textRect.size.width = iconFrame.size.width - 4.0;
    textRect.origin.y = iconPos.y + 6.0;
    textRect.size.height = NSMaxY (iconFrame) - textRect.origin.y - 4.0;
  }
  
  rectArray = [self titleRectArrayInRect:textRect];
  count = [rectArray count];
  for (n = 0; n < count; ++n) {
    if (NSIntersectsRect (rect, [[rectArray objectAtIndex:n] rectValue]))
      return YES;
  }
  
  return NO;
}

@end
