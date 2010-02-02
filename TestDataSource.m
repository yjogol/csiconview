//
//  TestDataSource.m
//  CSIconViewTest
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

#import "TestDataSource.h"
#import <CSIconView/CSIconView.h>

@implementation TestDataSource

- (unsigned)numberOfItemsInIconView:(CSIconView *)view
{
  return 1000;
}

- (CSIconViewItem *)iconView:(CSIconView *)view
		 itemAtIndex:(unsigned)index
{
  CSIcon *icon = [CSIcon iconWithContentsOfFile:@"/System/Library/CoreServices/"
                  @"CoreTypes.bundle/Contents/Resources/GenericFolderIcon.icns"];
  
  CSIconViewItem *item = [CSIconViewItem iconViewItemWithIcon:icon
							title:
      [NSString stringWithFormat:@"Hello World %u", index]];
  
  switch (index) {
    case 37:
      [item setState:kCSIVItemCustomSizeMask];
      [item setCustomSize:NSMakeSize (200, 180)];
      [item setCustomIconSize:NSMakeSize (128, 128)];
      break;
      
    case 54:
      [item setLabelColor:[NSColor yellowColor]];
      [item setState:kCSIVItemLabelledMask];
      break;
      
    case 55:
      [item setLabelColor:[NSColor blueColor]];
      [item setState:kCSIVItemLabelledMask];
      break;
      
    case 23:
      [item setIcon:nil];
      break;
      
    case 27:
      [item setState:kCSIVItemDisabledMask];
      break;
      
    case 29:
      [item setState:kCSIVItemOpenMask];
      break;
      
    case 30:
      [item setState:kCSIVItemAcceptingDropMask];
      break;
  }
  
  return item;
}

- (NSArray *)iconViewAcceptedPasteboardTypesForDrop:(CSIconView *)view
{
  return [NSArray array];
}

- (NSArray *)iconViewPasteboardTypesForDrag:(CSIconView *)view
{
  return [NSArray array];
}

@end
