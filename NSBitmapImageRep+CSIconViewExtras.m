//
//  NSBitmapImageRep+CSIconViewExtras.m
//  CSIconView
//
//  Created by Alastair Houghton on 03/09/2005.
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

#import "NSBitmapImageRep+CSIconViewExtras.h"

@implementation NSBitmapImageRep (CSIconViewExtras)

- (BOOL)rectIntersectsWithImage:(NSRect)rect
{
  return [self rectIntersectsWithImage:rect withAlphaThreshold:0.5f];
}

- (BOOL)rectIntersectsWithImage:(NSRect)rect
	     withAlphaThreshold:(float)thresh
{
  NSSize size = [self size];
  NSRect ourRect = { { 0.0f, 0.0f }, size };
  
  /* First deal with the simple cases; if the rectangle is outside of the
     bitmap, clearly we don't intersect.  Also, if there's no alpha, and
     the rectangle is inside, then clearly we do. */
  if (!NSIntersectsRect (rect, ourRect))
    return NO;
  
  /* Clip the rectangle so we don't stray outside it */
  rect = NSIntersectionRect (rect, ourRect);
  
  if (![self hasAlpha])
    return YES;
  
  /* OK; now we deal with planar vs. non-planar bitmaps */
  if ([self isPlanar]) {
    int bps = [self bitsPerSample];
    int planes = [self numberOfPlanes];
    int width = [self pixelsHigh];
    int height = [self pixelsWide];
    int bytesPerRow = [self bytesPerRow];
    unsigned char *planeData[5];
    unsigned char *alphaPlanePtr;
    NSBitmapFormat bitmapFormat;
    int miny = floor (NSMinY (rect)), maxy = ceil (NSMaxY (rect));
    int minx = floor (NSMinX (rect)), maxx = ceil (NSMaxX (rect));
    int y;
    
    [self getBitmapDataPlanes:planeData];
    
    if ([self respondsToSelector:@selector(bitmapFormat)])
      bitmapFormat = [self bitmapFormat];
    else
      bitmapFormat = 0;

    if (bitmapFormat & NSAlphaFirstBitmapFormat)
      alphaPlanePtr = planeData[0];
    else
      alphaPlanePtr = planeData[planes - 1];
    
    /* Now we have a pointer to the alpha plane, run through it checking
       pixels within the specified rectangle for alignment. */
    for (y = miny; y < maxy && y < height; ++y) {
      void *rowPtr = alphaPlanePtr + y * bytesPerRow;
      int x;
      
      for (x = minx; x < maxx && x < width; ++x) {
	if (bitmapFormat & NSFloatingPointSamplesBitmapFormat) {
	  if (((float *)rowPtr)[x] >= thresh)
	    return YES;
	} else {
	  switch (bps) {
	    case 8: {
	      unsigned char val = ((unsigned char *)rowPtr)[x];
	      
	      if (val >= 255 * thresh)
		return YES;
	      break;
	    }
	    case 16: {
	      unsigned short val = ((unsigned short *)rowPtr)[x];
	      
	      if (val >= 65535 * thresh)
		return YES;
	      break;
	    }
	  }
	}
      }
    }
  } else {
    int bps = [self bitsPerSample];
    int spp = [self samplesPerPixel];
    int bpp = [self bitsPerPixel];
    int bytesPerRow = [self bytesPerRow];
    unsigned char *bitmapData = [self bitmapData];
    NSBitmapFormat bitmapFormat;
    int miny = floor (NSMinY (rect)), maxy = ceil (NSMaxY (rect));
    int minx = floor (NSMinX (rect)), maxx = ceil (NSMaxX (rect));
    int y;
    
    if ([self respondsToSelector:@selector(bitmapFormat)])
      bitmapFormat = [self bitmapFormat];
    else
      bitmapFormat = 0;

    for (y = miny; y < maxy; ++y) {
      unsigned char *rowPtr = bitmapData + bytesPerRow * y;
      int x;
      
      for (x = minx; x < maxx; ++x) {
	if (bitmapFormat & NSFloatingPointSamplesBitmapFormat) {
	  float *pixelPtr = (float *)(rowPtr + (bpp * x) / 8);
	  if (bitmapFormat & NSAlphaFirstBitmapFormat) {
	    if (*(float *)pixelPtr >= thresh)
	      return YES;
	  } else {
	    if (((float *)pixelPtr)[spp - 1] >= thresh)
	      return YES;
	  }
	} else {
	  switch (bps) {
	    case 8: {
	      unsigned char val = ((unsigned char *)rowPtr)[x * spp];
	      
	      if (val >= 255 * thresh)
		return YES;
	      break;
	    }
	    case 16: {
	      unsigned short val = ((unsigned short *)rowPtr)[x * spp];
	      
	      if (val >= 65535 * thresh)
		return YES;
	      break;
	    }
	  }
	}
      }
    }
  }
  
  return NO;
}

@end
