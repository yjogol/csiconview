//
//  CSIconRenderer.h
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

#import <Cocoa/Cocoa.h>
#import "CSIcon.h"

@interface CSIconRenderer : NSObject
{
  NSTextStorage	  *textStorage;
  NSLayoutManager *layoutManager;
  NSTextContainer *textContainer;

  BOOL		  needLayout;

  CSIcon	  *icon;
  NSColor	  *labelColor;
  NSColor	  *labelShadeColor;
  NSSize	  iconSize;
  NSString	  *variant;
}

- (CSIcon *)icon;
- (void)setIcon:(CSIcon *)icon;

- (NSString *)variant;
- (void)setVariant:(NSString *)newVariant;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;

- (void)setTitleAttributes:(NSDictionary *)attributes;

- (NSAttributedString *)attributedTitle;
- (void)setAttributedTitle:(NSAttributedString *)newTitle;

- (NSColor *)labelColor;
- (void)setLabelColor:(NSColor *)labelColor;

- (NSColor *)labelShadeColor;
- (void)setLabelShadeColor:(NSColor *)labelShadeColor;

- (NSSize)iconSize;
- (void)setIconSize:(NSSize)newSize;

- (NSMutableArray *)iconTitleRectsInRect:(NSRect)rect;

- (void)renderIconTitleInRect:(NSRect)rect
	       withBackground:(BOOL)background
		 andFocusRing:(BOOL)focusRing
                    inKeyView:(BOOL)inKeyView;

- (void)drawWithFrame:(NSRect)iconFrame
	      enabled:(BOOL)enabled
	  highlighted:(BOOL)highlighted
      filledHighlight:(BOOL)filledHighlight
	  textOnRight:(BOOL)textOnRight
            inKeyView:(BOOL)inKeyView
             withText:(BOOL)withText;

- (BOOL)isPoint:(NSPoint)pt inTextIfDrawnWithFrame:(NSRect)iconFrame
    textOnRight:(BOOL)textOnRight;

- (BOOL)intersectsWithRect:(NSRect)rect
	  ifDrawnWithFrame:(NSRect)iconFrame
	       highlighted:(BOOL)highlighted
	       textOnRight:(BOOL)textOnRight;

- (NSRect)textRectIfDrawnWithFrame:(NSRect)iconFrame
                       textOnRight:(BOOL)textOnRight;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
