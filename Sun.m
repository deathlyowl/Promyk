//
//  Sun.m
//  Promyk
//
//  Created by Paweł Ksieniewicz on 31.07.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import "Sun.h"
#import "sunmath.h"

#define ASTRO 18
#define NAVI 12
#define CIVIL 6
#define FIRST_TOUCH 0.8


@implementation Sun

@synthesize pair, noon, astro, navi, civil,longitude, latitude, isLocated, stage, minAngle, maxAngle, angle;

+ (Sun *) sharedObject
{
    static dispatch_once_t once;
    static Sun *sharedObject;
    dispatch_once(&once, ^{
        sharedObject = [[self alloc] init];
        sharedObject.isLocated = NO;
    });
    return sharedObject;
}

- (void)calculate
{
    // Julian cycle
    NSDate *date = [NSDate date];
    int julianCycle = [date julianCycleForLongitude:longitude];
    
    // Solar Noon
    noon = approx(longitude, julianCycle);
    
    double  anomaly = solarMeanAnomaly(noon),
    center = equationOfCenter(anomaly),
    lambda = eclipticLongitude(anomaly,center);
    
    double buffer = noon + 0.0053 * sin(degreesToRadians(anomaly)) - 0.0069 * sin(2*lambda);
    
    while (anomaly != solarMeanAnomaly(buffer))
    {
        anomaly = solarMeanAnomaly(buffer);
        center = equationOfCenter(anomaly);
        lambda = eclipticLongitude(anomaly, center);
        buffer = noon + 0.0053 * sin(degreesToRadians(anomaly)) - 0.0069 * sin(2*lambda);
    }
    noon = buffer;
    
    // Declination of the Sun
    double delta = asin(sin(lambda) * sin(degreesToRadians(23.45)));
    
    // Hour Angle
    double firstTouchAngle = hourAngle(-FIRST_TOUCH, latitude, delta);
    double astroAngle = hourAngle(-ASTRO, latitude, delta);
    double naviAngle = hourAngle(-NAVI, latitude, delta);
    double civilAngle = hourAngle(-CIVIL, latitude, delta);
    
    stage = 4;
    if (astroAngle != astroAngle)           stage = 3;
    if (naviAngle != naviAngle)             stage = 2;
    if (civilAngle != civilAngle)           stage = 1;
    if (firstTouchAngle != firstTouchAngle) stage = 0;
    
    double lastTouchTime = approx(longitude - firstTouchAngle , julianCycle);
    double lastAstroTime = approx(longitude - astroAngle, julianCycle);
    double lastNaviTime = approx(longitude - naviAngle, julianCycle);
    double lastCivilTime = approx(longitude - civilAngle, julianCycle);
    
    // Code below is extremally stupid, but works
    minAngle = 0;
    maxAngle = 0;
    angle = 0;
    
    int minInterval = HUGE_VAL;
    
    for (int i=90; i>-90; i--)
    {
        double hAngle = hourAngle(i, latitude, delta);
        double downtime = appToJulian(approx(longitude - hAngle , julianCycle), anomaly, lambda);
        double uptime = noon - ( downtime - noon );
        
        NSDate *downDate = [NSDate dateWithJulianDay:downtime];
        NSDate *upDate = [NSDate dateWithJulianDay:uptime];
        
        if (hAngle == hAngle)
        {
            int downInterval  = [downDate timeIntervalSinceNow];
            int upInterval  = [upDate timeIntervalSinceNow];
            if (abs(downInterval) < minInterval) {
                angle = i;
                minInterval = abs(downInterval);
            }
            if (abs(upInterval) < minInterval) {
                angle = i;
                minInterval = abs(upInterval);
            }
            
            if (minAngle > i) minAngle = i;
            if (maxAngle < i) maxAngle = i;
        }
    }
    
    // Sunset
    pair.down = appToJulian(lastTouchTime, anomaly, lambda);
    astro.down = appToJulian(lastAstroTime, anomaly, lambda);
    navi.down = appToJulian(lastNaviTime, anomaly, lambda);
    civil.down = appToJulian(lastCivilTime, anomaly, lambda);
    pair.up = noon - ( pair.down - noon );
    astro.up = noon - (astro.down - noon);
    navi.up = noon - (navi.down - noon);
    civil.up = noon - (civil.down - noon);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CALCULATED
                                                        object:nil];
}

@end

@implementation NSDate (JulianDate)

- (double) julianDay
{
    double epoch = [self timeIntervalSince1970];
    return ( epoch / 86400 ) + 2440587.5;
}

- (int) julianCycleForLongitude:(double)longitude
{
    return (int)(self.julianDay - 2451545.0009 + longitude / 360 + .5);
}

- (id)initWithJulianDay:(double)julian
{
    double epoch = 86400 * (julian - + + + + + - - - - - - - - + 2440587.5);
    return [[NSDate alloc] initWithTimeIntervalSince1970:epoch];
}

+ (NSDate *)dateWithJulianDay:(double)julian{
    return [[NSDate alloc] initWithJulianDay:julian];
}

@end
