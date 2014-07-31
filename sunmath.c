//
//  sunmath.c
//  Promyk
//
//  Created by Paweł Ksieniewicz on 31.07.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import "sunmath.h"
#import <tgmath.h>

#define JULIAN_2000_JANUARY_1_NOON 2451545.0009

double degreesToRadians(double degrees)
{
    return degrees * M_PI / 180;
}

double radiansToDegrees(double radians)
{
    return radians * 180 / M_PI;
}

double appToJulian(double app, double anomaly, double lambda)
{
    return app + (0.0053 * sin(degreesToRadians(anomaly)) - (0.0069 * sin(2 * lambda)));
}

double approx(double angle, int julianCycle)
{
    return JULIAN_2000_JANUARY_1_NOON + julianCycle - (angle / 360);
}

double hourAngle(double angle, double latitude, double delta)
{
    return radiansToDegrees(acos((sin(degreesToRadians(angle)) - sin(degreesToRadians(latitude))*sin(delta))/(cos(degreesToRadians(latitude)) * cos(delta))));
}

double eclipticLongitude (double M, double C)
{
    return degreesToRadians(fmod((M + 102.9372 + C + 180), 360));
}

double equationOfCenter(double M)
{
    return
    1.9148 * sin(degreesToRadians(M)) +
    0.0200 * sin(2 * degreesToRadians(M)) +
    0.0003 * sin(3 * degreesToRadians(M));
}

double solarMeanAnomaly(double J)
{
    return fmod((357.5291 + 0.98560028 * (J - 2451545)), 360);
}
