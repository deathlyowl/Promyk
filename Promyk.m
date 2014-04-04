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

struct timePair {double dusk, dawn;};

#pragma mark - C Functions
double degreesToRadians(double degrees)
{
    return degrees * M_PI / 180;
}

double radiansToDegrees(double radians)
{
    return radians * 180 / M_PI;
}

double approx(double angle, int julianCycle)
{
    return JULIAN_2000_JANUARY_1_NOON - angle / 360 + julianCycle;
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
{
    CLLocationManager *locationManager;
}

@property (strong, nonatomic) UIWindow *window;

@end

@interface ViewController : UIViewController
{
    CAShapeLayer *handSolid, *handDashed, *innerCircle, *outerCircle;
    UILabel *hourLabel, *angleLabel, *verbumLabel;
}

@end

@interface Sun : NSObject

@property (nonatomic) double sunset;
@property (nonatomic) double sunrise;

@property (nonatomic) double noon;

@property (nonatomic) double longitude;
@property (nonatomic) double latitude;

@property (nonatomic) struct timePair astro;
@property (nonatomic) struct timePair navi;
@property (nonatomic) struct timePair civil;

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

@implementation AppDelegate

@synthesize window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarHidden:YES];
    
    application.idleTimerDisabled = YES;    // Do not fall asleep
    
    // Generate and show view
    window = UIWindow.new;
    window.frame = UIScreen.mainScreen.bounds;
    window.rootViewController = ViewController.new;
    
    [window setClipsToBounds:YES];
    
    // Initialize location manager
    locationManager = CLLocationManager.new;
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    [self locate];
    
    return YES;
}

- (void) locate
{
    double longitude = [[NSUserDefaults.standardUserDefaults objectForKey:@"longitude"] doubleValue];
    double latitude = [[NSUserDefaults.standardUserDefaults objectForKey:@"longitude"] doubleValue];
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
    NSLog(@"Located!");
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

@synthesize sunrise, sunset, noon, astro, navi, civil,longitude, latitude, isLocated, stage;

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

- (void)calculate{
    // Julian cycle
    int julianCycle = [[NSDate date] julianCycleForLongitude:longitude];
    
    
    // Solar Noon
    noon = approx(longitude, julianCycle);
    double anomaly = solarMeanAnomaly(noon), center = equationOfCenter(anomaly), lambda = eclipticLongitude(anomaly,center);
    
    
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
    
    
    
    // Sunset
    sunset = lastTouchTime + (0.0053 * sin(degreesToRadians(anomaly)) - (0.0069 * sin(2 * lambda)));
    sunrise = noon - ( sunset - noon );
    
    
    astro.dawn = lastAstroTime + (0.0053 * sin(degreesToRadians(anomaly)) - (0.0069 * sin(2* lambda)));
    astro.dusk = noon - (astro.dawn - noon);
    
    navi.dawn = lastNaviTime + (0.0053 * sin(degreesToRadians(anomaly)) - (0.0069 * sin(2* lambda)));
    navi.dusk = noon - (navi.dawn - noon);
    
    civil.dawn = lastCivilTime + (0.0053 * sin(degreesToRadians(anomaly)) - (0.0069 * sin(2* lambda)));
    civil.dusk = noon - (civil.dawn - noon);
    NSLog(@"civil: %f | %f | %f", civil.dusk, latitude, delta);
    
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
	// Do any additional setup after loading the view, typically from a nib.
    [self configure];
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
    
    [hourLabel setText:[NSString stringWithFormat:@"%i%@%02i", hour, separator, minute]];
    
    [self setSeconds:second];
}

- (void) configure
{
    // Preparations
    [self.view.layer setCornerRadius:20];
    [self.view setBackgroundColor:YELLOW];
    CGMutablePathRef path;
    
    // Centerline
    CAShapeLayer *centerline = [CAShapeLayer layer];
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
    CAShapeLayer *sun = [CAShapeLayer layer];
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
    [self setAngle];
    [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES] fire];
}

- (void) setSeconds:(int) seconds
{
    [outerCircle setStrokeStart:0];
    [outerCircle setStrokeEnd:(float)seconds/59.];
    if (seconds == 0) [self setAngle];
}

- (void) setAngle
{
    float angle = degreesToRadians((double)(rand() % 90)-45);
    
    [CATransaction setAnimationDuration:ANIMATION_DURATION];
    CATransform3D transform = CATransform3DMakeRotation(angle, 0, 0, 1);
    
    handSolid.transform = transform;
    handDashed.transform = transform;
    [angleLabel setText:[NSString stringWithFormat:@"%.0f°", radiansToDegrees(angle)]];
    
    [angleLabel.layer setFrame:CGRectMake(angle > 0 ? BIG_UNIT+10 : BIG_UNIT,
                                          angle > 0 ? 3*BIG_UNIT + SMALL_UNIT : 2*BIG_UNIT + SMALL_UNIT,
                                          2*BIG_UNIT,
                                          2.5*SMALL_UNIT)];
    
    [verbumLabel setText:@"twilight in 15"];
    
    float minAngle = -35;
    float maxAngle = 45;
    
    float minC = minAngle / 360;
    float maxC = maxAngle / 360;
    
    [innerCircle setStrokeStart:.5 + minC];
    [innerCircle setStrokeEnd:.5 + maxC];
}

@end
