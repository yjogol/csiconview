//
//  NSSet+CSSetOperations.m
//  CSFoundation
//
//  Created by Alastair Houghton on 22/10/2007.
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

#import "NSSet+CSSetOperations.h"
#import "NSMutableSet+CSSymmetricDifference.h"

@implementation NSSet (CSSetOperations)

- (NSSet *)setByIntersectingWithSet:(NSSet *)otherSet
{
  NSMutableSet *result = [[self mutableCopy] autorelease];
  [result intersectSet:otherSet];
  return result;
}

- (NSSet *)setBySubtractingSet:(NSSet *)otherSet
{
  NSMutableSet *result = [[self mutableCopy] autorelease];
  [result minusSet:otherSet];
  return result;
}

- (NSSet *)setFromUnionWithSet:(NSSet *)otherSet
{
  NSMutableSet *result = [[self mutableCopy] autorelease];
  [result unionSet:otherSet];
  return result;
}

- (NSSet *)setFromDifferenceWithSet:(NSSet *)otherSet
{
  NSMutableSet *result = [[self mutableCopy] autorelease];
  [result differenceSet:otherSet];
  return result;
}

@end
