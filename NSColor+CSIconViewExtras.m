//
//  NSColor+CSIconViewExtras.m
//  CSIconView
//
//  Created by Alastair Houghton on 18/09/2005.
//  Copyright 2005 Coriolis Systems Limited. All rights reserved.
//

#import <ApplicationServices/ApplicationServices.h>
#import "NSColor+CSIconViewExtras.h"

static CMWorldRef colorWorld = NULL;

@implementation NSColor (CSIconViewExtras)

#define CMNOERRORS(x)					\
{							\
  CMError err = x;					\
  if (err != noErr)					\
    [NSException raise:@"CSColorColorSyncError"		\
		format:@"ColorSync error %d", err];	\
}

- (void)getL:(CGFloat *)pL u:(CGFloat *)pu v:(CGFloat *)pv alpha:(CGFloat *)alpha
{
  float rgb[6];
  float xyz[6];
  float luv[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 2, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 2, 1, cmXYZData);
  CMFloatBitmap luvFB = CMFloatBitmapMakeChunky(luv, 1, 1, cmLuvData);
  
  CGFloat r, g, b;
  [self getRed:&r green:&g blue:&b alpha:alpha];
  rgb[0] = r; rgb[1] = g; rgb[2] = b;
  rgb[3] = rgb[4] = rgb[5] = 1.0;
  
  if (!colorWorld) {
    CMProfileRef xyzProfile, rgbProfile;

    CMNOERRORS (CMGetDefaultProfileBySpace (cmXYZData, &xyzProfile));
    CMNOERRORS (CMGetDefaultProfileBySpace (cmRGBData, &rgbProfile));
  
    CMNOERRORS (NCWNewColorWorld (&colorWorld, rgbProfile, xyzProfile));

    CMCloseProfile (rgbProfile);
    CMCloseProfile (xyzProfile);
  }

  CMNOERRORS (CMMatchFloatBitmap (colorWorld, &rgbFB, &xyzFB));
  
  xyzFB = CMFloatBitmapMakeChunky(xyz, 1, 1, cmXYZData);
  
  CMNOERRORS (CMConvertXYZFloatBitmap (&xyzFB, &xyz[3], &luvFB, NULL, 
                                       cmUseDefaultChromaticAdaptation));

  *pL = luv[0];
  *pu = luv[1];
  *pv = luv[2];
}

- (void)getL:(CGFloat *)pL a:(CGFloat *)pa b:(CGFloat *)pb alpha:(CGFloat *)alpha
{
  float rgb[6];
  float xyz[6];
  float lab[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 2, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 2, 1, cmXYZData);
  CMFloatBitmap labFB = CMFloatBitmapMakeChunky(lab, 1, 1, cmLabData);
  
  CGFloat r, g, b;
  [self getRed:&r green:&g blue:&b alpha:alpha];
  rgb[0] = r; rgb[1] = g; rgb[2] = b;
  rgb[3] = rgb[4] = rgb[5] = 1.0;
  
  if (!colorWorld) {
    CMProfileRef xyzProfile, rgbProfile;
    
    CMNOERRORS (CMGetDefaultProfileBySpace (cmXYZData, &xyzProfile));
    CMNOERRORS (CMGetDefaultProfileBySpace (cmRGBData, &rgbProfile));
    
    CMNOERRORS (NCWNewColorWorld (&colorWorld, rgbProfile, xyzProfile));
    
    CMCloseProfile (rgbProfile);
    CMCloseProfile (xyzProfile);
  }
  
  CMNOERRORS (CMMatchFloatBitmap (colorWorld, &rgbFB, &xyzFB));
  
  xyzFB = CMFloatBitmapMakeChunky(xyz, 1, 1, cmXYZData);
  
  CMNOERRORS (CMConvertXYZFloatBitmap (&xyzFB, &xyz[3], &labFB, NULL, 
                                       cmUseDefaultChromaticAdaptation));
  
  *pL = lab[0];
  *pa = lab[1];
  *pb = lab[2];
}

- (void)getX:(CGFloat *)pX Y:(CGFloat *)pY Z:(CGFloat *)pZ alpha:(CGFloat *)alpha
{
  float rgb[3];
  float xyz[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 1, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 1, 1, cmXYZData);
  
  CGFloat r, g, b;
  [self getRed:&r green:&g blue:&b alpha:alpha];
  rgb[0] = r;
  rgb[1] = g;
  rgb[2] = b;
  
  if (!colorWorld) {
    CMProfileRef xyzProfile, rgbProfile;
    
    CMNOERRORS (CMGetDefaultProfileBySpace (cmXYZData, &xyzProfile));
    CMNOERRORS (CMGetDefaultProfileBySpace (cmRGBData, &rgbProfile));
    
    CMNOERRORS (NCWNewColorWorld (&colorWorld, rgbProfile, xyzProfile));
    
    CMCloseProfile (rgbProfile);
    CMCloseProfile (xyzProfile);
  }
  
  CMNOERRORS (CMMatchFloatBitmap (colorWorld, &rgbFB, &xyzFB));
  
  *pX = xyz[0];
  *pY = xyz[1];
  *pZ = xyz[2];
}

@end
