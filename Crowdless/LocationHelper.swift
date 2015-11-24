//
//  LocationHelper.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/24/15.
//  Copyright © 2015 Parse. All rights reserved.
//

import Parse
import CocoaLumberjack

class LocationHelper {
    
    static let sharedInstance = LocationHelper()
    private var userGeoPoint: PFGeoPoint?
    private var lastUpdated: NSDate?
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();
    private let recentUpdateThresholdSeconds = 300 // five minutes
    
    private init() {}
    
    func getRecentUserLocationInBackground(completion: (PFGeoPoint?, error: NSError?) -> Void) {
        
        if let lastUpdated = lastUpdated {
            
            let lastUpdatedTimeComponents = currentCalendar.components([.Second], fromDate: lastUpdated)
            let currentTimeComponents = currentCalendar.components([.Second], fromDate: NSDate())

            if ((currentTimeComponents.second - lastUpdatedTimeComponents.second) >= recentUpdateThresholdSeconds) {
                retrieveLocationInBackground(completion)
            } else {
                completion(userGeoPoint!, error: nil)
            }
        } else {
            retrieveLocationInBackground(completion)
        }
    }
    
    private func retrieveLocationInBackground(completion: (PFGeoPoint?, error: NSError?) -> Void) {
        PFGeoPoint.geoPointForCurrentLocationInBackground { (
            geoPoint, error) -> Void in
            if let geoPoint = geoPoint {
                self.userGeoPoint = geoPoint
                self.lastUpdated = NSDate()
                completion(geoPoint, error: nil)
            } else {
                completion(nil, error: error)
                DDLogError("Could not obtain user location \(error!.localizedDescription)")
            }
        }
    }
}
