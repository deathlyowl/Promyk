//
//  Promyk
//
//  Created by Paweł Ksieniewicz on 04.04.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import <Availability.h>
#import <UIKit/UIKit.h>

#define LINE_WIDTH 8
#define SMALL_UNIT 20
#define BIG_UNIT 80
#define DASH_PATTERN @[@LINE_WIDTH,@LINE_WIDTH]
#define ANIMATION_DURATION 1
#define YELLOW [UIColor colorWithHue:0.16f saturation:0.51f brightness:1.00f alpha:1.00f]
#define FONT [UIFont fontWithName:@"ModernSans" size:50]

@interface DOAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end

@interface DOViewController : UIViewController

@end

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DOAppDelegate class]));
    }
}

@implementation DOAppDelegate

@synthesize window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [application setStatusBarHidden:YES];
    
    application.idleTimerDisabled = YES;    // Do not fall asleep
    
    // Generate and show view
    window = UIWindow.new;
    window.frame = UIScreen.mainScreen.bounds;
    window.rootViewController = DOViewController.new;
    
    [window setClipsToBounds:YES];
    
    // Initialize location manager
    /*
     locationManager = CLLocationManager.new;
     
     locationManager.delegate = self;
     locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
     
     [self.window makeKeyAndVisible];
     [self locate];
     */
    
    // Override point for customization after application launch.
    return YES;
}

@end

@interface DOViewController ()
{
    CAShapeLayer *handSolid, *handDashed, *innerCircle, *outerCircle;
    UILabel *hourLabel, *angleLabel, *verbumLabel;
}

@end

@implementation DOViewController

double degreesToRadians(double degrees){return degrees * M_PI / 180;}
double radiansToDegrees(double radians){return radians * 180 / M_PI;}

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
