//
//  DOAppDelegate.m
//  Promyk
//
//  Created by Paweł Ksieniewicz on 04.04.2014.
//  Copyright (c) 2014 Deathly Owl. All rights reserved.
//

#import "DOAppDelegate.h"
#import "DOViewController.h"

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
