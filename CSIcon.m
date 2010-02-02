//
//  CSIcon.m
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

#import "CSIcon.h"
#import "NSBitmapImageRep+CSIconViewExtras.h"
#import "libkern/OSByteOrder.h"

NSString * const kCSNormalIconVariant = @"Normal";
NSString * const kCSTiledIconVariant = @"Tiled";
NSString * const kCSRolloverIconVariant = @"Rollover";
NSString * const kCSDropIconVariant = @"Drop";
NSString * const kCSOpenIconVariant = @"Open";
NSString * const kCSOpenDropIconVariant = @"OpenDrop";

static const IconFamilyElement *findElement (Size containerSize,
					     const IconFamilyElement *firstElement,
					     OSType elementType);
static const unsigned char *dataForElement (Size		  containerSize,
					    const IconFamilyElement *firstElement,
					    OSType		  elementType);
static NSBitmapImageRep *imageRepFromData (Size containerSize,
					   const IconFamilyElement *firstElement,
					   const void *data,
					   OSType dataType,
					   Size dataSize);
static void convert1BitImageWithMask (unsigned char *output,
				      unsigned width, unsigned height,
				      const unsigned char *data,
				      const unsigned char *mask);
static void convert4BitImageWithMask (unsigned char *output,
				      unsigned width, unsigned height,
				      const unsigned char *data,
				      const unsigned char *mask,
				      unsigned maskDepth);
static void convert8BitImageWithMask (unsigned char *output,
				      unsigned width, unsigned height,
				      const unsigned char *data,
				      const unsigned char *mask,
				      unsigned maskDepth);
static void convert24BitImageWithMask (unsigned char *output,
				       unsigned width, unsigned height,
				       const unsigned char *data,
				       const unsigned char *mask,
				       unsigned maskDepth,
				       unsigned dataLen);
static void convert32BitImage (unsigned char *output,
			       unsigned width, unsigned height,
			       const unsigned char *data);
static void decompress (unsigned char *output,
			const unsigned char *data,
			unsigned size);

@implementation CSIcon

static NSMutableDictionary *namedIcons;

+ (void)initialize
{
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *iconFile = [mainBundle objectForInfoDictionaryKey:
    @"CFBundleIconFile"];
  NSString *mainIconPath;
  CSIcon *mainIcon = nil;
  
  if (!iconFile) {
    mainIconPath = @"/System/Library/CoreServices/"
    @"CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns";
  } else
    mainIconPath = [mainBundle pathForResource:iconFile ofType:@"icns"];
  
  namedIcons = [[NSMutableDictionary alloc] init];
  
  if (mainIconPath)
    mainIcon = [CSIcon iconWithContentsOfFile:mainIconPath];
  
  if (mainIcon)
    [mainIcon setName:@"NSApplicationIcon"];
}

+ (CSIcon *)iconNamed:(NSString *)name
{
  CSIcon *icon = [namedIcons objectForKey:name];
  
  if (!icon) {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *iconPath = [mainBundle pathForResource:name ofType:@"icns"];
    icon = [CSIcon iconWithContentsOfFile:iconPath];
    [icon setName:name];
  }
  
  return icon;
}

+ (CSIcon *)icon
{
  return [[[CSIcon alloc] init] autorelease];
}

+ (CSIcon *)iconWithIconFamily:(IconFamilyHandle)handle
{
  return [[[CSIcon alloc] initWithIconFamily:handle] autorelease];
}

+ (CSIcon *)iconWithContentsOfFile:(NSString *)filename
{
  return [[[CSIcon alloc] initWithContentsOfFile:filename] autorelease];
}

+ (CSIcon *)iconWithContentsOfURL:(NSURL *)url
{
  return [[[CSIcon alloc] initWithContentsOfURL:url] autorelease];
}

+ (CSIcon *)iconWithStandardIcon:(OSType)icon
{
  return [[[CSIcon alloc] initWithStandardIcon:icon] autorelease];
}

- (id)init
{
  if ((self = [super init])) {
    variants = [[NSMutableDictionary alloc] init];
    cachedReps = [[NSMutableSet alloc] init];
  }
  
  return self;
}

- (id)initWithIconFamily:(IconFamilyHandle)handle
{
  if ((self = [self init])) {
    [self setImagesFromIconFamily:handle];
  }
  
  return self;
}

- (id)initWithStandardIcon:(OSType)icon
{
  if ((self = [self init])) {
    OSStatus err;
    IconRef iconRef;

    err = GetIconRef (kOnSystemDisk, kSystemIconsCreator, icon, &iconRef);

    if (err != noErr) {
      [self release];
      return nil;
    }

    IconFamilyHandle family;

    err = IconRefToIconFamily (iconRef, kSelectorAllAvailableData, &family);
    ReleaseIconRef (iconRef);

    if (err != noErr || !family) {
      [self release];
      return nil;
    }

    [self setImagesFromIconFamily:family];

    DisposeHandle ((Handle)family);
  }

  return self;
}

- (id)initWithContentsOfFile:(NSString *)filename
{
  if ((self = [self init])) {
    if ([filename hasSuffix:@".icns"]) {
      NSData *data = [NSData dataWithContentsOfFile:filename];
      
      [self setImagesFromIconFamilyResource:(IconFamilyResource *)[data bytes]];
    } else {
      NSImage *image = [[[NSImage alloc] initWithContentsOfFile:filename]
	autorelease];
      
      [variants setObject:image forKey:kCSNormalIconVariant];
    }
  }
  
  return self;
}

- (id)initWithContentsOfURL:(NSURL *)url
{
  if ((self = [self init])) {
    if ([[url absoluteString] hasSuffix:@".icns"]) {
      NSData *data = [NSData dataWithContentsOfURL:url];
      
      [self setImagesFromIconFamilyResource:(IconFamilyResource *)[data bytes]];
    } else {
      NSImage *image = [[[NSImage alloc] initWithContentsOfURL:url]
	autorelease];
      
      [variants setObject:image forKey:kCSNormalIconVariant];
    }
  }
  
  return self;
}

- (void)dealloc
{
  [variants release];
  [cachedReps release];
  [super dealloc];
}

- (void)setName:(NSString *)newName
{
  if (newName != name) {
    NSString *oldName = name;
    name = [newName copy];
    if (oldName)
      [namedIcons removeObjectForKey:oldName];
    [oldName release];
    [namedIcons setObject:self forKey:newName];
  }
}

- (NSString *)name
{
  return name;
}

- (NSImage *)imageForVariant:(NSString *)variant
{
  return [variants objectForKey:variant];
}

- (void)setImage:(NSImage *)newImage forVariant:(NSString *)variant
{
  [variants setObject:newImage forKey:variant];
}

- (NSArray *)availableVariants
{
  return [variants allKeys];
}

/* Given an icon family, extract 32-bit images for each supported size.
   Note that the NSImages created will *only* contain 32-bit RGBA images,
   not any other format, although these images may be generated from e.g.
   a 4-bit image with a 1-bit mask if that is all that is present.

   Note that the constants whose names end in 1BitMask don't actually identify
   a 1-bit mask at all; in fact, they represent a 1-bit icon *with* a 1-bit
   mask, which is why they are in the sizes[][] array below. */
- (void)setImagesFromIconFamilyResource:(const IconFamilyResource *)resource
{
  NSImage *baseImage = [[[NSImage alloc] init] autorelease];
  OSType sizes[6][4] = {
    { kIconServices256PixelDataARGB, 0, 0, 0 },
    { kThumbnail32BitData, 0, 0, 0 },
    { kHuge32BitData, kHuge8BitData, kHuge4BitData, kHuge1BitMask }, 
    { kLarge32BitData, kLarge8BitData, kLarge4BitData, kLarge1BitMask },
    { kSmall32BitData, kSmall8BitData, kSmall4BitData, kSmall1BitMask },
    { kMini8BitData, kMini4BitData, kMini1BitMask, 0 }
  };
  OSType variantTypes[5] = {
    kTileIconVariant,
    kRolloverIconVariant,
    kDropIconVariant,
    kOpenIconVariant,
    kOpenDropIconVariant
  };
  NSString *variantKeys[5] = {
    kCSTiledIconVariant,
    kCSRolloverIconVariant,
    kCSDropIconVariant,
    kCSOpenIconVariant,
    kCSOpenDropIconVariant
  };
  Size resourceSize;
  unsigned size, variant, n;

  [baseImage setFlipped:YES];
  [variants setObject:baseImage forKey:kCSNormalIconVariant];
  
  resourceSize = OSSwapBigToHostInt32 (resource->resourceSize);
  for (size = 0; size < 6; ++size) {
    for (n = 0; n < 3 && sizes[size][n]; ++n) {
      const IconFamilyElement *element = findElement (resourceSize,
						      resource->elements,
						      sizes[size][n]);

      if (element) {
	NSBitmapImageRep *rep;
        Size elementSize = OSSwapBigToHostInt32 (element->elementSize);
        OSType elementType = OSSwapBigToHostInt32 (element->elementType);
	
	rep = imageRepFromData (resourceSize,
				resource->elements,
				element->elementData,
				elementType,
				elementSize - 8);
	
	if (rep) {
	  [baseImage addRepresentation:rep];
	  break;
	}
      }
    }
  }
  
  for (variant = 0; variant < 5; ++variant) {
    const IconFamilyElement *variantElement = findElement (resourceSize,
							   resource->elements,
							   variantTypes[variant]);
    IconFamilyElement *elements
      = (IconFamilyElement *)variantElement->elementData;
    Size variantSize;
    NSImage *variantImage;
    
    if (!variantElement)
      continue;
    
    variantSize = OSSwapBigToHostInt32 (variantElement->elementSize);
    variantImage = [[[NSImage alloc] init] autorelease];
    [variantImage setFlipped:YES];
    [variants setObject:variantImage forKey:variantKeys[variant]];
    
    for (size = 0; size < 6; ++size) {
      for (n = 0; n < 3 && sizes[size][n]; ++n) {
	const IconFamilyElement *element = findElement (variantSize,
							elements,
							sizes[size][n]);
	
	if (element) {
	  NSBitmapImageRep *rep;
          Size elementSize = OSSwapBigToHostInt32 (element->elementSize);
          OSType elementType = OSSwapBigToHostInt32 (element->elementType);

	  rep = imageRepFromData (variantSize,
				  elements,
				  element->elementData,
				  elementType,
				  elementSize - 8);
	  
	  if (rep) {
	    [variantImage addRepresentation:rep];
	    break;
	  }
	}
      }
    } 
  }  
}

- (void)setImagesFromIconFamily:(IconFamilyHandle)handle
{
  HLock ((Handle)handle);
  
  [self setImagesFromIconFamilyResource:*handle];
  
  HUnlock ((Handle)handle);
}

- (BOOL)variant:(NSString*)variant wouldIntersectRect:(NSRect)intersectRect
  ifDrawnInRect:(NSRect)rect
{
  NSImage *image = [variants objectForKey:variant];
  NSBitmapImageRep *rep, *bestRep = nil;
  NSArray *reps;
  NSEnumerator *repEnum;
  NSSize bestSize = NSMakeSize (0.0f, 0.0f);
  
  if (!image) {
    if (variant == kCSDropIconVariant || variant == kCSOpenIconVariant) {
      image = [variants objectForKey:kCSOpenDropIconVariant];
    }
    
    if (!image)
      image = [variants objectForKey:kCSNormalIconVariant];
  }
  
  reps = [image representations];
  repEnum = [reps objectEnumerator];

  while ((rep = [repEnum nextObject])) {
    NSSize size = [rep size];
    
    if ([rep class] != [NSBitmapImageRep class])
      continue;
    
    if (NSEqualSizes (rect.size, size)) {
      bestRep = rep;
      bestSize = size;
      break;
    }
    
    if ((size.width > bestSize.width
	 && size.height > bestSize.height)
	|| (size.width * size.height) > (bestSize.width * bestSize.height)) {
      bestSize = size;
      bestRep = rep;
    }
  }
  
  intersectRect.origin.x -= rect.origin.x;
  intersectRect.origin.y -= rect.origin.y;
  
  if (bestSize.width != rect.size.width
      || bestSize.height != rect.size.height) {
    float xScale = bestSize.width / rect.size.width;
    float yScale = bestSize.height / rect.size.height;
    
    intersectRect.origin.x *= xScale;
    intersectRect.size.width *= xScale;
    intersectRect.origin.y *= yScale;
    intersectRect.size.height *= yScale;
  }
  
  return [bestRep rectIntersectsWithImage:intersectRect 
		       withAlphaThreshold:0.1f];
}

- (void)drawVariant:(NSString *)variant inRect:(NSRect)rect
	  operation:(NSCompositingOperation)operation
	   fraction:(float)fraction
{
  NSImage *image = [variants objectForKey:variant];
  
  if (!image) {
    if (variant == kCSDropIconVariant || variant == kCSOpenIconVariant) {
      image = [variants objectForKey:kCSOpenDropIconVariant];
    }
    
    if (!image)
      image = [variants objectForKey:kCSNormalIconVariant];
  }
  
  [image drawInRect:rect
           fromRect:NSZeroRect
          operation:operation
           fraction:fraction];
}

- (void)drawInRect:(NSRect)rect
	 operation:(NSCompositingOperation)operation
	  fraction:(float)fraction
{
  [self drawVariant:kCSNormalIconVariant inRect:rect
	  operation:operation fraction:fraction];
}

@end

static const IconFamilyElement *
findElement (Size containerSize,
	     const IconFamilyElement *firstElement,
	     OSType elementType)
{
  Size size = 8;
  Size elementSize;
  const IconFamilyElement *element;
  OSType swappedType = OSSwapBigToHostInt32 (elementType);

  for (size = 8, element = firstElement;
       size < containerSize;
       size += elementSize,
       element = (IconFamilyElement *)(element->elementData
				       + elementSize
                                       - 8)) {

    elementSize = OSSwapBigToHostInt32 (element->elementSize);

    if (element->elementType == swappedType)
      return element;
  }
  
  return NULL;
}

static const unsigned char *
dataForElement (Size		  containerSize,
		const IconFamilyElement *firstElement,
		OSType		  elementType)
{
  const IconFamilyElement *element 
    = findElement (containerSize, firstElement, elementType);
  
  if (element)
    return element->elementData;
  
  return NULL;
}

static NSBitmapImageRep *
imageRepFromData (Size containerSize,
		  const IconFamilyElement *firstElement,
		  const void *data,
		  OSType dataType,
		  Size dataSize)
{
  const void *mask = NULL;
  unsigned width, height;
  unsigned maskDepth;
  unsigned imageDepth = 0;
  NSBitmapImageRep *newRep;
  unsigned char *output;
  
  switch (dataType) {
    case kIconServices256PixelDataARGB:
      mask = NULL;
      maskDepth = 0;
      imageDepth = 32;
      width = height = 256;
      break;
    case kThumbnail32BitData:
      mask = dataForElement (containerSize, firstElement, kThumbnail8BitMask);
      maskDepth = 8;
      width = height = 128;
      imageDepth = 24;
      data = (void *)((char *)data + 4);
      break;
    case kHuge32BitData:
      mask = dataForElement (containerSize, firstElement, kHuge8BitMask);
      maskDepth = 8;
      width = height = 48;
      imageDepth = 24;
      if (mask)
	break;
    case kHuge4BitData:
      if (!imageDepth)
	imageDepth = 4;
    case kHuge8BitData:
      if (!imageDepth)
	imageDepth = 8;
      mask = dataForElement (containerSize, firstElement, kHuge1BitMask) + 288;
      maskDepth = 1;
      width = height = 48;
      break;
    case kHuge1BitMask:
      mask = (unsigned char *)data + 288;
      maskDepth = 1;
      width = height = 48;
      imageDepth = 1;
      dataSize /= 2;
      break;
    case kLarge32BitData:
      mask = dataForElement (containerSize, firstElement, kLarge8BitMask);
      maskDepth = 8;
      width = height = 32;
      imageDepth = 24;
      if (mask)
	break;
    case kLarge4BitData:
      if (!imageDepth)
	imageDepth = 4;
    case kLarge8BitData:
      if (!imageDepth)
	imageDepth = 8;
      mask = dataForElement (containerSize, firstElement, kLarge1BitMask) + 128;
      maskDepth = 1;
      width = height = 32;
      break;
    case kLarge1BitMask:
      mask = (unsigned char *)data + 128;
      maskDepth = 1;
      width = height = 32;
      imageDepth = 1;
      dataSize /= 2;
      break;
    case kSmall32BitData:
      mask = dataForElement (containerSize, firstElement, kSmall8BitMask);
      maskDepth = 8;
      width = height = 16;
      imageDepth = 24;
      if (mask)
	break;
    case kSmall4BitData:
      if (!imageDepth)
	imageDepth = 4;
    case kSmall8BitData:
      if (!imageDepth)
	imageDepth = 8;
      mask = dataForElement (containerSize, firstElement, kSmall1BitMask) + 32;
      maskDepth = 1;
      width = height = 16;
      break;
    case kSmall1BitMask:
      mask = (unsigned char *)data + 32;
      maskDepth = 1;
      width = height = 16;
      imageDepth = 1;
      dataSize /= 2;
      break;
    case kMini4BitData:
      imageDepth = 4;
    case kMini8BitData:
      if (!imageDepth)
	imageDepth = 8;
      mask = dataForElement (containerSize, firstElement, kMini1BitMask) + 24;
      maskDepth = 1;
      width = 16;
      height = 12;
      break;
    case kMini1BitMask:
      mask = (unsigned char *)data + 24;
      maskDepth = 1;
      width = 16;
      height = 12;
      imageDepth = 1;
      dataSize /= 2;
      break;
      
    default:
      return nil;
  }
  
  newRep = [[[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes:NULL
		  pixelsWide:width
		  pixelsHigh:height
	       bitsPerSample:8
	     samplesPerPixel:4
		    hasAlpha:YES
		    isPlanar:NO
	      colorSpaceName:NSCalibratedRGBColorSpace
		 bytesPerRow:width * 4
		bitsPerPixel:32] autorelease];
  
  if (!newRep)
    return nil;

  output = [newRep bitmapData];
  
  switch (imageDepth) {
    case 1:
      convert1BitImageWithMask (output, width, height,
				(const unsigned char *)data,
				(const unsigned char *)mask);
      break;
    case 4:
      convert4BitImageWithMask (output, width, height,
				(const unsigned char *)data,
				(const unsigned char *)mask, maskDepth);
      break;
    case 8:
      convert8BitImageWithMask (output, width, height, 
				(const unsigned char *)data,
				(const unsigned char *)mask, maskDepth);
      break;
    case 24:
      convert24BitImageWithMask (output, width, height,
				 (const unsigned char *)data,
				 (const unsigned char *)mask, maskDepth,
				 dataSize);
      break;
    case 32:
      convert32BitImage (output, width, height, (const unsigned char *)data);
      break;
  }

  return newRep;
}

/* Converts a 1-bit (black & white) image with a mask into a 32-bit RGBA
   image */
static void
convert1BitImageWithMask (unsigned char *output,
			  unsigned width, unsigned height,
			  const unsigned char *data,
			  const unsigned char *mask)
{
  unsigned x, y;
  
  for (y = 0; y < height; ++y) {
    unsigned char *row = output + y * ((width + 7) / 8);
    const unsigned char *maskRow = mask + y * ((width + 7) / 8);
    
    for (x = 0; x < width; ++x) {
      unsigned char color = (row[x / 8] & (0x80 >> (x & 7))) ? 0x00 : 0xff;
      unsigned char mask = (maskRow[x / 8] & (0x80 >> (x & 7))) ? 0xff : 0x00;
      
      *output++ = color & mask;
      *output++ = color & mask;
      *output++ = color & mask;
      *output++ = mask;
    }
  }
  
}

/* Converts a 4-bit (16 color) image with a mask into a 32-bit RGBA image */
static void
convert4BitImageWithMask (unsigned char *output,
			  unsigned width, unsigned height,
			  const unsigned char *data,
			  const unsigned char *mask,
			  unsigned maskDepth)
{
  unsigned x, y;
  static const unsigned char colors[16][3] = {
    { 0xff, 0xff, 0xff }, { 0xfc, 0xf3, 0x05 }, { 0xff, 0x64, 0x02 },
    { 0xdd, 0x08, 0x06 }, { 0xf2, 0x08, 0x84 }, { 0x46, 0x00, 0xa5 },
    { 0x00, 0x00, 0xd4 }, { 0x02, 0xab, 0xea }, { 0x1f, 0xb7, 0x14 },
    { 0x00, 0x64, 0x11 }, { 0x56, 0x2c, 0x05 }, { 0x90, 0x71, 0x3a },
    { 0xc0, 0xc0, 0xc0 }, { 0x80, 0x80, 0x80 }, { 0x40, 0x40, 0x40 },
    { 0x00, 0x00, 0x00 }
  };
  
  for (y = 0; y < height; ++y) {
    unsigned char *row = output + y * ((width + 1) / 2);
    const unsigned char *maskRow;
    
    if (maskDepth == 1)
      maskRow = mask + y * ((width + 7) / 8);
    else
      maskRow = mask + y * width;
    
    for (x = 0; x < width; ++x) {
      unsigned color = (row[x / 2] >> (4 * (1 - (x & 1)))) & 0xf;
      unsigned char mask;
      
      if (maskDepth == 8)
	mask = *maskRow++;
      else
	mask = (maskRow[x / 8] & (0x80 >> (x & 7))) ? 0xff : 0x00;
      
      *output++ = (colors[color][0] * mask) / 255;
      *output++ = (colors[color][1] * mask) / 255;
      *output++ = (colors[color][2] * mask) / 255;
      *output++ = mask;
    }
  }
}

/* Converts an 8-bit (256 color) image with a mask into a 32-bit RGBA image */
static void
convert8BitImageWithMask (unsigned char *output,
			  unsigned width, unsigned height,
			  const unsigned char *data,
			  const unsigned char *mask,
			  unsigned maskDepth)
{
  unsigned x, y;
  static const unsigned char colors[256][3] = {
    { 0xff, 0xff, 0xff }, { 0xff, 0xff, 0xcc }, { 0xff, 0xff, 0x99 }, 
    { 0xff, 0xff, 0x66 }, { 0xff, 0xff, 0x33 }, { 0xff, 0xff, 0x00 }, 
    { 0xff, 0xcc, 0xff }, { 0xff, 0xcc, 0xcc }, { 0xff, 0xcc, 0x99 }, 
    { 0xff, 0xcc, 0x66 }, { 0xff, 0xcc, 0x33 }, { 0xff, 0xcc, 0x00 }, 
    { 0xff, 0x99, 0xff }, { 0xff, 0x99, 0xcc }, { 0xff, 0x99, 0x99 }, 
    { 0xff, 0x99, 0x66 }, { 0xff, 0x99, 0x33 }, { 0xff, 0x99, 0x00 }, 
    { 0xff, 0x66, 0xff }, { 0xff, 0x66, 0xcc }, { 0xff, 0x66, 0x99 }, 
    { 0xff, 0x66, 0x66 }, { 0xff, 0x66, 0x33 }, { 0xff, 0x66, 0x00 }, 
    { 0xff, 0x33, 0xff }, { 0xff, 0x33, 0xcc }, { 0xff, 0x33, 0x99 }, 
    { 0xff, 0x33, 0x66 }, { 0xff, 0x33, 0x33 }, { 0xff, 0x33, 0x00 }, 
    { 0xff, 0x00, 0xff }, { 0xff, 0x00, 0xcc }, { 0xff, 0x00, 0x99 }, 
    { 0xff, 0x00, 0x66 }, { 0xff, 0x00, 0x33 }, { 0xff, 0x00, 0x00 }, 
    { 0xcc, 0xff, 0xff }, { 0xcc, 0xff, 0xcc }, { 0xcc, 0xff, 0x99 }, 
    { 0xcc, 0xff, 0x66 }, { 0xcc, 0xff, 0x33 }, { 0xcc, 0xff, 0x00 }, 
    { 0xcc, 0xcc, 0xff }, { 0xcc, 0xcc, 0xcc }, { 0xcc, 0xcc, 0x99 }, 
    { 0xcc, 0xcc, 0x66 }, { 0xcc, 0xcc, 0x33 }, { 0xcc, 0xcc, 0x00 }, 
    { 0xcc, 0x99, 0xff }, { 0xcc, 0x99, 0xcc }, { 0xcc, 0x99, 0x99 }, 
    { 0xcc, 0x99, 0x66 }, { 0xcc, 0x99, 0x33 }, { 0xcc, 0x99, 0x00 }, 
    { 0xcc, 0x66, 0xff }, { 0xcc, 0x66, 0xcc }, { 0xcc, 0x66, 0x99 }, 
    { 0xcc, 0x66, 0x66 }, { 0xcc, 0x66, 0x33 }, { 0xcc, 0x66, 0x00 }, 
    { 0xcc, 0x33, 0xff }, { 0xcc, 0x33, 0xcc }, { 0xcc, 0x33, 0x99 }, 
    { 0xcc, 0x33, 0x66 }, { 0xcc, 0x33, 0x33 }, { 0xcc, 0x33, 0x00 }, 
    { 0xcc, 0x00, 0xff }, { 0xcc, 0x00, 0xcc }, { 0xcc, 0x00, 0x99 }, 
    { 0xcc, 0x00, 0x66 }, { 0xcc, 0x00, 0x33 }, { 0xcc, 0x00, 0x00 }, 
    { 0x99, 0xff, 0xff }, { 0x99, 0xff, 0xcc }, { 0x99, 0xff, 0x99 }, 
    { 0x99, 0xff, 0x66 }, { 0x99, 0xff, 0x33 }, { 0x99, 0xff, 0x00 }, 
    { 0x99, 0xcc, 0xff }, { 0x99, 0xcc, 0xcc }, { 0x99, 0xcc, 0x99 }, 
    { 0x99, 0xcc, 0x66 }, { 0x99, 0xcc, 0x33 }, { 0x99, 0xcc, 0x00 }, 
    { 0x99, 0x99, 0xff }, { 0x99, 0x99, 0xcc }, { 0x99, 0x99, 0x99 }, 
    { 0x99, 0x99, 0x66 }, { 0x99, 0x99, 0x33 }, { 0x99, 0x99, 0x00 }, 
    { 0x99, 0x66, 0xff }, { 0x99, 0x66, 0xcc }, { 0x99, 0x66, 0x99 }, 
    { 0x99, 0x66, 0x66 }, { 0x99, 0x66, 0x33 }, { 0x99, 0x66, 0x00 }, 
    { 0x99, 0x33, 0xff }, { 0x99, 0x33, 0xcc }, { 0x99, 0x33, 0x99 }, 
    { 0x99, 0x33, 0x66 }, { 0x99, 0x33, 0x33 }, { 0x99, 0x33, 0x00 }, 
    { 0x99, 0x00, 0xff }, { 0x99, 0x00, 0xcc }, { 0x99, 0x00, 0x99 }, 
    { 0x99, 0x00, 0x66 }, { 0x99, 0x00, 0x33 }, { 0x99, 0x00, 0x00 }, 
    { 0x66, 0xff, 0xff }, { 0x66, 0xff, 0xcc }, { 0x66, 0xff, 0x99 }, 
    { 0x66, 0xff, 0x66 }, { 0x66, 0xff, 0x33 }, { 0x66, 0xff, 0x00 }, 
    { 0x66, 0xcc, 0xff }, { 0x66, 0xcc, 0xcc }, { 0x66, 0xcc, 0x99 }, 
    { 0x66, 0xcc, 0x66 }, { 0x66, 0xcc, 0x33 }, { 0x66, 0xcc, 0x00 }, 
    { 0x66, 0x99, 0xff }, { 0x66, 0x99, 0xcc }, { 0x66, 0x99, 0x99 }, 
    { 0x66, 0x99, 0x66 }, { 0x66, 0x99, 0x33 }, { 0x66, 0x99, 0x00 }, 
    { 0x66, 0x66, 0xff }, { 0x66, 0x66, 0xcc }, { 0x66, 0x66, 0x99 }, 
    { 0x66, 0x66, 0x66 }, { 0x66, 0x66, 0x33 }, { 0x66, 0x66, 0x00 }, 
    { 0x66, 0x33, 0xff }, { 0x66, 0x33, 0xcc }, { 0x66, 0x33, 0x99 }, 
    { 0x66, 0x33, 0x66 }, { 0x66, 0x33, 0x33 }, { 0x66, 0x33, 0x00 }, 
    { 0x66, 0x00, 0xff }, { 0x66, 0x00, 0xcc }, { 0x66, 0x00, 0x99 }, 
    { 0x66, 0x00, 0x66 }, { 0x66, 0x00, 0x33 }, { 0x66, 0x00, 0x00 }, 
    { 0x33, 0xff, 0xff }, { 0x33, 0xff, 0xcc }, { 0x33, 0xff, 0x99 }, 
    { 0x33, 0xff, 0x66 }, { 0x33, 0xff, 0x33 }, { 0x33, 0xff, 0x00 }, 
    { 0x33, 0xcc, 0xff }, { 0x33, 0xcc, 0xcc }, { 0x33, 0xcc, 0x99 }, 
    { 0x33, 0xcc, 0x66 }, { 0x33, 0xcc, 0x33 }, { 0x33, 0xcc, 0x00 }, 
    { 0x33, 0x99, 0xff }, { 0x33, 0x99, 0xcc }, { 0x33, 0x99, 0x99 }, 
    { 0x33, 0x99, 0x66 }, { 0x33, 0x99, 0x33 }, { 0x33, 0x99, 0x00 }, 
    { 0x33, 0x66, 0xff }, { 0x33, 0x66, 0xcc }, { 0x33, 0x66, 0x99 }, 
    { 0x33, 0x66, 0x66 }, { 0x33, 0x66, 0x33 }, { 0x33, 0x66, 0x00 }, 
    { 0x33, 0x33, 0xff }, { 0x33, 0x33, 0xcc }, { 0x33, 0x33, 0x99 }, 
    { 0x33, 0x33, 0x66 }, { 0x33, 0x33, 0x33 }, { 0x33, 0x33, 0x00 }, 
    { 0x33, 0x00, 0xff }, { 0x33, 0x00, 0xcc }, { 0x33, 0x00, 0x99 }, 
    { 0x33, 0x00, 0x66 }, { 0x33, 0x00, 0x33 }, { 0x33, 0x00, 0x00 }, 
    { 0x00, 0xff, 0xff }, { 0x00, 0xff, 0xcc }, { 0x00, 0xff, 0x99 }, 
    { 0x00, 0xff, 0x66 }, { 0x00, 0xff, 0x33 }, { 0x00, 0xff, 0x00 }, 
    { 0x00, 0xcc, 0xff }, { 0x00, 0xcc, 0xcc }, { 0x00, 0xcc, 0x99 }, 
    { 0x00, 0xcc, 0x66 }, { 0x00, 0xcc, 0x33 }, { 0x00, 0xcc, 0x00 }, 
    { 0x00, 0x99, 0xff }, { 0x00, 0x99, 0xcc }, { 0x00, 0x99, 0x99 }, 
    { 0x00, 0x99, 0x66 }, { 0x00, 0x99, 0x33 }, { 0x00, 0x99, 0x00 }, 
    { 0x00, 0x66, 0xff }, { 0x00, 0x66, 0xcc }, { 0x00, 0x66, 0x99 }, 
    { 0x00, 0x66, 0x66 }, { 0x00, 0x66, 0x33 }, { 0x00, 0x66, 0x00 }, 
    { 0x00, 0x33, 0xff }, { 0x00, 0x33, 0xcc }, { 0x00, 0x33, 0x99 }, 
    { 0x00, 0x33, 0x66 }, { 0x00, 0x33, 0x33 }, { 0x00, 0x33, 0x00 }, 
    { 0x00, 0x00, 0xff }, { 0x00, 0x00, 0xcc }, { 0x00, 0x00, 0x99 }, 
    { 0x00, 0x00, 0x66 }, { 0x00, 0x00, 0x33 }, { 0xee, 0x00, 0x00 }, 
    { 0xdd, 0x00, 0x00 }, { 0xbb, 0x00, 0x00 }, { 0xaa, 0x00, 0x00 }, 
    { 0x88, 0x00, 0x00 }, { 0x77, 0x00, 0x00 }, { 0x55, 0x00, 0x00 }, 
    { 0x44, 0x00, 0x00 }, { 0x22, 0x00, 0x00 }, { 0x11, 0x00, 0x00 }, 
    { 0x00, 0xee, 0x00 }, { 0x00, 0xdd, 0x00 }, { 0x00, 0xbb, 0x00 }, 
    { 0x00, 0xaa, 0x00 }, { 0x00, 0x88, 0x00 }, { 0x00, 0x77, 0x00 }, 
    { 0x00, 0x55, 0x00 }, { 0x00, 0x44, 0x00 }, { 0x00, 0x22, 0x00 }, 
    { 0x00, 0x11, 0x00 }, { 0x00, 0x00, 0xee }, { 0x00, 0x00, 0xdd }, 
    { 0x00, 0x00, 0xbb }, { 0x00, 0x00, 0xaa }, { 0x00, 0x00, 0x88 }, 
    { 0x00, 0x00, 0x77 }, { 0x00, 0x00, 0x55 }, { 0x00, 0x00, 0x44 }, 
    { 0x00, 0x00, 0x22 }, { 0x00, 0x00, 0x11 }, { 0xee, 0xee, 0xee }, 
    { 0xdd, 0xdd, 0xdd }, { 0xbb, 0xbb, 0xbb }, { 0xaa, 0xaa, 0xaa }, 
    { 0x88, 0x88, 0x88 }, { 0x77, 0x77, 0x77 }, { 0x55, 0x55, 0x55 }, 
    { 0x44, 0x44, 0x44 }, { 0x22, 0x22, 0x22 }, { 0x11, 0x11, 0x11 }, 
    { 0x00, 0x00, 0x00 }
  };
  
  for (y = 0; y < height; ++y) {
    unsigned char *row = output + y * width;
    const unsigned char *maskRow;
    
    if (maskDepth == 1)
      maskRow = mask + y * ((width + 7) / 8);
    else
      maskRow = mask + y * width;
    
    for (x = 0; x < width; ++x) {
      unsigned color = row[x];
      unsigned char mask;
      
      if (maskDepth == 8)
	mask = *maskRow++;
      else
	mask = (maskRow[x / 8] & (0x80 >> (x & 7))) ? 0xff : 0x00;
      
      *output++ = (colors[color][0] * mask) / 255;
      *output++ = (colors[color][1] * mask) / 255;
      *output++ = (colors[color][2] * mask) / 255;
      *output++ = mask;
    }
  }  
}

/* Decompress a PackBits compressed 24-bit image */
static void
decompress (unsigned char *output,
	    const unsigned char *data,
	    unsigned size)
{
  unsigned channel;
  
  for (channel = 1; channel < 4; ++channel) {
    unsigned char *ptr = output + channel;
    unsigned char *end = ptr + 4 * size;
    
    while (ptr < end) {
      unsigned char byte = *data++;
      
      if (byte & 0x80) {
	unsigned len = byte - 125;
	unsigned val = *data++;
	while (len-- && ptr < end) {
	  *ptr = val, ptr += 4;
	}
      } else {
	unsigned len = byte + 1;
	while (len-- && ptr < end) {
	  *ptr = *data++, ptr += 4;
	}
      }
    }
  }
}

/* Converts a 24-bit RGB image with a mask into a 32-bit RGBA image */
static void
convert24BitImageWithMask (unsigned char *output,
			   unsigned width, unsigned height,
			   const unsigned char *data,
			   const unsigned char *mask,
			   unsigned maskDepth,
			   unsigned dataLen)
{
  unsigned char *buffer;
  unsigned x, y;

  /* Check for compressed data, and decompress it */
  if (dataLen != width * height * 4) {
    unsigned size = width * height;
    
    buffer = (unsigned char *) malloc (size * 4);
    
    decompress (buffer, data, size);
    
    data = buffer;
  }
  
  for (y = 0; y < height; ++y) {
    const unsigned char *maskRow;
    
    if (maskDepth == 1)
      maskRow = mask + y * ((width + 7) / 8);
    else
      maskRow = mask + y * width;

    for (x = 0; x < width; ++x) {
      unsigned char mask;
      
      if (maskDepth == 8)
	mask = *maskRow++;
      else
	mask = (maskRow[x / 8] & (0x80 >> (x & 7))) ? 0xff : 0x00;

      ++data;
      *output++ = (*data++ * mask) / 255;
      *output++ = (*data++ * mask) / 255;
      *output++ = (*data++ * mask) / 255;
      *output++ = mask;
    }
  }
  
  if (dataLen != width * height * 4)
    free (buffer);
}

/* Converts ARGB to RGBA */
static void
convert32BitImage (unsigned char *output,
		   unsigned width, unsigned height,
		   const unsigned char *data)
{
  unsigned pixels;

  pixels = width * height;
  
  while (pixels--) {
    unsigned char a = *data++;
    
    *output++ = (*data++ * a) / 255;
    *output++ = (*data++ * a) / 255;
    *output++ = (*data++ * a) / 255;
    *output++ = a;
  }
}

