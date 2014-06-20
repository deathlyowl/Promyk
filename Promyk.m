//
//  Promyk
//
//  Created by Paweł Ksieniewicz on 04.04.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import <Availability.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <tgmath.h>

#define LINE_WIDTH 8
#define SMALL_UNIT 20
#define BIG_UNIT 80
#define DASH_PATTERN @[@LINE_WIDTH,@LINE_WIDTH]
#define ANIMATION_DURATION 1
#define YELLOW [UIColor colorWithHue:0.16f saturation:0.51f brightness:1.00f alpha:1.00f]
#define FONT [UIFont fontWithName:@"ModernSans" size:50]
#define CALCULATED @"CalculationsDidEnd"
#define JULIAN_2000_JANUARY_1_NOON 2451545.0009
#define ASTRO 18
#define NAVI 12
#define CIVIL 6
#define FIRST_TOUCH 0.83

struct timePair {double up, down;};

#pragma mark - C Functions

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

#pragma mark - Classes declarations
@interface AppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic) CLLocationManager *locationManager;

@end

@interface ViewController : UIViewController
{
    CAShapeLayer *handSolid, *handDashed, *innerCircle, *outerCircle, *sun, *centerline;
    UILabel *hourLabel, *angleLabel, *verbumLabel;
}

@end

@interface Sun : NSObject

//@property (nonatomic) double sunset;
//@property (nonatomic) double sunrise;

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

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

#pragma mark - Class implementations

@implementation AppDelegate

@synthesize window, locationManager;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarHidden:YES];
    [application setIdleTimerDisabled:YES];    // Do not fall asleep
    
    // Generate and show view
    window = UIWindow.new;
    window.frame = UIScreen.mainScreen.bounds;
    window.rootViewController = ViewController.new;
    [window makeKeyAndVisible];
    
    // Initialize location manager
    locationManager = CLLocationManager.new;
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    [self locate];
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[Sun sharedObject] calculate];
}

- (void) locate
{
    NSLog(@"Locate!");
    double longitude = [[NSUserDefaults.standardUserDefaults objectForKey:@"longitude"] doubleValue];
    double latitude = [[NSUserDefaults.standardUserDefaults objectForKey:@"latitude"] doubleValue];
    if (longitude && latitude)
    {
        [[Sun sharedObject] setLatitude:latitude];
        [[Sun sharedObject] setLongitude:longitude];
        [[Sun sharedObject] setIsLocated:YES];
        [[Sun sharedObject] calculate];
    }
    [locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = [locations lastObject];
    
    Sun.sharedObject.latitude = location.coordinate.latitude;
    Sun.sharedObject.longitude = location.coordinate.longitude;
    Sun.sharedObject.isLocated = YES;
    [Sun.sharedObject calculate];
    
    [manager stopUpdatingLocation];
    
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];
    [NSUserDefaults.standardUserDefaults synchronize];
}

@end

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
    
    // Lookup
    /*
    NSLog(@"STAGE: %i", stage);
    NSLog(@"NOW:\t\t %@",           [NSDate dateWithJulianDay:julianNow]);
    NSLog(@"NOON:\t\t %@",          [NSDate dateWithJulianDay:noon]);
    NSLog(@"NORMAL:\t\t %@ | %@",   [NSDate dateWithJulianDay:pair.up],     [NSDate dateWithJulianDay:pair.down]);
    NSLog(@"CIVIL:\t\t %@ | %@",    [NSDate dateWithJulianDay:civil.up],    [NSDate dateWithJulianDay:civil.down]);
    NSLog(@"NAVI:\t\t %@ | %@",     [NSDate dateWithJulianDay:navi.up],     [NSDate dateWithJulianDay:navi.down]);
    NSLog(@"ASTRO:\t\t %@ | %@",    [NSDate dateWithJulianDay:astro.up],    [NSDate dateWithJulianDay:astro.down]);
    */
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

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configure];
}

- (BOOL)canBecomeFirstResponder{
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake)
    {
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] locate];
    } 
}
- (void) tick
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit)
                                               fromDate:[NSDate date]];
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    
    NSString *separator = second % 2 ? @":" : @".";
    
    [hourLabel setText:[NSString stringWithFormat:@"%li%@%02li", (long)hour, separator, (long)minute]];
    
    [self setSeconds:second];
}

- (UIColor *) wantedBackgroundColor
{
    int angle = [[Sun sharedObject] angle];
    if (angle < 0)
    {
        if (angle > -18)
        {
            return [UIColor colorWithHue:.6 saturation:.5 brightness:.3 + .25 * (angle/18.) alpha:1];
        }
        return [UIColor colorWithHue:.6 saturation:.5 brightness:.05 alpha:1];
    }
    else if (angle == 0) return [UIColor colorWithHue:.6 saturation:.5 brightness:.3 alpha:1];
    else if (angle < 45)
    {
        return [UIColor colorWithHue:.6 saturation:.5 brightness:.3 + (.7 * angle/45.) alpha:1];
    }
    return [UIColor colorWithHue:.16 saturation:.5 brightness:1 alpha:1];
}

- (UIColor *) wantedForegreoundColor
{
    return [[Sun sharedObject] angle] < 45 ? [UIColor whiteColor] : [UIColor blackColor];
}

- (void) configure
{
    // Preparations
    [self.view.layer setCornerRadius:20];
    [self.view.layer setBackgroundColor:YELLOW.CGColor];
    CGMutablePathRef path;
    
    // Centerline
    centerline = [CAShapeLayer layer];
    [centerline setPosition:self.view.center];
    [centerline setStrokeColor:[UIColor blackColor].CGColor];
    [centerline setLineWidth:LINE_WIDTH];
    
    path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, -2 * SMALL_UNIT, 0);
    CGPathAddLineToPoint(path, NULL, 2 * SMALL_UNIT, 0);
    
    [centerline setPath:path];
    
    // Hand solid
    handSolid = [CAShapeLayer layer];
    [handSolid setPosition:self.view.center];
    [handSolid setStrokeColor:[UIColor blackColor].CGColor];
    [handSolid setLineWidth:LINE_WIDTH];
    
    path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 0);
    CGPathAddLineToPoint(path, NULL, -2 * SMALL_UNIT, 0);
    
    [handSolid setPath:path];
    
    // Hand dashed
    handDashed = [CAShapeLayer layer];
    [handDashed setPosition:self.view.center];
    [handDashed setStrokeColor:[UIColor blackColor].CGColor];
    [handDashed setLineWidth:LINE_WIDTH];
    [handDashed setLineDashPattern:DASH_PATTERN];
    
    path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 0);
    CGPathAddLineToPoint(path, NULL, -6 * SMALL_UNIT, 0);
    
    [handDashed setPath:path];
    
    // Inner circle
    innerCircle = [CAShapeLayer layer];
    [innerCircle setPosition:self.view.center];
    [innerCircle setStrokeColor:[UIColor blackColor].CGColor];
    [innerCircle setFillColor:[UIColor clearColor].CGColor];
    [innerCircle setLineWidth:LINE_WIDTH];
    [innerCircle setLineCap:kCALineCapRound];
    [innerCircle setPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-SMALL_UNIT * 6,
                                                                           -SMALL_UNIT * 6,
                                                                           SMALL_UNIT * 12,
                                                                           SMALL_UNIT * 12)].CGPath];
    
    // Outer circle
    outerCircle = [CAShapeLayer layer];
    [outerCircle setPosition:self.view.center];
    [outerCircle setStrokeColor:[UIColor blackColor].CGColor];
    [outerCircle setFillColor:[UIColor clearColor].CGColor];
    [outerCircle setLineWidth:LINE_WIDTH];
    [outerCircle setOpacity:.1];
    [outerCircle setStrokeStart:0];
    [outerCircle setStrokeEnd:0];
    [outerCircle setTransform:CATransform3DMakeRotation(-M_PI_2, 0, 0, 1)];
    [outerCircle setPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-SMALL_UNIT * 7,
                                                                           -SMALL_UNIT * 7,
                                                                           SMALL_UNIT * 14,
                                                                           SMALL_UNIT * 14)].CGPath];
    
    // Sun
    sun = [CAShapeLayer layer];
    [sun setStrokeColor:YELLOW.CGColor];
    [sun setFillColor:[UIColor blackColor].CGColor];
    [sun setLineWidth:LINE_WIDTH];
    
    [sun setPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-SMALL_UNIT*6 -LINE_WIDTH,-LINE_WIDTH,
                                                                   LINE_WIDTH*2,
                                                                   LINE_WIDTH*2)].CGPath];
    
    // Labels
    hourLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2*SMALL_UNIT, 320, 2.5*SMALL_UNIT)];
    verbumLabel = [[UILabel alloc] initWithFrame:CGRectMake(SMALL_UNIT, 5*BIG_UNIT, 320 - 2*SMALL_UNIT, 2.5*SMALL_UNIT)];
    angleLabel = [[UILabel alloc] initWithFrame:CGRectMake(BIG_UNIT+10, 3*BIG_UNIT + SMALL_UNIT, 2*BIG_UNIT, 2.5*SMALL_UNIT)];
    
    hourLabel.font = verbumLabel.font = angleLabel.font = FONT;
    
//    verbumLabel.font = WEATHER_FONT;
    
    
    hourLabel.textAlignment = verbumLabel.textAlignment = angleLabel.textAlignment = NSTextAlignmentCenter;
    
    [hourLabel.layer setOpacity:.1];
    
    [verbumLabel setMinimumScaleFactor:.1];
    [verbumLabel setAdjustsFontSizeToFitWidth:YES];
    
    // Place all the layers
    [self.view.layer addSublayer:outerCircle];
    [self.view.layer addSublayer:innerCircle];
    [self.view.layer addSublayer:centerline];
    [self.view.layer addSublayer:handSolid];
    [self.view.layer addSublayer:handDashed];
    [handDashed addSublayer:sun];
    [self.view addSubview:verbumLabel];
    [self.view addSubview:hourLabel];
    [self.view addSubview:angleLabel];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:YES];
    [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES] fire];
}

- (void) setSeconds:(int) seconds
{
    [outerCircle setStrokeStart:0];
    [outerCircle setStrokeEnd:(float)seconds/59.];
    [self setAngle];
    if (seconds == 0) [[Sun sharedObject] calculate];
}

- (NSString *) verbum
{
    NSDate *now = [NSDate date];
    NSDate *noon = [NSDate dateWithJulianDay:[[Sun sharedObject] noon]];
    NSDate *midnight = [noon dateByAddingTimeInterval:60*60*12];
    NSDate *sunrise = [NSDate dateWithJulianDay:[[Sun sharedObject] pair].up];
    NSDate *sunset = [NSDate dateWithJulianDay:[[Sun sharedObject] pair].down];
    
    int minutesToNoon = (int)[now timeIntervalSinceDate:noon]/60;
    int minutesToMidnight = (int)[now timeIntervalSinceDate:midnight]/60;
    int minutesToSunset = (int)[now timeIntervalSinceDate:sunset]/60;
    int minutesToSunrise = (int)[now timeIntervalSinceDate:sunrise]/60;

    if (abs(minutesToNoon) < 15)
    {
        if (minutesToNoon == 0) return @"Noon";
        return minutesToNoon > 0 ? [NSString stringWithFormat:@"%i past noon", abs(minutesToNoon)] : [NSString stringWithFormat:@"Noon in %i", abs(minutesToNoon)];
    }
    
    if (abs(minutesToMidnight) < 15)
    {
        if (minutesToMidnight == 0) return @"Midnight";
        return minutesToMidnight > 0 ? [NSString stringWithFormat:@"%i past midnight", abs(minutesToMidnight)] : [NSString stringWithFormat:@"Midnight in %i", abs(minutesToMidnight)];
    }
    
    if (abs(minutesToSunset) < 15)
    {
        if (minutesToSunset == 0) return @"Sunset";
        return minutesToSunset > 0 ? [NSString stringWithFormat:@"%i past sunset", abs(minutesToSunset)] : [NSString stringWithFormat:@"Sunset in %i", abs(minutesToSunset)];
    }
    
    if (abs(minutesToSunrise) < 15)
    {
        if (minutesToSunrise == 0) return @"Sunrise";
        return minutesToSunrise > 0 ? [NSString stringWithFormat:@"%i past sunrise", abs(minutesToSunrise)] : [NSString stringWithFormat:@"Sunrise in %i", abs(minutesToSunrise)];
    }
    return @"";
    //return [NSString stringWithFormat:@"%i | %i | %i | %i", minutesToNoon, minutesToMidnight, minutesToSunset, minutesToSunrise];
}

- (void) setAngle
{
    float angle = [[Sun sharedObject] angle];
    
    [CATransaction setAnimationDuration:ANIMATION_DURATION];
    CATransform3D transform = CATransform3DMakeRotation(degreesToRadians(angle), 0, 0, 1);
    
    handSolid.transform = transform;
    handDashed.transform = transform;
    [angleLabel setText:[NSString stringWithFormat:@"%.0f°", angle]];
    
    [angleLabel.layer setFrame:CGRectMake(angle > 0 ? BIG_UNIT+10 : BIG_UNIT,
                                          angle > 0 ? 3*BIG_UNIT + SMALL_UNIT : 2*BIG_UNIT + SMALL_UNIT,
                                          2*BIG_UNIT,
                                          2.5*SMALL_UNIT)];
    
    [verbumLabel setText:[self verbum]];
    
    float minAngle = [[Sun sharedObject] minAngle];
    float maxAngle = [[Sun sharedObject] maxAngle];
    
    float minC = minAngle / 360;
    float maxC = maxAngle / 360;
    
    [innerCircle setStrokeStart:.5 + minC];
    [innerCircle setStrokeEnd:.5 + maxC];
    
    [self.view.layer setBackgroundColor:[self wantedBackgroundColor].CGColor];
    [sun setStrokeColor:[self wantedBackgroundColor].CGColor];
    [sun setFillColor:[self wantedForegreoundColor].CGColor];
    
    handSolid.strokeColor = handDashed.strokeColor = centerline.strokeColor = innerCircle.strokeColor = outerCircle.strokeColor = [self wantedForegreoundColor].CGColor;
    
    hourLabel.textColor = angleLabel.textColor = verbumLabel.textColor = [self wantedForegreoundColor];
}

@end
