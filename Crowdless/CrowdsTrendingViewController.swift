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
import MPCoachMarks

public let ErrorDomain: String! = "CrowdsTrendingViewControllerErrorDomain"

class CrowdsTrendingViewController: UIViewController, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate, UITableViewDataSource {
    
    @IBOutlet var crowdsTableView: UITableView!
    
    private var refreshControl:UIRefreshControl!
    private var isLoadingPlaces = false
    private var userGeoPoint: PFGeoPoint?
    private var trendingScores = [PFObject]()
    private var filteredPlaces = [Place]()
    private let resultsPageLimit = 10
    private var currentPage = 0
    private let pageLimit = 3
    private var reachability: Reachability?
    private let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .White)
    private let googlePlacesHelper = GooglePlacesHelper()
    private var searchController:UISearchController!
    private var searchResultsController: UITableViewController!
    
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
        
        if !definesPresentationContext {
            definesPresentationContext = true
        }
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadingSpinner.startAnimating()
                loadInitialPlaces();
            }
        }
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let coachMarksShown = NSUserDefaults.standardUserDefaults().boolForKey("CrowdsTrendingTutorialShown")
        if coachMarksShown == false {
            displayCoachMarks()
        }        
    }
    
    override func viewWillDisappear(animated: Bool) {
        definesPresentationContext = false
        super.viewWillDisappear(animated)
    }
    
    private func displayCoachMarks() {
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "CrowdsTrendingTutorialShown")
        NSUserDefaults.standardUserDefaults().synchronize()
        let searchCoachMark = navigationController!.navigationBar.frame
        let crowdsTableFrame = crowdsTableView.frame
        let crowdsTableMark = CGRect(origin: crowdsTableView.frame.origin, size: CGSize(width: crowdsTableFrame.width, height: 180))
        let coachMarks = [["rect": NSValue(CGRect: crowdsTableMark), "caption": "Browse Trending Crowds Around You...", "showArrow": true], ["rect": NSValue(CGRect: searchCoachMark), "caption": "... Or Search For Nearby Crowds!", "showArrow": true]]
        let coachMarksView = MPCoachMarks(frame: navigationController!.view.bounds, coachMarks: coachMarks)
        coachMarksView.maskColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.9)
        coachMarksView.lblCaption.font = UIFont(name:"Comfortaa", size: 24)
        navigationController!.view.addSubview(coachMarksView)
        coachMarksView.start()
    }
    
    private func initView() {
        
        self.navigationController?.navigationBar.barTintColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.navigationController?.navigationBar.barStyle = UIBarStyle.Black
        
        UINavigationBar.appearance().tintColor = UIColor.whiteColor()
        UITextField.appearance().keyboardAppearance = .Dark
        
        initSearchController()
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to Refresh",
            attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        crowdsTableView.addSubview(refreshControl)
        crowdsTableView.backgroundColor = UIColor.clearColor()
        
        searchResultsController.tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        var frame: CGRect = loadingSpinner.frame
        frame.origin.x = (self.view.frame.size.width / 2 - frame.size.width / 2)
        frame.origin.y = (self.view.frame.size.height / 2 - frame.size.height / 2)
        loadingSpinner.frame = frame
        view.addSubview(loadingSpinner)
    }
    
    private func initSearchController() {
        
        searchResultsController = UITableViewController()
        searchResultsController.tableView.backgroundColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0)
        searchController = UISearchController(searchResultsController: searchResultsController)
        searchResultsController.tableView.rowHeight = 50
        
        searchResultsController.tableView.registerNib(UINib(nibName: "PoweredByGoogleTableViewCell", bundle: nil), forCellReuseIdentifier: "poweredByGoogleCell")
        searchResultsController.tableView.registerNib(UINib(nibName: "GooglePlaceTableViewCell", bundle: nil), forCellReuseIdentifier: "googlePlaceCell")
        
        let textFieldInsideSearchBar = searchController.searchBar.valueForKey("searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.whiteColor()
        searchController.searchBar.sizeToFit()
        searchController.searchBar.placeholder = "Search for crowds..."
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.dimsBackgroundDuringPresentation = true
        searchController.searchBar.searchBarStyle = .Minimal
        navigationItem.titleView = searchController.searchBar
        definesPresentationContext = true
        
        searchController.searchResultsUpdater = self
        searchResultsController.tableView.dataSource = self
        searchResultsController.tableView.delegate = self
        searchController.searchBar.delegate = self
        
        searchController.loadViewIfNeeded() // iOS 9 bug with search controller
        
    }
    
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        if let reachability = reachability {
            if(reachability.isReachable()) {
                googlePlacesHelper.getPlacesInBackgroundWithBlock(searchController.searchBar.text!, userGeoPoint: userGeoPoint,
                    results: { placesPredictions -> () in
                        self.filteredPlaces = placesPredictions
                        self.searchResultsController.tableView.reloadData()
                })
            }
        }
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
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
        if tableView == searchResultsController.tableView {
            return filteredPlaces.count + 1
        } else {
            return 1
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if tableView == searchResultsController.tableView {
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
        if tableView == searchResultsController.tableView {
            return 0
        } else {
            return 10;
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if tableView == searchResultsController.tableView {
            return nil
        } else {
            let view = UIView()
            view.backgroundColor = UIColor.clearColor()
            return view
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if (tableView == crowdsTableView && trendingScores.count == 0) {
            let cell = UITableViewCell()
            cell.textLabel!.text = "Search For Crowds Above"
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.textAlignment = .Center;
            return cell
        }
        
        var cell: UITableViewCell
        if tableView == searchResultsController.tableView {
            if indexPath.row == filteredPlaces.count {
                cell = searchResultsController.tableView.dequeueReusableCellWithIdentifier("poweredByGoogleCell")!
            } else {
                cell = searchResultsController.tableView.dequeueReusableCellWithIdentifier("googlePlaceCell")!
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
        if tableView == searchResultsController.tableView && indexPath.row != filteredPlaces.count {
            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let destination: CrowdScoreViewController = storyboard.instantiateViewControllerWithIdentifier("CrowdScoreViewController")
                as! CrowdScoreViewController
            let index = indexPath.row
            let filteredPlace = self.filteredPlaces[index]
            destination.googlePlace = filteredPlace
            navigationController!.pushViewController(destination, animated: true)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showCrowdScoreView", let destination = segue.destinationViewController as? CrowdScoreViewController {
            let index = crowdsTableView.indexPathForSelectedRow!.section
            let trendingScore = trendingScores[index]
            let place = trendingScore["place"] as! PFObject
            let googlePlace = Place(prediction: ["place_id": place["googlePlaceId"] as! String, "description": ""])
            destination.googlePlace = googlePlace
            destination.place = place;
            destination.crowdScore = trendingScore
            
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
                self.userGeoPoint = geoPoint
                // Create a query for places
                let innerQuery = PFQuery(className:"Place")
                // Interested in locations near user.
                innerQuery.whereKey("coordinates", nearGeoPoint: geoPoint, withinMiles: 5)
                let query = PFQuery(className: "CrowdScore")
                query.whereKey("place", matchesQuery: innerQuery)
                query.includeKey("place")
                query.orderByDescending("recentUserScoreCount")
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
                        
                        DDLogError("Could not load first crowd results \(error!.localizedDescription)")
                        let alert = UIAlertController(title: "Error", message: "Could not load first crowd results!", preferredStyle: UIAlertControllerStyle.Alert)
                        alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                        self.presentViewController(alert, animated: true, completion: nil)
                    }
                    
                })
            } else {
                self.isLoadingPlaces = false;
                DDLogError("Could not obtain user location \(error!.localizedDescription)")
            }
        }
    }
    
    private func loadAdditionalPlaces() {
        
        if (!isLoadingPlaces) {
            self.isLoadingPlaces = true
            let innerQuery = PFQuery(className:"Place")
            // Interested in locations near user.
            innerQuery.whereKey("coordinates", nearGeoPoint: self.userGeoPoint!, withinMiles: 5)
            let query = PFQuery(className: "CrowdScore")
            query.whereKey("place", matchesQuery: innerQuery)
            query.includeKey("place")
            query.orderByDescending("recentUserScoreCount")
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
                    
                    DDLogError("Could not additional first crowd results \(error!.localizedDescription)")
                    let alert = UIAlertController(title: "Error", message: "Could not additional first crowd results.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                }
            })
        }
        
    }
}
