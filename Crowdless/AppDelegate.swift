//
//  PlaceListViewController.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/20/15.
//  Copyright © 2015 Crowdless, inc. All rights reserved.
//

import UIKit

import Parse
import FBSDKCoreKit
import ParseFacebookUtilsV4
import CocoaLumberjack

// If you want to use any of the UI components, uncomment this line
// import ParseUI

// If you want to use Crash Reporting - uncomment this line
// import ParseCrashReporting

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    
    var window: UIWindow?
    var previousController: UIViewController? = nil
    
    //--------------------------------------
    // MARK: - UIApplicationDelegate
    //--------------------------------------
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        DDLog.addLogger(DDTTYLogger.sharedInstance()) // TTY = Xcode console
        DDLog.addLogger(DDASLLogger.sharedInstance()) // ASL = Apple System Logs
        
        DDLogInfo("Logging initialized!")
        
        Parse.enableLocalDatastore()
        
        Parse.setApplicationId("oKl91rL1UjJljCDwmi1V5ZE8aF1jtLLPxN3zr1Eo",
            clientKey: "EKTucNdwOrfkmxF0ddw13yRfboU2SfzMRElrbqBk");
        PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)
        
        let defaultACL = PFACL();
        
        // If you would like all objects to be private by default, remove this line.
        defaultACL.setPublicReadAccess(true)
        
        PFACL.setDefaultACL(defaultACL, withAccessForCurrentUser:true)
        
        if application.applicationState != UIApplicationState.Background {
            // Track an app open here if we launch with a push, unless
            // "content_available" was used to trigger a background push (introduced in iOS 7).
            // In that case, we skip tracking here to avoid double counting the app-open.
            
            let preBackgroundPush = !application.respondsToSelector("backgroundRefreshStatus")
            let oldPushHandlerOnly = !self.respondsToSelector("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            var noPushPayload = false;
            if let options = launchOptions {
                noPushPayload = options[UIApplicationLaunchOptionsRemoteNotificationKey] != nil;
            }
            if (preBackgroundPush || oldPushHandlerOnly || noPushPayload) {
                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
            }
        }
        
        //
        //  Swift 2.0
        //
        //        if #available(iOS 8.0, *) {
        //            let types: UIUserNotificationType = [.Alert, .Badge, .Sound]
        //            let settings = UIUserNotificationSettings(forTypes: types, categories: nil)
        //            application.registerUserNotificationSettings(settings)
        //            application.registerForRemoteNotifications()
        //        } else {
        //            let types: UIRemoteNotificationType = [.Alert, .Badge, .Sound]
        //            application.registerForRemoteNotificationTypes(types)
        //        }
        
        if PFUser.currentUser() == nil {
            showLoginScreen()
        } else {
            showCrowdsTrendingViewController()
            //refresh current user
            PFUser.currentUser()!.fetchInBackground()
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions);
        
    }
    
    func showCrowdsTrendingViewController() {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootViewController = mainStoryboard.instantiateViewControllerWithIdentifier("MainTabBarController") as! UITabBarController
        UITabBar.appearance().tintColor = UIColor(red: 116/255, green: 169/255, blue: 255/255, alpha: 1.0)
        UITabBar.appearance().barTintColor = UIColor.blackColor()
        rootViewController.delegate = self
        self.window?.rootViewController = rootViewController
        
        UIView.transitionWithView(self.window!, duration: 0.5, options: UIViewAnimationOptions.TransitionFlipFromLeft, animations: { () -> Void in
            self.window?.rootViewController = rootViewController
            }, completion: nil)
    }
    
    func tabBarController(tabBarController: UITabBarController, didSelectViewController viewController: UIViewController) {
        if let navigationController = viewController as? UINavigationController {
            navigationController.popToRootViewControllerAnimated(true)
        }
        
        if let navigationController = viewController as? UINavigationController {
            if navigationController.viewControllers.count == 1 {
                let rootViewController = navigationController.viewControllers.first
                if let crowdSearchControllerDismissable = rootViewController as? CrowdSearchControllerDismissable {
                    crowdSearchControllerDismissable.dismissSearchController()
                }
                if previousController == viewController {
                    if let scrollableToTopViewController = rootViewController as? ScrollableToTop {
                        scrollableToTopViewController.scrollToTop()
                    }
                }
            }
        } else if let scrollableToTopViewController = viewController as? ScrollableToTop {
            scrollableToTopViewController.scrollToTop()
        }
        
        previousController = viewController
    }
    
    func showLoginScreen() {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let welcomeViewController = mainStoryboard.instantiateViewControllerWithIdentifier("welcomeViewController") as! WelcomeViewController
        self.window?.rootViewController = welcomeViewController
        UIView.transitionWithView(self.window!, duration: 0.5, options: UIViewAnimationOptions.TransitionFlipFromRight, animations: { () -> Void in
            self.window?.rootViewController = welcomeViewController
            }, completion: nil)
    }
    
    func logout() {
        PFUser.logOut()
        showLoginScreen();
    }
    
    //--------------------------------------
    // MARK: Push Notifications
    //--------------------------------------
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        installation.saveInBackground()
        
        PFPush.subscribeToChannelInBackground("") { (succeeded: Bool, error: NSError?) in
            if succeeded {
                DDLogDebug("CrowdList successfully subscribed to push notifications on the broadcast channel.\n");
            } else {
                DDLogError("CrowdList failed to subscribe to push notifications on the broadcast channel with error = " + (error?.description)!)
            }
        }
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if error.code == 3010 {
            DDLogError("Push notifications are not supported in the iOS Simulator.\n")
        } else {
            DDLogError("application:didFailToRegisterForRemoteNotificationsWithError: " + error.description)
        }
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        PFPush.handlePush(userInfo)
        if application.applicationState == UIApplicationState.Inactive {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }
    }
    
    ///////////////////////////////////////////////////////////
    // Uncomment this method if you want to use Push Notifications with Background App Refresh
    ///////////////////////////////////////////////////////////
    // func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
    //     if application.applicationState == UIApplicationState.Inactive {
    //         PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
    //     }
    // }
    
    func application(application: UIApplication,
        openURL url: NSURL,
        sourceApplication: String?,
        annotation: AnyObject) -> Bool {
            return FBSDKApplicationDelegate.sharedInstance().application(
                application,
                openURL: url,
                sourceApplication: sourceApplication,
                annotation: annotation)
    }
    
    
    //Make sure it isn't already declared in the app delegate (possible redefinition of func error)
    func applicationDidBecomeActive(application: UIApplication) {
        FBSDKAppEvents.activateApp()
    }
}
