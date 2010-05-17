//
//  CSColorSpace.m
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

#import "CSColorSpace.h"

/*
extern CFStringRef kCGColorSpaceGenericGray __attribute__((weak_import));
extern CFStringRef kCGColorSpaceGenericRGB __attribute__((weak_import));
extern CFStringRef kCGColorSpaceGenericCMYK __attribute__((weak_import));
*/

@implementation CSColorSpace

+ (CSColorSpace *)deviceRGBColorSpace
{
  static CSColorSpace *deviceRGBColorSpace;
  
  if (!deviceRGBColorSpace) {
    deviceRGBColorSpace 
      = [[self alloc] initWithColorSpaceRef:CGColorSpaceCreateDeviceRGB ()];
  }
  
  return deviceRGBColorSpace;
}

+ (CSColorSpace *)deviceCMYKColorSpace
{
  static CSColorSpace *deviceCMYKColorSpace;
  
  if (!deviceCMYKColorSpace) {
    deviceCMYKColorSpace 
      = [[self alloc] initWithColorSpaceRef:CGColorSpaceCreateDeviceCMYK ()];
  }
  
  return deviceCMYKColorSpace;
}

+ (CSColorSpace *)deviceGrayColorSpace
{
  static CSColorSpace *deviceGrayColorSpace;
  
  if (!deviceGrayColorSpace) {
    deviceGrayColorSpace 
      = [[self alloc] initWithColorSpaceRef:CGColorSpaceCreateDeviceGray ()];
  }
  
  return deviceGrayColorSpace;
}

+ (CSColorSpace *)genericRGBColorSpace
{
  CFStringRef name;
  
  name = kCGColorSpaceGenericRGB;
  
  return [[[self alloc] initWithColorSpaceName:(NSString *)name]
    autorelease];
}

+ (CSColorSpace *)genericCMYKColorSpace
{
  CFStringRef name;
  
  name = kCGColorSpaceGenericCMYK;
  
  return [[[self alloc] initWithColorSpaceName:(NSString *)name]
    autorelease];
}

+ (CSColorSpace *)genericGrayColorSpace
{
  CFStringRef name;
  
  name = kCGColorSpaceGenericGray;
  
  return [[[self alloc] initWithColorSpaceName:(NSString *)name]
    autorelease];
}

- (id)initWithColorSpaceRef:(CGColorSpaceRef)colorSpaceRef
{
  if ((self = [super init])) {
    colorSpace = colorSpaceRef;
    if (!colorSpace) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithColorSpaceName:(NSString *)name
{
  return [self initWithColorSpaceRef:
    CGColorSpaceCreateWithName ((CFStringRef)name)];
}

- (void)dealloc
{
  CGColorSpaceRelease (colorSpace);
  [super dealloc];
}

- (unsigned)numberOfComponents
{
  return CGColorSpaceGetNumberOfComponents (colorSpace);
}

- (CGColorSpaceRef)cgColorSpaceRef
{
  return colorSpace;
}

@end
