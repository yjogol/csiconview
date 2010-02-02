//
//  NSColor+CSIconViewExtras.h
//  CSIconView
//
//  Created by Alastair Houghton on 18/09/2005.
//  Copyright 2005 Coriolis Systems Limited. All rights reserved.
//

#import <AppKit/NSColor.h>

@interface NSColor (CSIconViewExtras) 

- (void)getL:(float *)pL u:(float *)pu v:(float *)pv alpha:(float *)alpha;
- (void)getL:(float *)pL a:(float *)pa b:(float *)pb alpha:(float *)alpha;
- (void)getX:(float *)X Y:(float *)Y Z:(float *)Z alpha:(float *)alpha;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
