//
//  NSColor+CSIconViewExtras.h
//  CSIconView
//
//  Created by Alastair Houghton on 18/09/2005.
//  Copyright 2005 Coriolis Systems Limited. All rights reserved.
//

#import <AppKit/NSColor.h>

@interface NSColor (CSIconViewExtras) 

- (void)getL:(CGFloat *)pL u:(CGFloat *)pu v:(CGFloat *)pv alpha:(CGFloat *)alpha;
- (void)getL:(CGFloat *)pL a:(CGFloat *)pa b:(CGFloat *)pb alpha:(CGFloat *)alpha;
- (void)getX:(CGFloat *)X Y:(CGFloat *)Y Z:(CGFloat *)Z alpha:(CGFloat *)alpha;

@end

/*
 * Local Variables:
 * mode: ObjC
 * End:
 *
 */
