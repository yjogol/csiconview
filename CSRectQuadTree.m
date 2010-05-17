//
//  CSRectQuadTree.m
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

#import "CSRectQuadTree.h"
#import "CSRectUtils.h"

#define DEBUG_NODE_ALLOCATION 0
#define DEBUG_NODE_ZOMBIES 0

#if DEBUG_NODE_ZOMBIES
# define CHECK_NODE(x) NSCAssert (x->used <= x->total, @"Oops!")
#else
# define CHECK_NODE(x) (void)0
#endif

/* A quad tree is structured like this:

      +--------+--------+
      |        |        |
      |   TL   |   TR   |
      |        |        |
      +--------+--------+
      |        |        |
      |   BL   |   BR   |
      |        |        |
      +--------+--------+

   Objects are placed into the quad tree according to the smallest node in
   which they can completely reside. */
struct quad_tree_object {
  NSRect   bounds;
  id	   object;
};

#define IS_RIGHT(box)	((box) & 1)
#define IS_LEFT(box)	(!IS_RIGHT(box))
#define IS_TOP(box)	((box) & 2)
#define IS_BOTTOM(box)	(!IS_TOP(box))

typedef enum {
  kNoBox	  = -1,
  // These are deliberately in this order so that the macros above work
  kBottomLeftBox  = 0,
  kBottomRightBox = 1,
  kTopLeftBox	  = 2,
  kTopRightBox	  = 3
} QuadTreeBox;

struct quad_tree_node {
  struct quad_tree_node	  *parent;
  union {
    struct {
      struct quad_tree_node *bl, *br, *tl, *tr; // Must be same order as above
    };
    struct quad_tree_node *boxes[4];
  };

  unsigned		  total, used;
  struct quad_tree_object objects[0];
};

static struct quad_tree_node *newNode (struct quad_tree_node *parent);
static struct quad_tree_node *addObjectToNode (struct quad_tree_node *node,
					       id object,
					       NSRect bounds);
static void releaseNode (struct quad_tree_node *node, BOOL recurse);
static struct quad_tree_node *splitForRect (struct quad_tree_node *head,
					    NSRect		  bounds,
					    NSRect		  objectRect);
static void addObjectsInRectToSet (NSMutableSet *set,
				   struct quad_tree_node *node,
				   NSRect bounds,
				   NSRect rect,
				   BOOL includeIntersectingObjects,
				   BOOL includeContainedObjects);
static struct quad_tree_node *findNodeForObject (struct quad_tree_node *node,
						 id			object,
						 unsigned		hash,
						 unsigned	       *index);
static struct quad_tree_node *
findNodeForObjectWithRect (struct quad_tree_node *node,
			   NSRect		 bounds,
			   id			 object,
			   unsigned		 hash,
			   NSRect		 rect,
			   BOOL			 rectIsHint,
			   unsigned	         *index);
static struct quad_tree_node *
removeObjectFromNode (struct quad_tree_node *node,
		      unsigned		    index);
static void strokeQuadTreeNodes (struct quad_tree_node *node,
				 NSRect		       bounds);
static void unionRectForAllNodes (struct quad_tree_node *node,
                                  NSRect                bounds,
                                  NSRect                *unionRect,
                                  BOOL                  *foundRect);

static NSRect boundsForBox (NSRect larger, QuadTreeBox box) __attribute__ ((__const__));
static int whichBox (NSRect larger, NSRect smaller) __attribute__ ((__const__));

static NSRect boundsForBox (NSRect larger, QuadTreeBox box)
{
  NSRect r;
  r.size = NSMakeSize (larger.size.width / 2, larger.size.height / 2);
  r.origin = NSMakePoint (larger.origin.x + (IS_RIGHT (box) ? r.size.width : 0),
			  larger.origin.y + (IS_TOP (box) ? r.size.height : 0));
  return r;
}

static int whichBox (NSRect larger, NSRect smaller)
{
  QuadTreeBox box;
  for (box = 0; box < 4; ++box) {
    NSRect bounds = boundsForBox (larger, box);
    if (CSContainsRect (bounds, smaller))
      return box;
  }
  return kNoBox;
}

@implementation CSRectQuadTree

+ (CSRectQuadTree *)quadTreeWithBounds:(NSRect)newBounds
{
  return [[[CSRectQuadTree alloc] initWithBounds:newBounds] autorelease];
}

- (id)init
{
  if ((self = [super init])) {
    head = newNode (NULL);
    bounds.size.width = bounds.size.height = 10.0f;
    
    if (!head) {
      [self release];
      self = nil;
    }
  }
  
  return self;
}

- (id)initWithBounds:(NSRect)newBounds
{
  if ((self = [self init])) {
    bounds = newBounds;
  }
  
  return self;
}

- (void)dealloc
{
  releaseNode (head, TRUE);
  [super dealloc];
}

- (NSRect)bounds
{
  return bounds;
}

- (void)setBounds:(NSRect)newBounds
{
  bounds = newBounds;
}

- (NSRect)objectBounds
{
  BOOL foundRect = NO;
  NSRect unionRect = NSZeroRect;

  unionRectForAllNodes (head, bounds, &unionRect, &foundRect);

  return unionRect;
}

- (void)resizeBoundsForRect:(NSRect)rect
{
  if (bounds.size.width <= 0)
    bounds.size.width = 1.0;
  if (bounds.size.height <= 0)
    bounds.size.height = 1.0;

  // Increase the size
  while (!CSContainsRect (bounds, rect)) {
    if (head->bl || head->br || head->tl || head->tr || head->used) {
      struct quad_tree_node *node = newNode (NULL);
      
      if (!node) {
	[NSException raise:@"CSOutOfMemory"
		    format:@"%@",
          NSLocalizedString (@"Not enough memory.",
                             @"Not enough memory.")];
      }
      
      head->parent = node;

      if (NSMinX (rect) >= NSMinX (bounds)) {
        if (NSMinY (rect) >= NSMinY (bounds))
          node->bl = head;
        else
          node->tl = head;
      } else {
        if (NSMinY (rect) >= NSMinY (bounds))
          node->br = head;
        else
          node->tr = head;
      }

      head = node;
    }

    if (NSMinX (rect) < NSMinX (bounds))
      bounds.origin.x -= bounds.size.width;
    if (NSMinY (rect) < NSMinY (bounds))
      bounds.origin.y -= bounds.size.height;
    
    bounds.size.width *= 2;
    bounds.size.height *= 2;
  }
  
  // Decrease the size
  while (!head->used) {
    QuadTreeBox box;
    struct quad_tree_node *node = NULL;
    
    for (box = 0; box < 4; ++box) {
      if (head->boxes[box]) {
	if (node)
	  return;
	node = head->boxes[box];
	if (!CSContainsRect (boundsForBox (bounds, box), rect))
	  return;
        break;
      }
    }
    
    if (node) {
      node->parent = NULL;
      releaseNode (head, NO);
      head = node;
      bounds = boundsForBox (bounds, box);
    } else {
      // Empty quad tree
      for (;;) {
	box = whichBox (bounds, rect);
	if (box == kNoBox)
	  return;
	bounds = boundsForBox (bounds, box);
      }
    }
  }
}

- (void)addObject:(id)obj
       withBounds:(NSRect)objectRect
{
  struct quad_tree_node *node;
  BOOL isHead;

  if (!CSContainsRect (bounds, objectRect)) {
    NSRect uRect = NSUnionRect (bounds, objectRect);
    
    [self resizeBoundsForRect:uRect];
  }
  
  node = splitForRect (head, bounds, objectRect);

  isHead = node == head;
  
  if (node)
    node = addObjectToNode (node, obj, objectRect);
  
  if (isHead)
    head = node;
  
  if (!node) {
    [NSException raise:@"CSOutOfMemory"
		format:@"%@",
      NSLocalizedString (@"Not enough memory.",
                         @"Not enough memory.")];
  }
}

- (id)objectAtPoint:(NSPoint)point
{
  struct quad_tree_node *node = head;
  NSRect rect = bounds;
  QuadTreeBox box;
  
  do {
    unsigned n;
    
    for (n = 0; n < node->used; ++n) {
      if (NSPointInRect (point, node->objects[n].bounds))
	return node->objects[n].object;
    }
    
    for (box = 0; box < 4; ++box) {
      NSRect boxBounds = boundsForBox (rect, box);
      if (NSPointInRect (point, boxBounds)) {
	node = node->boxes[box];
	if (!node)
	  return nil;
	rect = boxBounds;
	break;
      }
    }
  } while (box < 4);

  return nil;
}

- (NSMutableSet *)objectsAtPoint:(NSPoint)point
{
  struct quad_tree_node *node = head;
  NSMutableSet *set = [NSMutableSet set];
  NSRect rect = bounds;
  QuadTreeBox box;

  do {
    unsigned n;
    
    for (n = 0; n < node->used; ++n) {
      if (NSPointInRect (point, node->objects[n].bounds))
	[set addObject:node->objects[n].object];
    }
    
    for (box = 0; box < 4; ++box) {
      NSRect boxBounds = boundsForBox (rect, box);
      if (NSPointInRect (point, boxBounds)) {
	node = node->boxes[box];
	if (!node)
	  return set;
	rect = boxBounds;
	break;
      }
    }
  } while (box < 4);
  
  return set;
}

- (NSMutableSet *)objectsInRect:(NSRect)rect
{
  NSMutableSet *set = [NSMutableSet set];
  
  addObjectsInRectToSet (set, head, bounds, rect, NO, YES);
  
  return set;
}

- (NSMutableSet *)objectsIntersectingRect:(NSRect)rect
{
  NSMutableSet *set = [NSMutableSet set];
  
  addObjectsInRectToSet (set, head, bounds, rect, YES, YES);

  return set;
}

- (NSMutableSet *)objectsIntersectingRectBoundary:(NSRect)rect
{
  NSMutableSet *set = [NSMutableSet set];
  
  addObjectsInRectToSet (set, head, bounds, rect, YES, NO);
  
  return set;
}

- (void)removeObject:(id)object
{
  unsigned index = ~0u;
  struct quad_tree_node *node = findNodeForObject(head,
						  object,
						  [object hash],
						  &index);
  BOOL isHead = node == head;
  
  NSAssert (node, @"You can't remove an object that isn't in the tree.");
  
  node = removeObjectFromNode (node, index);
  
  if (isHead)
    head = node;
}

- (void)removeObject:(id)object inRect:(NSRect)rectHint
{
  unsigned index = ~0u;
  struct quad_tree_node *node = findNodeForObjectWithRect (head,
							   bounds,
							   object,
							   [object hash],
							   rectHint,
							   YES,
							   &index);
  BOOL isHead = node == head;

  NSAssert (node, @"You can't remove an object that isn't in the tree.");
  
  node = removeObjectFromNode (node, index);
  
  if (isHead)
    head = node;
}

- (void)removeObject:(id)object withBounds:(NSRect)objectBounds
{
  unsigned index;
  struct quad_tree_node *node = findNodeForObjectWithRect (head,
							   bounds,
							   object,
							   [object hash],
							   objectBounds,
							   NO,
							   &index);
  BOOL isHead = node == head;

  NSAssert (node, @"You can't remove an object that isn't in the tree.");
  
  node = removeObjectFromNode (node, index);
  
  if (isHead)
    head = node;
}

- (void)removeAllObjects
{
  unsigned n;
  
#if DEBUG_NODE_ALLOCATION
  NSLog (@"Removing all objects, head is %p (%p, %p, %p, %p)", head,
	 head->tl, head->tr, head->bl, head->br);
#endif
  
  if (head->tl) releaseNode (head->tl, TRUE);
  if (head->tr) releaseNode (head->tr, TRUE);
  if (head->bl) releaseNode (head->bl, TRUE);
  if (head->br) releaseNode (head->br, TRUE);

  for (n = 0; n < head->used; ++n)
    [head->objects[n].object release];
  
  head->used = 0;
}

- (void)stroke
{
  strokeQuadTreeNodes (head, bounds);
}

static void 
addObjectsInNodeToSet (NSMutableSet *set,
		       struct quad_tree_node *node)
{
  unsigned n;

  for (n = 0; n < node->used; ++n)
    [set addObject:node->objects[n].object];
  
  if (node->tl)
    addObjectsInNodeToSet (set, node->tl);
  if (node->tr)
    addObjectsInNodeToSet (set, node->tr);
  if (node->bl)
    addObjectsInNodeToSet (set, node->bl);
  if (node->br)
    addObjectsInNodeToSet (set, node->br);
}  

- (NSMutableSet *)allObjects
{
  NSMutableSet *set = [NSMutableSet set];
  
  addObjectsInNodeToSet (set, head);
  
  return set;
}

@end

/* Create a new, empty, node in the Quad-Tree.  Note that by default, the
   node is created with no storage space for objects, since it is expected
   that the majority of nodes will not contain objects. */
static struct quad_tree_node *
newNode (struct quad_tree_node *parent)
{
  struct quad_tree_node *node 
    = (struct quad_tree_node *)malloc (sizeof (struct quad_tree_node));
  
  memset (node, 0, sizeof (struct quad_tree_node));
  node->parent = parent;
  
#if DEBUG_NODE_ALLOCATION
  NSLog (@"Allocated node %p", node);
#endif
  
  return node;
}

/* Resize a node */
static struct quad_tree_node *
resizeNode (struct quad_tree_node *node,
	    unsigned		  new_size)
{
  struct quad_tree_node *newptr;
  enum { tl, tr, bl, br, none } parentPos = none;
  
  if (new_size == node->total)
    return node;
  
  if (node->parent) {
    if (node->parent->tl == node)
      parentPos = tl;
    else if (node->parent->tr == node)
      parentPos = tr;
    else if (node->parent->bl == node)
      parentPos = bl;
    else if (node->parent->br == node)
      parentPos = br;
  }
  
#if DEBUG_NODE_ALLOCATION
  NSLog (@"Trying to resize node %p (from %p)", node, __builtin_return_address (0));
#endif
  
  newptr = realloc (node, 
		    sizeof (*node) + sizeof (node->objects[0]) * new_size);
  
  if (!newptr)
    return NULL;

#if DEBUG_NODE_ALLOCATION
  if (node != newptr)
    NSLog (@"Resized node %p to node %p (from %p)", node, newptr,
	   __builtin_return_address (0));
#endif
  
  newptr->total = new_size;
  
  if (newptr->tl) newptr->tl->parent = newptr;
  if (newptr->tr) newptr->tr->parent = newptr;
  if (newptr->bl) newptr->bl->parent = newptr;
  if (newptr->br) newptr->br->parent = newptr;
  
  switch (parentPos) {
    case tl: newptr->parent->tl = newptr; break;
    case tr: newptr->parent->tr = newptr; break;
    case bl: newptr->parent->bl = newptr; break;
    case br: newptr->parent->br = newptr; break;
    default: break;
  }
  
  return newptr;
}

/* Add an object to a quad-tree node, resizing it if necessary.  Note that
   the pointer returned by this function may be different to the original
   pointer passed in. */
static struct quad_tree_node *
addObjectToNode (struct quad_tree_node *node,
		 id object,
		 NSRect bounds)
{
  if (node->used >= node->total) {
    node = resizeNode (node, node->total + 4);
    
    if (!node)
      return NULL;
  }
  
  node->objects[node->used].object = [object retain];
  node->objects[node->used++].bounds = bounds;
  
  return node;
}

/* Remove an object from a quad-tree node, resizing the node if there are
   more than 16 free slots in the node.  This function will release the
   node in question if there are no objects in it and it has no child nodes. */
static struct quad_tree_node *
removeObjectFromNode (struct quad_tree_node *node,
		      unsigned		    index)
{
  NSCAssert2 (index < node->used, 
              @"Can't remove a node after the last index (count %u, index %u)!",
              node->used, index);

  [node->objects[index].object release];
  memmove (&node->objects[index], &node->objects[index + 1], 
	   sizeof (node->objects[0]) * (node->used - index));

  struct quad_tree_node *parent = node->parent;
  if (!--node->used && parent
      && !node->tl && !node->tr && !node->bl && !node->br) {
    do {
      releaseNode (node, NO);
      node = parent;
      parent = node->parent;
    } while (!node->used && parent
	     && !node->tl && !node->tr && !node->bl && !node->br);
    return NULL;      
  } else if (node->total - node->used > 16) {
    unsigned newSize = (node->used + 15) & ~15;
    return resizeNode (node, newSize);
  }
  
  return node;
}

/* Release a quad-tree node, optionally releasing all child nodes */
static void
releaseNode (struct quad_tree_node *node, BOOL recurse)
{
  if (!node)
    return;
  
  CHECK_NODE (node);

#if DEBUG_NODE_ALLOCATION
  NSLog (@"Releasing node %p (%p, %p, %p, %p, %p) at %p",
	 node, node->parent, 
	 node->tl, node->tr, node->bl, node->br);
#endif
  
  if (node->parent) {
    if (node->parent->tl == node)
      node->parent->tl = NULL;
    if (node->parent->tr == node)
      node->parent->tr = NULL;
    if (node->parent->bl == node)
      node->parent->bl = NULL;
    if (node->parent->br == node)
      node->parent->br = NULL;
  }
  
  if (recurse) {
    if (node->tl) releaseNode (node->tl, recurse);
    if (node->tr) releaseNode (node->tr, recurse);
    if (node->bl) releaseNode (node->bl, recurse);
    if (node->br) releaseNode (node->br, recurse);
  }
  
  {
    unsigned n;
    for (n = 0; n < node->used; ++n)
      [node->objects[n].object release];
  }
  
#if DEBUG_NODE_ALLOCATION
  NSLog (@"Freeing %p", node);
#endif
  
#if DEBUG_NODE_ZOMBIES
  node->total = 0;
  node->used = 1;
#else
  free (node);
#endif  
}

/* Split a quad-tree so we can insert the specified rectangle */
static struct quad_tree_node *
splitForRect (struct quad_tree_node *head,
	      NSRect		    bounds,
	      NSRect		    objectRect)
{
  CHECK_NODE (head);
  
  unsigned depth = 0;

  /* The depth limit of 64 is to prevent infinite recursion in the case
     where someone adds a zero-sized object in just the wrong place. */
  while (head && depth++ < 64)
  {
    QuadTreeBox box = whichBox (bounds, objectRect);
    
    if (box == kNoBox)
      return head;
    
    if (!head->boxes[box])
      head->boxes[box] = newNode (head);
	
    head = head->boxes[box];
    bounds = boundsForBox (bounds, box);
  }

  return head;
}

/* Add all of the objects in the specified rectangle to the set */
static void 
addObjectsInRectToSet (NSMutableSet *set,
		       struct quad_tree_node *node,
		       NSRect bounds,
		       NSRect rect,
		       BOOL includeIntersect,
		       BOOL includeContained)
{
  unsigned n;
  QuadTreeBox box;
  
  if (includeIntersect && !includeContained) {
    for (n = 0; n < node->used; ++n) {
      if (CSIntersectsRect (rect, node->objects[n].bounds)
	  && !CSContainsRect (rect, node->objects[n].bounds))
	[set addObject:node->objects[n].object];
    }
  } else if (includeIntersect) {
    for (n = 0; n < node->used; ++n) {
      if (CSIntersectsRect (rect, node->objects[n].bounds))
	[set addObject:node->objects[n].object];
    }
  } else if (includeContained) {
    for (n = 0; n < node->used; ++n) {
      if (CSContainsRect (rect, node->objects[n].bounds))
	[set addObject:node->objects[n].object];
    }
  } else {
    return;
  }
  
  for (box = 0; box < 4; ++box) {
    if (node->boxes[box]) {
      NSRect boxBounds = boundsForBox (bounds, box);
      if (CSIntersectsRect (boxBounds, rect)
	  && (includeContained || !CSContainsRect (rect, boxBounds))) {
	addObjectsInRectToSet (set, node->boxes[box], boxBounds, rect, 
			       includeIntersect, includeContained);
      }
    }
  }
}

/* Find the node for an object, without using information about its
   rectangle. */
static struct quad_tree_node *
findNodeForObject (struct quad_tree_node *node,
		   id			 object,
		   unsigned		 hash,
		   unsigned		 *ndx)
{
  CHECK_NODE (node);
  
  unsigned n;
  struct quad_tree_node *found = NULL;
  
  for (n = 0; n < node->used; ++n) {
    if (hash == [node->objects[n].object hash]
	&& [object isEqualTo:node->objects[n].object]) {
      if (ndx)
	*ndx = n;
      return node;
    }
  }
  
  if (node->tl)
    found = findNodeForObject (node->tl, object, hash, ndx);

  if (!found && node->tr)
    found = findNodeForObject (node->tr, object, hash, ndx);

  if (!found && node->bl)
    found = findNodeForObject (node->bl, object, hash, ndx);
  
  if (!found && node->br)
    found = findNodeForObject (node->br, object, hash, ndx);
  
  return found;
}

/* Find the node for an object, with a rectangle. */
static struct quad_tree_node *
findNodeForObjectWithRect (struct quad_tree_node *node,
			   NSRect		 bounds,
			   id			 object,
			   unsigned		 hash,
			   NSRect		 rect,
			   BOOL			 rectIsHint,
			   unsigned		 *ndx)
{
  CHECK_NODE (node);
  
  struct quad_tree_node *found = NULL;
  unsigned n;
  QuadTreeBox box;
  
  if (!rectIsHint && !CSContainsRect (bounds, rect))
    return NULL;
  
  if (CSContainsRect (rect, bounds))
    return findNodeForObject (node, object, hash, ndx);
  
  for (n = 0; n < node->used; ++n) {
    if (hash == [node->objects[n].object hash]
	&& [object isEqualTo:node->objects[n].object]
	&& (rectIsHint || NSEqualRects (node->objects[n].bounds, rect))) {
      if (ndx)
	*ndx = n;
      return node;
    }
  }

  for (box = 0; box < 4; ++box) {
    if (node->boxes[box]) {
      NSRect boxBounds = boundsForBox (bounds, box);
      if (CSIntersectsRect (rect, boxBounds)) {
	found = findNodeForObjectWithRect (node->boxes[box], boxBounds,
					   object, hash, rect, rectIsHint, ndx);
	if (found)
	  return found;
      }
    }
  }

  return found;
}

/* Work out the rectangle that encloses all nodes in the quadtree */
static void
unionRectForAllNodes (struct quad_tree_node *node,
                      NSRect                 bounds,
                      NSRect                *unionRect,
                      BOOL                  *foundRect)
{
  CHECK_NODE (node);
  unsigned n;
  QuadTreeBox box;

  for (n = 0; n < node->used; ++n) {
    if (!*foundRect) {
      *foundRect = YES;
      *unionRect = node->objects[n].bounds;
    } else {
      *unionRect = NSUnionRect (*unionRect, node->objects[n].bounds);
    }
  }
  
  for (box = 0; box < 4; ++box) {
    if (node->boxes[box]) {
      NSRect boxBounds = boundsForBox (bounds, box);
      if (!CSContainsRect (*unionRect, boxBounds))
	unionRectForAllNodes (node->boxes[box], boxBounds, unionRect, foundRect);
    }
  }
}

/* Draw the quadtree (for debugging) */
static void
strokeQuadTreeNodes (struct quad_tree_node *node,
                     NSRect		    bounds)
{
  CHECK_NODE (node);
  
  NSBezierPath *path = [NSBezierPath bezierPath];
  unsigned n;
  QuadTreeBox box;
  NSPoint midPoint = NSMakePoint (bounds.origin.x + bounds.size.width / 2,
				  bounds.origin.y + bounds.size.height / 2);

  if (!node) {
    [[NSString stringWithFormat:@"empty"]
     drawAtPoint:midPoint
     withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
   [NSFont systemFontOfSize:10], NSFontAttributeName,
   [NSColor grayColor], NSForegroundColorAttributeName,
   nil]];
    
    return;
  }
  
  for (box = 0; box < 4; ++box)
    strokeQuadTreeNodes (node->boxes[box], boundsForBox (bounds, box));
  
  [[NSColor greenColor] set];
  [path moveToPoint:NSMakePoint (midPoint.x, NSMinY (bounds))];
  [path lineToPoint:NSMakePoint (midPoint.x, NSMaxY (bounds))];
  [path moveToPoint:NSMakePoint (NSMinX (bounds), midPoint.y)];
  [path lineToPoint:NSMakePoint (NSMaxX (bounds), midPoint.y)];
  [path stroke];
  
  [[NSString stringWithFormat:@"%p", node]
    drawAtPoint:midPoint
 withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
   [NSFont systemFontOfSize:10], NSFontAttributeName,
   [NSColor greenColor], NSForegroundColorAttributeName,
   nil]];
  
  [[NSColor redColor] set];
  for (n = 0; n < node->used; ++n) {
    NSPoint centre;
    
    NSFrameRect (node->objects[n].bounds);
    
    centre.x = NSMidX (node->objects[n].bounds);
    centre.y = NSMidY (node->objects[n].bounds);
    
    [[NSString stringWithFormat:@"%p", node]
    drawAtPoint:centre
 withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
   [NSFont systemFontOfSize:10], NSFontAttributeName,
   [NSColor redColor], NSForegroundColorAttributeName,
   nil]];
    
  }
}

