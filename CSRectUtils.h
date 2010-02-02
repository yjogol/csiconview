//
//  CSRectUtils.h
//  CSIconView
//
//  Created by Alastair Houghton on 16/11/2007.
//  Copyright (c) 2007-2010 Coriolis Systems Limited
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

#import <Foundation/NSGeometry.h>

static inline BOOL
CSPointInRect (NSPoint point, NSRect rect)
{
  return (NSMinX (rect) <= point.x
          && NSMaxX (rect) > point.x
          && NSMinY (rect) <= point.y
          && NSMaxY (rect) > point.y);
}

static inline BOOL
CSContainsRect (NSRect outer, NSRect inner)
{
  return (NSMinX (outer) <= NSMinX (inner)
          && NSMaxX (outer) >= NSMaxX (inner)
          && NSMinY (outer) <= NSMinY (inner)
          && NSMaxY (outer) >= NSMaxY (inner));
}

static inline BOOL
CSIntersectsRect (NSRect aRect, NSRect bRect)
{
  NSRect iRect;

  if (NSMinX (aRect) > NSMinX (bRect))
    iRect.origin.x = NSMinX (aRect);
  else
    iRect.origin.x = NSMinX (bRect);

  if (NSMinY (aRect) > NSMinY (bRect))
    iRect.origin.y = NSMinY (aRect);
  else
    iRect.origin.y = NSMinY (bRect);

  if (NSMaxX (aRect) < NSMaxX (bRect))
    iRect.size.width = NSMaxX (aRect) - iRect.origin.x;
  else
    iRect.size.width = NSMaxX (bRect) - iRect.origin.x;

  if (NSMaxY (aRect) < NSMaxY (bRect))
    iRect.size.height = NSMaxY (aRect) - iRect.origin.y;
  else
    iRect.size.height = NSMaxY (bRect) - iRect.origin.y;

  return iRect.size.width > 0 && iRect.size.height > 0;
}

static inline NSRect
CSUnionRect (NSRect aRect, NSRect bRect)
{
  NSRect uRect;

  if (NSMinX (aRect) < NSMinX (bRect))
    uRect.origin.x = NSMinX (aRect);
  else
    uRect.origin.x = NSMinX (bRect);

  if (NSMinY (aRect) < NSMinY (bRect))
    uRect.origin.y = NSMinY (aRect);
  else
    uRect.origin.y = NSMinY (bRect);

  if (NSMaxX (aRect) > NSMaxX (bRect))
    uRect.size.width = NSMaxX (aRect) - uRect.origin.x;
  else
    uRect.size.width = NSMaxX (bRect) - uRect.origin.x;

  if (NSMaxY (aRect) > NSMaxY (bRect))
    uRect.size.height = NSMaxY (aRect) - uRect.origin.y;
  else
    uRect.size.height = NSMaxY (bRect) - uRect.origin.y;

  return uRect;
}

static inline NSRect
CSIntersectionRect (NSRect aRect, NSRect bRect)
{
  NSRect iRect;

  if (NSMinX (aRect) > NSMinX (bRect))
    iRect.origin.x = NSMinX (aRect);
  else
    iRect.origin.x = NSMinX (bRect);

  if (NSMinY (aRect) > NSMinY (bRect))
    iRect.origin.y = NSMinY (aRect);
  else
    iRect.origin.y = NSMinY (bRect);

  if (NSMaxX (aRect) < NSMaxX (bRect))
    iRect.size.width = NSMaxX (aRect) - iRect.origin.x;
  else
    iRect.size.width = NSMaxX (bRect) - iRect.origin.x;

  if (NSMaxY (aRect) < NSMaxY (bRect))
    iRect.size.height = NSMaxY (aRect) - iRect.origin.y;
  else
    iRect.size.height = NSMaxY (bRect) - iRect.origin.y;

  return iRect;
}
