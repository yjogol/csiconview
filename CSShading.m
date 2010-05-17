//
//  CSShading.m
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

#import "CSShading.h"

static CSShading *currentShading;

struct color {
  CGFloat fraction, r, g, b, a;
};

struct color_array {
  unsigned	count;
  struct color	colors[0];
};

@implementation CSShading

static void
shadingFunction (void *info,
		 const CGFloat *input,
		 CGFloat *outputs)
{
  CSShading *shading = (CSShading *)info;
  
  shading->callback (*input, outputs, shading->functionContext);
}

static void
shadeFromColorArray (CGFloat input, CGFloat *outputs, void *colorArrayPtr)
{
  struct color_array *colorArray = (struct color_array *)colorArrayPtr;
  struct color *last = &colorArray->colors[colorArray->count - 1];
  unsigned n;

  for (n = 0; n + 1 < colorArray->count; ++n) {
    struct color *color1 = &colorArray->colors[n];
    struct color *color2 = &colorArray->colors[n + 1];
    
    if (color1->fraction >= input) {
      outputs[0] = color1->r;
      outputs[1] = color1->g;
      outputs[2] = color1->b;
      outputs[3] = color1->a;
      return;
    } else if (color2->fraction >= input) {
      CGFloat range = color2->fraction - color1->fraction;
      CGFloat offset = color2->fraction - input;
      CGFloat fraction = offset / range;
      CGFloat ifraction = 1.0f - fraction;
      
      outputs[0] = color1->r * fraction + color2->r * ifraction;
      outputs[1] = color1->g * fraction + color2->g * ifraction;
      outputs[2] = color1->b * fraction + color2->b * ifraction;
      outputs[3] = color1->a * fraction + color2->a * ifraction;
      return;
    }
  }
  
  outputs[0] = last->r;
  outputs[1] = last->g;
  outputs[2] = last->b;
  outputs[3] = last->a;
}

struct color_array *
generateColorArray (CSShadingColorArray *oldArray)
{
  struct color_array *colorArray;
  unsigned n;
  
  colorArray = (struct color_array *) malloc (sizeof (struct color_array)
					      + (oldArray->count
						 * sizeof (struct color)));
  
  if (!colorArray)
    return NULL;
  
  colorArray->count = oldArray->count;

  for (n = 0; n < colorArray->count; ++n) {
    NSColor *color = [oldArray->colors[n].color colorUsingColorSpaceName:
      NSCalibratedRGBColorSpace];
    
    colorArray->colors[n].fraction = oldArray->colors[n].fraction;
    [color getRed:&colorArray->colors[n].r
	    green:&colorArray->colors[n].g
	     blue:&colorArray->colors[n].b
	    alpha:&colorArray->colors[n].a];
  }
  
  return colorArray;
}

+ (CSShading *)currentShading
{
  return currentShading;
}

+ (CSShading *)axialShadingFromPoint:(NSPoint)startPoint
			     toPoint:(NSPoint)endPoint
			  colorSpace:(CSColorSpace *)colorSpace
			       flags:(unsigned)flags
			    function:(CSShadingCallback)function
			     context:(void *)context
{
  return [[[CSShading alloc] initWithAxialShadingFromPoint:startPoint
						  toPoint:endPoint
					       colorSpace:colorSpace
						    flags:flags
						 function:function
						  context:context] autorelease];
}

+ (CSShading *)radialShadingFromPoint:(NSPoint)startPoint
			       radius:(float)r1
			      toPoint:(NSPoint)endPoint
			       radius:(float)r2
			   colorSpace:(CSColorSpace *)colorSpace
				flags:(unsigned)flags
			     function:(CSShadingCallback)function
			      context:(void *)context
{
  return [[[CSShading alloc] initWithRadialShadingFromPoint:startPoint
						    radius:r1
						   toPoint:endPoint
						    radius:r2
						colorSpace:colorSpace
						     flags:flags
						  function:function
						   context:context] autorelease];
}

+ (CSShading *)axialShadingFromPoint:(NSPoint)startPoint
			     toPoint:(NSPoint)endPoint
			  withColors:(CSShadingColorArray)colorArray
			       flags:(unsigned)flags
{
  return [[[CSShading alloc] initWithAxialShadingFromPoint:startPoint
						   toPoint:endPoint
						withColors:colorArray
						     flags:flags] autorelease];
}

+ (CSShading *)radialShadingFromPoint:(NSPoint)startPoint
			       radius:(float)r1
			      toPoint:(NSPoint)endPoint
			       radius:(float)r2
			   withColors:(CSShadingColorArray)colorArray
				flags:(unsigned)flags
{
  return [[[CSShading alloc] initWithRadialShadingFromPoint:startPoint
						     radius:r1
						    toPoint:endPoint
						     radius:r2
						 withColors:colorArray
						      flags:flags] autorelease];
}

- (id)initWithAxialShadingFromPoint:(NSPoint)startPoint
			    toPoint:(NSPoint)endPoint
			 colorSpace:(CSColorSpace *)colorSpace
			      flags:(unsigned)flags
			   function:(CSShadingCallback)func
			    context:(void *)context
{
  static const CGFloat domain[2] = { 0.0f, 1.0f };
  static const CGFloat range[8]
    = { 0.0f, 1.0f,
	0.0f, 1.0f,
	0.0f, 1.0f,
	0.0f, 1.0f };
  CGFunctionCallbacks callbackInfo = { 0, shadingFunction, NULL };
  
  if (!(self = [super init]))
    return nil;

  if (!colorSpace)
    colorSpace = [CSColorSpace genericRGBColorSpace];
  
  function = CGFunctionCreate (self,
			       1,
			       domain,
			       4,
			       range,
			       &callbackInfo);
  
  if (!function) {
    [self release];
    return nil;
  }
  
  shading = CGShadingCreateAxial ([colorSpace cgColorSpaceRef],
				  *(CGPoint *)&startPoint,
				  *(CGPoint *)&endPoint,
				  function,
				  (flags & CSShadingExtendStart) ? true : false,
				  (flags & CSShadingExtendEnd) ? true : false);
  
  if (!shading) {
    [self release];
    return nil;
  }
  
  functionContext = context;
  callback = func;
  
  return self;
}

- (id)initWithRadialShadingFromPoint:(NSPoint)startPoint
			      radius:(float)r1
			     toPoint:(NSPoint)endPoint
			      radius:(float)r2
			  colorSpace:(CSColorSpace *)colorSpace
			       flags:(unsigned)flags
			    function:(CSShadingCallback)func
			     context:(void *)context
{
  static const CGFloat domain[2] = { 0.0f, 1.0f };
  static const CGFloat range[8]
    = { 0.0f, 1.0f,
      0.0f, 1.0f,
      0.0f, 1.0f,
      0.0f, 1.0f };
  CGFunctionCallbacks callbackInfo = { 0, shadingFunction, NULL };
  
  if (!(self = [super init]))
    return nil;
  
  if (!colorSpace)
    colorSpace = [CSColorSpace genericRGBColorSpace];
  
  function = CGFunctionCreate (self,
			       1,
			       domain,
			       4,
			       range,
			       &callbackInfo);
  
  if (!function) {
    [self release];
    return nil;
  }
  
  shading = CGShadingCreateRadial ([colorSpace cgColorSpaceRef],
				  *(CGPoint *)&startPoint, r1,
				  *(CGPoint *)&endPoint, r2,
				  function,
				  (flags & CSShadingExtendStart) ? true : false,
				  (flags & CSShadingExtendEnd) ? true : false);
  
  if (!shading) {
    [self release];
    return nil;
  }
  
  functionContext = context;
  callback = func;
  
  return self;
}

- (id)initWithAxialShadingFromPoint:(NSPoint)startPoint
			    toPoint:(NSPoint)endPoint
			 withColors:(CSShadingColorArray)colors
			      flags:(unsigned)flags
{
  if ((self = [self initWithAxialShadingFromPoint:startPoint
					  toPoint:endPoint
				       colorSpace:[CSColorSpace genericRGBColorSpace]
					    flags:flags
					 function:shadeFromColorArray
					  context:NULL])) {
    functionContext = generateColorArray (&colors);
    
    if (!functionContext) {
      [self release];
      return nil;
    }
    
    freeFunctionContext = YES;
  }
  
  return self;
}

- (id)initWithRadialShadingFromPoint:(NSPoint)startPoint
			      radius:(float)r1
			     toPoint:(NSPoint)endPoint
			      radius:(float)r2
			  withColors:(CSShadingColorArray)colors
			       flags:(unsigned)flags
{
  if ((self = [self initWithRadialShadingFromPoint:(NSPoint)startPoint
					    radius:r1
					   toPoint:endPoint
					    radius:r2
					colorSpace:[CSColorSpace genericRGBColorSpace]
					     flags:flags
					  function:shadeFromColorArray
					   context:NULL])) {
    functionContext = generateColorArray (&colors);

    if (!functionContext) {
      [self release];
      return nil;
    }

    freeFunctionContext = YES;
  }
  
  return self;
}

- (void)dealloc
{
  CGShadingRelease (shading);
  CGFunctionRelease (function);

  if (freeFunctionContext)
    free (functionContext);

  [super dealloc];
}

- (void)draw
{
  CGContextRef cgContext = (CGContextRef)[[NSGraphicsContext currentContext]
    graphicsPort];

  CGContextDrawShading (cgContext, shading);
}

- (void)set
{
  [currentShading release];
  currentShading = [self retain];
}

@end

@implementation NSBezierPath (CSShadingSupport)

- (void)shade
{
  NSGraphicsContext *context = [NSGraphicsContext currentContext];
  
  [context saveGraphicsState];
  [self addClip];
  [currentShading draw];
  [context restoreGraphicsState];
}

@end
