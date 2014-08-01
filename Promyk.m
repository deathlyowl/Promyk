//
//  Promyk
//
//  Created by Paweł Ksieniewicz on 04.04.2014.
//  Copyright (c) 2014 Paweł Ksieniewicz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Sun.h"

#define LINE_WIDTH 8
#define SMALL_UNIT 20
#define BIG_UNIT 80
#define DASH_PATTERN @[@LINE_WIDTH,@LINE_WIDTH]
#define ANIMATION_DURATION 1
#define YELLOW [UIColor colorWithHue:0.16f saturation:0.51f brightness:1.00f alpha:1.00f]
#define FONT [UIFont fontWithName:@"ModernSans" size:50]
#define INFO_FONT [UIFont fontWithName:@"ModernSans" size:22]


#pragma mark - Classes declarations
@interface AppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic) CLLocationManager *locationManager;

@end

int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

@interface ViewController : UIViewController
{
    CAShapeLayer *handSolid, *handDashed, *innerCircle, *outerCircle, *sun, *centerline;
    UILabel *hourLabel, *angleLabel, *verbumLabel;
    UIButton *infoButton;
}

@end

@interface InfoViewController : UIViewController

@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, retain) UIColor *foregroundColor;

@end

#pragma mark - Class implementations

@implementation InfoViewController

-(void)viewDidLoad
{
    // Stylization
    [self.view.layer setCornerRadius:20];
    [self.view setBackgroundColor:_backgroundColor];
    
    UILabel *infoLabel = [UILabel new];
    [infoLabel setFont:INFO_FONT];
    [infoLabel setTextColor:_foregroundColor];
    
    [infoLabel setFrame:CGRectMake(20, 20, self.view.frame.size.width-40, (self.view.frame.size.height-40)*.75)];
    [infoLabel setNumberOfLines:0];
    
    [infoLabel setText:@"It's a clock with information about current angle of sunrays.\n\nPromyk means a little, warm sunray in polish."];
    
    [self.view addSubview:infoLabel];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(goBack)];
    

    [self.view addGestureRecognizer:tapRecognizer];
}

- (void) goBack
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

@end

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
    NSDateComponents *components = [[NSCalendar currentCalendar]
                                    components:(NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit)
                                        fromDate:[NSDate date]];
    
    [hourLabel setText:[NSString stringWithFormat:@"%li%@%02li",
                        (long)[components hour],
                        [components second] % 2 ? @":" : @".",
                        (long)[components minute]]];
    
    [self setSeconds:[components second]];
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
    hourLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, self.view.frame.size.height/4)];
    verbumLabel = [[UILabel alloc] initWithFrame:CGRectMake(SMALL_UNIT, self.view.frame.size.height*.75, 320 - 2*SMALL_UNIT, self.view.frame.size.height/4)];
    angleLabel = [[UILabel alloc] initWithFrame:CGRectMake(BIG_UNIT+10, 4*BIG_UNIT + SMALL_UNIT, 2*BIG_UNIT, 2.5*SMALL_UNIT)];
    
    hourLabel.font = verbumLabel.font = angleLabel.font = FONT;
    hourLabel.textAlignment = verbumLabel.textAlignment = angleLabel.textAlignment = NSTextAlignmentCenter;
    
    [hourLabel.layer setOpacity:.1];
    
    [verbumLabel setMinimumScaleFactor:.1];
    [verbumLabel setAdjustsFontSizeToFitWidth:YES];
    
    // Info button
    infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [infoButton setTintColor:[self wantedForegreoundColor]];
    [infoButton setCenter:CGPointMake(self.view.frame.size.width - 20, self.view.frame.size.height - 20)];
    [infoButton setAlpha:.2];
    [infoButton addTarget:self
                   action:@selector(showInfoView)
         forControlEvents:UIControlEventTouchUpInside];
    
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
    [self.view addSubview:infoButton];
}

- (void) showInfoView
{
    InfoViewController *infoViewController = [InfoViewController new];
    [infoViewController setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [infoViewController setBackgroundColor:[self wantedForegreoundColor]];
    [infoViewController setForegroundColor:[self wantedBackgroundColor]];
    [self presentViewController:infoViewController
                       animated:YES
                     completion:nil];
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
    
    NSDateFormatter *dateFormatter = NSDateFormatter.new;
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"EN"]];
    [dateFormatter setDateFormat:@"EEEE"];
    return [dateFormatter stringFromDate:NSDate.date];
}

- (void) setAngle
{
    float angle = [[Sun sharedObject] angle];
    
    //angle = 45;
    
    [CATransaction setAnimationDuration:ANIMATION_DURATION];
    CATransform3D transform = CATransform3DMakeRotation(angle * M_PI / 180, 0, 0, 1);
    
    handSolid.transform = transform;
    handDashed.transform = transform;
    [angleLabel setText:[NSString stringWithFormat:@"%.0f°", angle]];
    
    [angleLabel.layer setFrame:CGRectMake(angle > 0 ? BIG_UNIT+10 : BIG_UNIT,
                                          angle > 0 ? self.view.center.y + SMALL_UNIT : self.view.center.y - 3 * SMALL_UNIT,
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
    [infoButton setTintColor:[self wantedForegreoundColor]];
    
    handSolid.strokeColor = handDashed.strokeColor = centerline.strokeColor = innerCircle.strokeColor = outerCircle.strokeColor = [self wantedForegreoundColor].CGColor;
    
    hourLabel.textColor = angleLabel.textColor = verbumLabel.textColor = [self wantedForegreoundColor];
}

@end
