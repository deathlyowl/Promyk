//
//  sunmath.h
//  Promyk
//
//  Created by Paweł Ksieniewicz on 31.07.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#ifndef Promyk_sunmath_h
#define Promyk_sunmath_h

#pragma mark - C Functions

double degreesToRadians(double degrees);
double radiansToDegrees(double radians);
double appToJulian(double app, double anomaly, double lambda);
double approx(double angle, int julianCycle);
double hourAngle(double angle, double latitude, double delta);
double eclipticLongitude (double M, double C);
double equationOfCenter(double M);
double solarMeanAnomaly(double J);

#endif
