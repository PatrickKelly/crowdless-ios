//
//  PlaceListViewController.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/20/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import ReachabilitySwift
import CocoaLumberjack

public let ErrorDomain: String! = "CrowdsTrendingViewControllerErrorDomain"

class CrowdsTrendingViewController: UIViewController, UITableViewDelegate, UISearchBarDelegate, UITableViewDataSource {
    
    @IBOutlet var crowdsTableView: UITableView!
    
    private var refreshControl:UIRefreshControl!
    private var isLoadingPlaces = false;
    private var userGeoPoint: PFGeoPoint!;
    private var trendingScores = [PFObject]();
    private var filteredPlaces = [Place]();
    private let resultsPageLimit = 10;
    private var currentPage = 0;
    private let pageLimit = 5;
    private let apiKey = "AIzaSyC_Ydzgdq62x0XXgy6vMp8p3aNs6PlOh0M";
    private var reachability: Reachability?
    private let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .White)
    
    var locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch {
            DDLogError("Unable to create Reachability")
            return
        }
        
        initView();
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = crowdsTableView.indexPathForSelectedRow {
            crowdsTableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    private func initView() {
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        self.navigationController!.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.navigationBar.barStyle = UIBarStyle.Black
        
        UINavigationBar.appearance().tintColor = UIColor.whiteColor()
        
        self.searchDisplayController!.searchResultsTableView.rowHeight = 60
        (UIBarButtonItem.appearanceWhenContainedInInstancesOfClasses([UISearchBar.self])).tintColor = UIColor.whiteColor()
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to Refresh",
            attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        crowdsTableView.addSubview(refreshControl)
        crowdsTableView.backgroundColor = UIColor.clearColor()
        
        var frame: CGRect = loadingSpinner.frame
        frame.origin.x = (self.view.frame.size.width / 2 - frame.size.width / 2)
        frame.origin.y = (self.view.frame.size.height / 2 - frame.size.height / 2)
        loadingSpinner.frame = frame
        view.addSubview(loadingSpinner)
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadingSpinner.startAnimating()
                loadInitialPlaces();
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    func refresh(sender:AnyObject)
    {
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadInitialPlaces();
            } else {
                refreshControl.endRefreshing()
            }
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return filteredPlaces.count + 1
        } else {
            return 1
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return 1
        } else {
            
            if (isLoadingPlaces) {
                return 0;
            }
            
            if (trendingScores.count == 0) {
                return 1;
            } else {
                return trendingScores.count
            }
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return 0
        } else {
            return 10;
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if tableView == self.searchDisplayController!.searchResultsTableView {
            return nil
        } else {
            let view = UIView()
            view.backgroundColor = UIColor.clearColor()
            return view
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if (tableView == crowdsTableView && trendingScores.count == 0) {
            let cell: UITableViewCell = UITableViewCell()
            cell.textLabel!.text = "Search For Crowds Above"
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.textAlignment = .Center;
            return cell
        }
        
        var cell: UITableViewCell
        if tableView == self.searchDisplayController!.searchResultsTableView {
            if indexPath.row == filteredPlaces.count {
                cell = self.crowdsTableView.dequeueReusableCellWithIdentifier("googleCell")!
            } else {
                cell = self.crowdsTableView.dequeueReusableCellWithIdentifier("searchCrowdCell")!
                cell.textLabel?.textColor = UIColor.whiteColor()
                cell.detailTextLabel?.textColor = UIColor.whiteColor()
                let place = filteredPlaces[indexPath.row]
                cell.textLabel!.text = place.name
                cell.detailTextLabel?.text = place.detail
            }
        } else {
            cell = self.crowdsTableView.dequeueReusableCellWithIdentifier("trendingCrowdCell", forIndexPath: indexPath)
            if trendingScores.count >= indexPath.section {
                
                let trendingCrowdCell = cell as! TrendingCrowdCell
                cell.contentView.backgroundColor = UIColor.clearColor()
                cell.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
                
                let trendingScore = trendingScores[indexPath.section]
                let place = trendingScore["place"]
                trendingCrowdCell.name.text = place["name"] as? String
                trendingCrowdCell.detail.text = place["detail"] as? String
                setTrendingCrowdScoreImagesForCell(trendingScore, cell: trendingCrowdCell)
                cell = trendingCrowdCell
                
                // See if we need to load more places
                if (currentPage < pageLimit) {
                    let rowsToLoadFromBottom = resultsPageLimit;
                    let rowsLoaded = trendingScores.count
                    if (!self.isLoadingPlaces && (indexPath.section >= (rowsLoaded - rowsToLoadFromBottom)))
                    {
                        if let reachability = reachability {
                            if(reachability.isReachable()) {
                                loadAdditionalPlaces();
                            }
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchString searchString: String?) -> Bool {
        controller.searchResultsTableView.backgroundColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        controller.searchResultsTableView.bounces = false
        if let reachability = reachability {
            if(reachability.isReachable()) {
                getPlaces(searchString!)
            }
        }
        
        return true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showCrowdScoreView", let destination = segue.destinationViewController as? CrowdScoreViewController {
            let index = crowdsTableView.indexPathForSelectedRow!.section
            let trendingScore = trendingScores[index]
            let place = trendingScore["place"] as! PFObject
            let googlePlace = Place(prediction: ["place_id": place["googlePlaceId"] as! String, "description": ""],
                apiKey: self.apiKey)
            destination.googlePlace = googlePlace
            destination.place = place;
            destination.crowdScore = trendingScore
            
        } else if segue.identifier == "showCrowdScoreViewFromSearch", let destination = segue.destinationViewController as? CrowdScoreViewController  {
            if self.searchDisplayController!.active {
                let index = self.searchDisplayController!.searchResultsTableView.indexPathForSelectedRow!.row
                let filteredPlace = self.filteredPlaces[index]
                destination.googlePlace = filteredPlace
                self.searchDisplayController!.active = false
            }
        }
        
    }
    
    private func setTrendingCrowdScoreImagesForCell(trendingScore: PFObject, cell: TrendingCrowdCell) {
        
        let trendingScoreImages = [cell.trendingScoreFirstImage, cell.trendingScoreSecondImage, cell.trendingScoreThirdImage]
        var index = 0
        
        //clear the images first
        for trendingScoreImage in trendingScoreImages {
            trendingScoreImage.image = nil
        }
        
        if let crowded = trendingScore["crowded"] as? Int {
            if(crowded >= 0 && crowded < 2) {
                cell.scoreImage.image = UIImage(named: "people-green")
            } else if (crowded >= 2 && crowded < 4) {
                cell.scoreImage.image = UIImage(named: "people-yellow")
            } else if (crowded >= 4) {
                cell.scoreImage.image = UIImage(named: "people-red")
            } else {
                cell.scoreImage.image = UIImage(named: "people-green")
            }
        }
        
        if let waitTime = trendingScore["waitTime"] as? Int {
            let waitTimeImage = trendingScoreImages[index]
            if(waitTime > 0 && waitTime < 2) {
                waitTimeImage.image = UIImage(named: "clock-green")
                index++
            } else if (waitTime >= 2 && waitTime < 4) {
                waitTimeImage.image = UIImage(named: "clock-yellow")
                index++
            } else if (waitTime >= 4) {
                waitTimeImage.image = UIImage(named: "clock-red")
                index++
            }
        }
        
        if let coverCharge = trendingScore["coverCharge"] as? Int {
            let coverChargeImage = trendingScoreImages[index]
            if(coverCharge > 0 && coverCharge < 2) {
                coverChargeImage.image = UIImage(named: "money-green")
                index++
            } else if (coverCharge >= 2 && coverCharge < 4) {
                coverChargeImage.image = UIImage(named: "money-yellow")
                index++
            } else if (coverCharge >= 4) {
                coverChargeImage.image = UIImage(named: "money-red")
                index++
            }
        }
        
        if let parking = trendingScore["parkingDifficult"] as? Int {
            let userParkingImage = trendingScoreImages[index]
            if(parking >= 0 && parking < 2) {
                userParkingImage.image = UIImage(named: "car-green")
            } else if (parking >= 2 && parking < 4) {
                userParkingImage.image = UIImage(named: "car-yellow")
            } else if (parking >= 4) {
                userParkingImage.image = UIImage(named: "car-red")
            } else {
                userParkingImage.image = UIImage(named: "car-green")
            }
        }
    }
    
    private func loadInitialPlaces() {
        isLoadingPlaces = true
        PFGeoPoint.geoPointForCurrentLocationInBackground {
            (geoPoint: PFGeoPoint?, error: NSError?) -> Void in
            if let geoPoint = geoPoint {
                self.userGeoPoint = PFGeoPoint(latitude: 32.7833, longitude: -79.9333);
                // Create a query for places
                let innerQuery = PFQuery(className:"Place")
                // Interested in locations near user.
                innerQuery.whereKey("coordinates", nearGeoPoint: self.userGeoPoint, withinMiles: 10)
                let query = PFQuery(className: "TrendingCrowdScore")
                query.whereKey("place", matchesQuery: innerQuery)
                query.includeKey("place")
                query.orderByDescending("updatedAt")
                query.limit = self.resultsPageLimit
                // Final list of objects
                query.findObjectsInBackgroundWithBlock({ (
                    trendingScores, error: NSError?) -> Void in
                    if let trendingScores = trendingScores {
                        self.trendingScores = trendingScores;
                        self.currentPage++;
                        self.isLoadingPlaces = false
                        self.crowdsTableView.reloadData()
                        
                        if(self.refreshControl.refreshing) {
                            self.refreshControl.endRefreshing()
                        }
                        
                        if(self.loadingSpinner.isAnimating()) {
                            self.loadingSpinner.stopAnimating()
                        }
                    } else {
                        self.isLoadingPlaces = false
                        
                        if(self.refreshControl.refreshing) {
                            self.refreshControl.endRefreshing()
                        }
                        
                        if(self.loadingSpinner.isAnimating()) {
                            self.loadingSpinner.stopAnimating()
                        }
                        
                        let alert = UIAlertController(title: "Error", message: "Could not load first crowd results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    
                })
            } else {
                self.isLoadingPlaces = false;
                let alert = UIAlertController(title: "Error", message: "Could not obtain user location \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func loadAdditionalPlaces() {
        
        if (!isLoadingPlaces) {
            self.isLoadingPlaces = true
            let innerQuery = PFQuery(className:"Place")
            // Interested in locations near user.
            innerQuery.whereKey("coordinates", nearGeoPoint: self.userGeoPoint, withinMiles: 10)
            let query = PFQuery(className: "TrendingCrowdScore")
            query.whereKey("place", matchesQuery: innerQuery)
            query.includeKey("place")
            query.orderByDescending("updatedAt")
            query.limit = self.resultsPageLimit
            query.skip = currentPage * resultsPageLimit;
            // Final list of objects
            query.findObjectsInBackgroundWithBlock({ (
                trendingScores, error: NSError?) -> Void in
                if let trendingScores = trendingScores {
                    self.trendingScores = self.trendingScores + trendingScores;
                    self.currentPage++;
                    self.isLoadingPlaces = false
                    self.crowdsTableView.reloadData()
                    
                    if(self.refreshControl.refreshing) {
                        self.refreshControl.endRefreshing()
                    }
                    
                    if(self.loadingSpinner.isAnimating()) {
                        self.loadingSpinner.stopAnimating()
                    }
                    
                } else {
                    self.isLoadingPlaces = false
                    
                    if(self.refreshControl.refreshing) {
                        self.refreshControl.endRefreshing()
                    }
                    
                    if(self.loadingSpinner.isAnimating()) {
                        self.loadingSpinner.stopAnimating()
                    }
                    
                    let alert = UIAlertController(title: "Error", message: "Could not load first crowd results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                }
            })
        }
        
    }
    
    private func getPlaces(searchString: String) {
        var params = [
            "input": searchString,
            "types": "establishment",
            "key": apiKey
        ]
        
        params["location"] = "\(userGeoPoint.latitude),\(userGeoPoint.longitude)"
        params["radius"] = "25000"
        
        if (searchString == ""){
            return
        }
        
        GooglePlacesRequestHelpers.doRequest(
            "https://maps.googleapis.com/maps/api/place/autocomplete/json",
            params: params
            ) { json, error in
                if let json = json{
                    if let predictions = json["predictions"] as? Array<[String: AnyObject]> {
                        self.filteredPlaces = predictions.map { (prediction: [String: AnyObject]) -> Place in
                            return Place(prediction: prediction, apiKey: self.apiKey)
                        }
                        self.searchDisplayController!.searchResultsTableView.reloadData()
                    }
                }
        }
    }
    
}

class GooglePlaceDetailsRequest {
    let place: Place
    
    init(place: Place) {
        self.place = place
    }
    
    func request(result: PlaceDetails -> ()) {
        GooglePlacesRequestHelpers.doRequest(
            "https://maps.googleapis.com/maps/api/place/details/json",
            params: [
                "placeid": place.id,
                "key": place.apiKey ?? ""
            ]
            ) { json, error in
                if let json = json as? [String: AnyObject] {
                    result(PlaceDetails(json: json))
                }
                if let error = error {
                    // TODO: We should probably pass back details of the error
                    DDLogError("Error fetching google place details: \(error)")
                }
        }
    }
}

class GooglePlacesRequestHelpers {
    /**
     Build a query string from a dictionary
     - parameter parameters: Dictionary of query string parameters
     - returns: The properly escaped query string
     */
    private class func query(parameters: [String: AnyObject]) -> String {
        var components: [(String, String)] = []
        for key in Array(parameters.keys).sort(<) {
            let value: AnyObject! = parameters[key]
            components += [(escape(key), escape("\(value)"))]
        }
        
        return (components.map{"\($0)=\($1)"} as [String]).joinWithSeparator("&")
    }
    
    private class func escape(string: String) -> String {
        let legalURLCharactersToBeEscaped: CFStringRef = ":/?&=;+!@#$()',*"
        return CFURLCreateStringByAddingPercentEscapes(nil, string, nil, legalURLCharactersToBeEscaped, CFStringBuiltInEncodings.UTF8.rawValue) as String
    }
    
    private class func doRequest(url: String, params: [String: String], completion: (NSDictionary?,NSError?) -> ()) {
        let request = NSMutableURLRequest(
            URL: NSURL(string: "\(url)?\(query(params))")!
        )
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            self.handleResponse(data, response: response as? NSHTTPURLResponse, error: error, completion: completion)
        }
        
        task.resume()
    }
    
    private class func handleResponse(data: NSData!, response: NSHTTPURLResponse!, error: NSError!, completion: (NSDictionary?, NSError?) -> ()) {
        
        // Always return on the main thread...
        let done: ((NSDictionary?, NSError?) -> Void) = {(json, error) in
            dispatch_async(dispatch_get_main_queue(), {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                completion(json,error)
            })
        }
        
        if let error = error {
            DDLogError("GooglePlaces Error: \(error.localizedDescription)")
            done(nil,error)
            return
        }
        
        if response == nil {
            DDLogError("GooglePlaces Error: No response from API")
            let error = NSError(domain: ErrorDomain, code: 1001, userInfo: [NSLocalizedDescriptionKey:"No response from API"])
            done(nil,error)
            return
        }
        
        if response.statusCode != 200 {
            DDLogError("GooglePlaces Error: Invalid status code \(response.statusCode) from API")
            let error = NSError(domain: ErrorDomain, code: response.statusCode, userInfo: [NSLocalizedDescriptionKey:"Invalid status code"])
            done(nil,error)
            return
        }
        
        let json: NSDictionary?
        do {
            json = try NSJSONSerialization.JSONObjectWithData(
                data,
                options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
        } catch {
            DDLogError("Serialisation error")
            let serialisationError = NSError(domain: ErrorDomain, code: 1002, userInfo: [NSLocalizedDescriptionKey:"Serialization error"])
            done(nil,serialisationError)
            return
        }
        
        if let status = json?["status"] as? String {
            if status != "OK" {
                DDLogError("GooglePlaces API Error: \(status)")
                let error = NSError(domain: ErrorDomain, code: 1002, userInfo: [NSLocalizedDescriptionKey:status])
                done(nil,error)
                return
            }
        }
        
        done(json,nil)
        
    }
}

public class Place: NSObject {
    public let id: String
    public let desc: String
    public var apiKey: String?
    public var detail: String?
    public var name: String?
    
    override public var description: String {
        get { return desc }
    }
    
    public init(id: String, description: String) {
        self.id = id
        self.desc = description
    }
    
    public convenience init(prediction: [String: AnyObject], apiKey: String?) {
        self.init(
            id: prediction["place_id"] as! String,
            description: prediction["description"] as! String
        )
        
        if let placeTerms = (prediction["terms"] as? NSArray) as Array? {
            if placeTerms.count >= 4 {
                detail = (placeTerms[1]["value"] as! String) + ", " + (placeTerms[2]["value"] as! String) + ", " + (placeTerms[3]["value"] as! String)
            } else if placeTerms.count >= 3 {
                detail = (placeTerms[1]["value"] as! String) + ", " + (placeTerms[2]["value"] as! String)
            } else if (placeTerms.count == 2) {
                detail = placeTerms[1]["value"] as? String
            } else {
                detail = ""
            }
            
            name = placeTerms[0]["value"] as? String
        }
        
        self.apiKey = apiKey
    }
    
    /**
     Call Google Place Details API to get detailed information for this place
     
     Requires that Place#apiKey be set
     
     - parameter result: Callback on successful completion with detailed place information
     */
    public func getDetails(result: PlaceDetails -> ()) {
        GooglePlaceDetailsRequest(place: self).request(result)
    }
}

public class PlaceDetails: CustomStringConvertible {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let raw: [String: AnyObject]
    
    public init(json: [String: AnyObject]) {
        let result = json["result"] as! [String: AnyObject]
        let geometry = result["geometry"] as! [String: AnyObject]
        let location = geometry["location"] as! [String: AnyObject]
        
        self.name = result["name"] as! String
        self.latitude = location["lat"] as! Double
        self.longitude = location["lng"] as! Double
        self.raw = json
    }
    
    public var description: String {
        return "PlaceDetails: \(name) (\(latitude), \(longitude))"
    }
}
