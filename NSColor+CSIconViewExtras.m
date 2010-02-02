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

- (void)getL:(float *)pL u:(float *)pu v:(float *)pv alpha:(float *)alpha
{
  float rgb[6];
  float xyz[6];
  float luv[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 2, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 2, 1, cmXYZData);
  CMFloatBitmap luvFB = CMFloatBitmapMakeChunky(luv, 1, 1, cmLuvData);
  
  [self getRed:&rgb[0] green:&rgb[1] blue:&rgb[2] alpha:alpha];
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

- (void)getL:(float *)pL a:(float *)pa b:(float *)pb alpha:(float *)alpha
{
  float rgb[6];
  float xyz[6];
  float lab[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 2, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 2, 1, cmXYZData);
  CMFloatBitmap labFB = CMFloatBitmapMakeChunky(lab, 1, 1, cmLabData);
  
  [self getRed:&rgb[0] green:&rgb[1] blue:&rgb[2] alpha:alpha];
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
  
  NSLog (@"%f,%f,%f => %f,%f,%f => %f,%f,%f\n",
         rgb[0], rgb[1], rgb[2],
         xyz[0], xyz[1], xyz[2],
         lab[0], lab[1], lab[2]);
  
  *pL = lab[0];
  *pa = lab[1];
  *pb = lab[2];
}

- (void)getX:(float *)pX Y:(float *)pY Z:(float *)pZ alpha:(float *)alpha
{
  float rgb[3];
  float xyz[3];
  CMFloatBitmap rgbFB = CMFloatBitmapMakeChunky(rgb, 1, 1, cmRGBData);
  CMFloatBitmap xyzFB = CMFloatBitmapMakeChunky(xyz, 1, 1, cmXYZData);
  
  [self getRed:&rgb[0] green:&rgb[1] blue:&rgb[2] alpha:alpha];
  
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
