//
//  TestTarget.m
//  CSIconView
//
//  Created by Alastair Houghton on 03/02/2010.
//  Copyright 2010 Coriolis Systems Limited. All rights reserved.
//

#import "TestTarget.h"
#import <CSIconView/CSIconView.h>

@implementation TestTarget

- (IBAction)itemClicked:(id)sender
{
  CSIconView *view = (CSIconView *)sender;
  NSMutableString *itemList = [NSMutableString string];
  
  for (CSIconViewItem *item in [view selectedItems]) {
    [itemList appendFormat:@"\nItem %@", [item title]];
  }
  
  NSRunAlertPanel(@"You opened an item!", @"Selected items:%@", nil, nil, nil, itemList);
}

@end
