//
//  CSIcon.h
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

#import <Cocoa/Cocoa.h>

extern NSString * const kCSNormalIconVariant;
extern NSString * const kCSTiledIconVariant;
extern NSString * const kCSRolloverIconVariant;
extern NSString * const kCSDropIconVariant;
extern NSString * const kCSOpenIconVariant;
extern NSString * const kCSOpenDropIconVariant;

/* If you are looking for a list of the available standard icons, it is in
   
   <HIServices/Icons.h>

   You can get there quickly from Xcode's "Open Quickly..." option. */

@interface CSIcon : NSObject
{
  NSMutableDictionary *variants;
  NSMutableSet        *cachedReps;
  NSString	      *name;
}

+ (CSIcon *)iconNamed:(NSString *)name;

+ (CSIcon *)icon;
+ (CSIcon *)iconWithIconFamily:(IconFamilyHandle)handle;
+ (CSIcon *)iconWithContentsOfFile:(NSString *)filename;
+ (CSIcon *)iconWithContentsOfURL:(NSURL *)url;
+ (CSIcon *)iconWithStandardIcon:(OSType)icon;

- (id)init;
- (id)initWithIconFamily:(IconFamilyHandle)handle;
- (id)initWithContentsOfFile:(NSString *)filename;
- (id)initWithContentsOfURL:(NSURL *)url;
- (id)initWithStandardIcon:(OSType)icon;

- (void)setName:(NSString *)name;
- (NSString *)name;

- (NSImage *)imageForVariant:(NSString *)variant;
- (void)setImage:(NSImage *)image forVariant:(NSString *)variant;

- (void)drawVariant:(NSString *)variant inRect:(NSRect)rect
	  operation:(NSCompositingOperation)operation
	   fraction:(float)fraction;
- (void)drawInRect:(NSRect)rect
	 operation:(NSCompositingOperation)operation
	  fraction:(float)fraction;

- (BOOL)variant:(NSString*)variant wouldIntersectRect:(NSRect)rect
  ifDrawnInRect:(NSRect)drawRect;

- (NSArray *)availableVariants;

- (void)setImagesFromIconFamily:(IconFamilyHandle)handle;
- (void)setImagesFromIconFamilyResource:(const IconFamilyResource *)resource;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
