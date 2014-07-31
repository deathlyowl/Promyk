//
//  Sun.h
//  Promyk
//
//  Created by Paweł Ksieniewicz on 31.07.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CALCULATED @"CalculationsDidEnd"

struct timePair {double up, down;};

@interface Sun : NSObject

@property (nonatomic) double noon;

@property (nonatomic) double longitude;
@property (nonatomic) double latitude;

@property (nonatomic) struct timePair pair;
@property (nonatomic) struct timePair astro;
@property (nonatomic) struct timePair navi;
@property (nonatomic) struct timePair civil;

@property (nonatomic) int minAngle, maxAngle, angle;

@property (nonatomic) int stage;

@property (nonatomic) BOOL isLocated;

- (void) calculate;
+ (Sun *) sharedObject;

@end

@interface NSDate (JulianDate)

- (double) julianDay;
- (int) julianCycleForLongitude:(double)longitude;
- (id) initWithJulianDay:(double)julian;
+ (NSDate *) dateWithJulianDay:(double) julian;

@end
