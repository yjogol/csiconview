//
//  CSShading.h
//  CSIconView
//
//  Created by Alastair Houghton on 24/08/2005.
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
#import "CSColorSpace.h"

typedef void (*CSShadingCallback)(CGFloat input,
				  CGFloat *outputs,
				  void    *context);

enum {
  CSShadingDefaultFlags = 0,
  CSShadingExtendStart  = 0x0001,
  CSShadingExtendEnd    = 0x0002
};

typedef struct {
  float	  fraction;
  NSColor *color;
} CSShadingColor;

typedef struct {
  unsigned	 count;
  CSShadingColor *colors;
} CSShadingColorArray;

@interface NSBezierPath (CSShadingSupport)

- (void)shade;

@end

@interface CSShading : NSObject {
  CGShadingRef	      shading;
  CGFunctionRef	      function;
  CSShadingCallback   callback;
  void		      *functionContext;
  BOOL		      freeFunctionContext;
}

+ (CSShading *)currentShading;

+ (CSShading *)axialShadingFromPoint:(NSPoint)startPoint
			     toPoint:(NSPoint)endPoint
			  colorSpace:(CSColorSpace *)colorspace
			       flags:(unsigned)flags
			    function:(CSShadingCallback)function
			     context:(void *)context;

+ (CSShading *)radialShadingFromPoint:(NSPoint)startPoint
			       radius:(float)r1
			      toPoint:(NSPoint)endPoint
			       radius:(float)r2
			   colorSpace:(CSColorSpace *)colorspace
				flags:(unsigned)flags
			     function:(CSShadingCallback)function
			      context:(void *)context;

+ (CSShading *)axialShadingFromPoint:(NSPoint)startPoint
			     toPoint:(NSPoint)endPoint
			  withColors:(CSShadingColorArray)colorArray
			       flags:(unsigned)flags;
  
+ (CSShading *)radialShadingFromPoint:(NSPoint)startPoint
			       radius:(float)r1
			      toPoint:(NSPoint)endPoint
			       radius:(float)r2
			   withColors:(CSShadingColorArray)colorArray
				flags:(unsigned)flags;

- (id)initWithAxialShadingFromPoint:(NSPoint)startPoint
			    toPoint:(NSPoint)endPoint
			 colorSpace:(CSColorSpace *)colorspace
			      flags:(unsigned)flags
			   function:(CSShadingCallback)function
			    context:(void *)context;

- (id)initWithRadialShadingFromPoint:(NSPoint)startPoint
			      radius:(float)r1
			     toPoint:(NSPoint)endPoint
			      radius:(float)r2
			  colorSpace:(CSColorSpace *)colorspace
			       flags:(unsigned)flags
			    function:(CSShadingCallback)function
			     context:(void *)context;

- (id)initWithAxialShadingFromPoint:(NSPoint)startPoint
			    toPoint:(NSPoint)endPoint
			 withColors:(CSShadingColorArray)colors
			      flags:(unsigned)flags;

- (id)initWithRadialShadingFromPoint:(NSPoint)startPoint
			      radius:(float)r1
			     toPoint:(NSPoint)endPoint
			      radius:(float)r2
			  withColors:(CSShadingColorArray)colors
			       flags:(unsigned)flags;

- (void)draw;

/* This isn't quite as sophisticated as the -set implementation for e.g.
   NSColor, in that it doesn't get saved when the graphics context saves
   state, and it's global rather than per-context.  Still, it's nice. */
- (void)set;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
