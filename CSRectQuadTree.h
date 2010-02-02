//
//  CSRectQuadTree.h
//  CSIconView
//
//  Created by Alastair Houghton on 30/08/2005.
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

@interface CSRectQuadTree : NSObject
{
  NSRect bounds;
  struct quad_tree_node *head;
}

+ (CSRectQuadTree *)quadTreeWithBounds:(NSRect)bounds;

- (id)initWithBounds:(NSRect)bounds;

- (NSRect)bounds;
- (void)setBounds:(NSRect)bounds;
- (void)resizeBoundsForRect:(NSRect)size;

- (NSRect)objectBounds;

- (void)addObject:(id)obj withBounds:(NSRect)rect;
- (id)objectAtPoint:(NSPoint)point;
- (NSMutableSet *)objectsAtPoint:(NSPoint)point;
- (NSMutableSet *)objectsInRect:(NSRect)rect;
- (NSMutableSet *)objectsIntersectingRect:(NSRect)rect;
- (NSMutableSet *)objectsIntersectingRectBoundary:(NSRect)rect;

- (void)removeObject:(id)object;
- (void)removeObject:(id)object inRect:(NSRect)rectHint;
- (void)removeObject:(id)object withBounds:(NSRect)bounds;

- (void)removeAllObjects;

- (void)stroke;

- (NSMutableSet *)allObjects;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
