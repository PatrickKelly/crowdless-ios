//
//  CrowdScoreViewController.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/20/15.
//  Copyright © 2015 Reactiv LLC. All rights reserved.
//

import UIKit
import Parse
import ReachabilitySwift
import CocoaLumberjack
import MPCoachMarks

class CrowdScoreViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,
    UISearchResultsUpdating, UISearchBarDelegate {
    
    var googlePlace: Place?
    var place: PFObject?
    var crowdScore: PFObject?
    
    @IBOutlet var crowdScoreSummaryView: UIView!
    
    @IBOutlet var name: UILabel!
    @IBOutlet var detail: UILabel!
    
    @IBOutlet var scoreButton: UIButton!
    @IBOutlet var crowdScoreImage: UIImageView!
    @IBOutlet var crowdScoreFirstImage: UIImageView!
    @IBOutlet var crowdScoreSecondImage: UIImageView!
    @IBOutlet var crowdScoreThirdImage: UIImageView!
    
    @IBOutlet var crowdScoreFirstLabel: UILabel!
    @IBOutlet var crowdScoreSecondLabel: UILabel!
    @IBOutlet var crowdScoreThirdLabel: UILabel!
    
    @IBOutlet var crowdScoreSummarySeparator: UILabel!
    @IBOutlet var crowdScoresTableView: UITableView!
    
    //for Google places search
    private var filteredPlaces = [Place]()
    private var searchResultsController: UITableViewController!
    private var userGeoPoint: PFGeoPoint?
    private var searchController:UISearchController!
    private let googlePlacesHelper = GooglePlacesHelper()
    
    private var refreshControl:UIRefreshControl!
    private var userCrowdScores = [PFObject]()
    private let resultsLimit = 10
    private var currentPage = 0
    private let pageLimit = 5
    private var isLoadingPlace = false
    private var isLoadingCrowdScores = false
    let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();
    private var refreshCrowdScoreTimer: NSTimer?
    
    private let greenColor = UIColor(red: 123/255, green: 191/255, blue: 106/255, alpha: 1.0)
    private let yellowColor = UIColor(red: 254/255, green: 215/255, blue: 0/255, alpha: 1.0)
    private let redColor = UIColor(red: 224/255, green: 64/255, blue: 51/255, alpha: 1.0)
    
    private var reachability: Reachability?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch {
            DDLogError("Unable to create Reachability")
            return
        }
        
        initView()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let coachMarksShown = NSUserDefaults.standardUserDefaults().boolForKey("CrowdScoreTutorialShown")
        if coachMarksShown == false {
            displayCoachMarks()
        }
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
        self.navigationItem.setHidesBackButton(true, animated: true)
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
        self.navigationItem.setHidesBackButton(false, animated: true)
    }
    
    @IBAction func scoreButtonClicked(sender: AnyObject) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let scorecardViewController = storyboard.instantiateViewControllerWithIdentifier("ScorecardViewController") as! ScorecardViewController
        scorecardViewController.crowdScore = crowdScore
        self.presentViewController(scorecardViewController, animated: true, completion: nil)
    }
    override func viewWillAppear(animated: Bool) {
        
        if !definesPresentationContext {
            definesPresentationContext = true
        }
        
        isLoadingPlace = true
        userCrowdScores.removeAll()
        crowdScoresTableView.reloadData()
        
        clearView()
        
        NSTimer.scheduledTimerWithTimeInterval(1, target: self,
            selector: "refreshCrowdScore", userInfo: nil, repeats: false)
        
        super.viewWillAppear(animated);
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadingSpinner.startAnimating()
                isLoadingPlace = true;
                crowdScoresTableView.reloadData()
                if let crowdScore = crowdScore {
                    crowdScore.fetchInBackgroundWithBlock({ (
                        crowdScore, error) -> Void in
                        if (error == nil) {
                            self.crowdScore = crowdScore;
                            self.getPlaceInBackground { (placeResult: PFObject) -> () in
                                self.place = placeResult;
                                self.loadPlace();
                            }
                        }
                    })
                } else {
                    getPlaceInBackground { (placeResult: PFObject) -> () in
                        self.place = placeResult;
                        self.loadPlace();
                    }
                }
            } else {
                crowdScoreImage.hidden = false
                isLoadingPlace = false;
                let alert = UIAlertController(title: "Error", message: "An Internet connection is required to get this crowd score.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
        } else {
            DDLogError("Reachability object is nil.")
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        definesPresentationContext = false
        super.viewWillDisappear(animated)
    }
    
    private func displayCoachMarks() {
        
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "CrowdScoreTutorialShown")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        let crowdScoreSummaryViewFrame = navigationController!.view.convertRect(crowdScoreSummaryView.frame, fromView: crowdScoreSummaryView)
        let crowdScoreSummarySeparatorFrame = navigationController!.view.convertRect(crowdScoreSummarySeparator.frame, fromView: crowdScoreSummarySeparator.superview)
        
        let crowdScoreSummaryMark = CGRect(origin: crowdScoreSummaryViewFrame.origin, size: CGSize(width: crowdScoreSummaryViewFrame.width, height: crowdScoreSummarySeparatorFrame.origin.y - crowdScoreSummaryViewFrame.origin.y))
        
        let crowdScoreButtonMark = CGRect(origin: crowdScoreSummarySeparatorFrame.origin, size: CGSize(width: crowdScoreSummarySeparatorFrame.width, height: (crowdScoreSummaryViewFrame.height + crowdScoreSummaryViewFrame.origin.y) - crowdScoreSummarySeparatorFrame.origin.y))
        
        let recentScoresMark = CGRect(origin: CGPoint(x: crowdScoresTableView.frame.origin.x, y: crowdScoreSummaryViewFrame.height + crowdScoreSummaryViewFrame.origin.y), size: CGSize(width: crowdScoresTableView.frame.width, height: navigationController!.view.frame.height - (crowdScoreSummaryViewFrame.height + crowdScoreSummaryViewFrame.origin.y)))
        
        let coachMarks = [["rect": NSValue(CGRect: crowdScoreSummaryMark), "caption": "View The Crowd Summary For This Place...", "showArrow": true], ["rect": NSValue(CGRect: crowdScoreButtonMark), "caption": "...Score This Crowd...", "showArrow": true], ["rect": NSValue(CGRect: recentScoresMark), "caption": "...And View Other People's Scores!", "showArrow": true, "position": LabelPosition.LABEL_POSITION_TOP.rawValue]]
        let coachMarksView = MPCoachMarks(frame: navigationController!.view.bounds, coachMarks: coachMarks)
        coachMarksView.maskColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.9)
        coachMarksView.lblCaption.font = UIFont(name:"Comfortaa", size: 24)
        navigationController!.view.addSubview(coachMarksView)
        coachMarksView.start()
    }
    
    private func clearView() {
        
        if let place = place {
            name.text = place["name"] as? String
            detail.text = place["detail"] as? String
            crowdScoreImage.hidden = true
        } else if let googlePlace = googlePlace {
            name.text = googlePlace.name
            detail.text = googlePlace.detail
            crowdScoreImage.hidden = true
        }
        
        //clear the images and labels
        crowdScoreFirstImage.image = nil
        crowdScoreSecondImage.image = nil
        crowdScoreThirdImage.image = nil
        crowdScoreFirstLabel.text = ""
        crowdScoreSecondLabel.text = ""
        crowdScoreThirdLabel.text = ""
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == searchResultsController.tableView {
            return filteredPlaces.count + 1
        } else {
            if (isLoadingPlace || isLoadingCrowdScores) {
                return 0;
            }
            
            if(userCrowdScores.count == 0) {
                return 1;
            }
            
            
            return userCrowdScores.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if tableView == searchResultsController.tableView {
            if indexPath.row == filteredPlaces.count {
                let cell = searchResultsController.tableView.dequeueReusableCellWithIdentifier("poweredByGoogleCell")!
                return cell
            } else {
                let cell = searchResultsController.tableView.dequeueReusableCellWithIdentifier("googlePlaceCell")!
                let place = filteredPlaces[indexPath.row]
                cell.textLabel!.text = place.name
                cell.detailTextLabel?.text = place.detail
                return cell
            }
        }
        
        
        if (userCrowdScores.count == 0) {
            let cell: UITableViewCell = UITableViewCell()
            cell.textLabel!.text = "No recent scores...yet."
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.textAlignment = .Center;
            return cell
        }
        
        let cell = self.crowdScoresTableView.dequeueReusableCellWithIdentifier("crowdScoreCell", forIndexPath: indexPath) as! CrowdScoreCell
        if userCrowdScores.count >= indexPath.row {
            
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
            
            let userCrowdScore = userCrowdScores[indexPath.row]
            let user = userCrowdScore["user"] as! PFUser
            cell.userName.text = user["name"] as? String
            if let comment = userCrowdScore["comment"] {
                cell.userComment.text = comment as? String
                cell.userComment.font = UIFont(name:"HelveticaNeue", size: 12.0)
            } else {
                cell.userComment.text = ""
                cell.userComment.font = UIFont(name:"HelveticaNeue-Italic", size: 12.0)
            }
            
            if let scoreTime = userCrowdScore.updatedAt {
                let formatter = NSDateFormatter()
                formatter.timeStyle = .ShortStyle
                if currentCalendar.isDateInToday(scoreTime) {
                    cell.time.text = formatter.stringFromDate(scoreTime)
                } else if currentCalendar.isDateInYesterday(scoreTime) {
                    cell.time.text = "Yesterday, " + formatter.stringFromDate(scoreTime)
                } else {
                    formatter.dateStyle = .ShortStyle
                    cell.time.text = formatter.stringFromDate(scoreTime)
                }
            }
            
            setUserCrowdScoreImagesForCell(userCrowdScore, cell: cell)
            
            if let imageFile = user["image"] as? PFFile {
                cell.userImageView.file = imageFile
                cell.userImageView.loadInBackground()
            }
            
            // See if we need to load more user crowdscores
            if (currentPage < pageLimit) {
                let rowsToLoadFromBottom = resultsLimit;
                let rowsLoaded = userCrowdScores.count
                if (!self.isLoadingCrowdScores && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom)))
                {
                    if let reachability = reachability {
                        if(reachability.isReachable()) {
                            loadAdditionalUserCrowdScores();
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
            let filteredPlace = filteredPlaces[index]
            destination.googlePlace = filteredPlace
            navigationController!.pushViewController(destination, animated: true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showUserScoreView", let destination = segue.destinationViewController as? UserScoreViewController {
            let index = crowdScoresTableView.indexPathForSelectedRow!.row
            let userCrowdScore = userCrowdScores[index]
            destination.userScore = userCrowdScore
        }
    }
    
    private func setUserCrowdScoreImagesForCell(userCrowdScore: PFObject, cell: CrowdScoreCell) {
        
        let userScoreImages = [cell.userScoreFirstImage, cell.userScoreSecondImage,
            cell.userScoreThirdImage, cell.userScoreFourthImage]
        var index = 0
        
        //clear the images first
        for userScoreImage in userScoreImages {
            userScoreImage.image = nil
        }
        
        if let drove = userCrowdScore["drove"] as? Bool where drove {
            if let userParkingDifficult = userCrowdScore["parkingDifficult"] as? Int {
                let userParkingImage = userScoreImages[index]
                if(userParkingDifficult == 5) {
                    userParkingImage.image = UIImage(named: "car-red")
                } else {
                    userParkingImage.image = UIImage(named: "car-green")
                }
                index++
            }
        }
        
        if let userEntranceCharge = userCrowdScore["coverCharge"] as? Int {
            let userEntranceChargeImage = userScoreImages[index]
            switch userEntranceCharge {
            case 1:
                userEntranceChargeImage.image = UIImage(named: "money-green")
                index++
            case 3:
                userEntranceChargeImage.image = UIImage(named: "money-yellow")
                index++
            case 5:
                userEntranceChargeImage.image = UIImage(named: "money-red")
                index++
            default: break
            }
            
        }
        
        if let userWaitTime = userCrowdScore["waitTime"] as? Int {
            let userWaitTimeImage = userScoreImages[index]
            switch userWaitTime {
            case 1:
                userWaitTimeImage.image = UIImage(named: "clock-green")
                index++
            case 3:
                userWaitTimeImage.image = UIImage(named: "clock-yellow")
                index++
            case 5:
                userWaitTimeImage.image = UIImage(named: "clock-red")
                index++
            default: break
            }
        }
        
        if let crowded = userCrowdScore["crowded"] as? Int {
            let crowdImage = userScoreImages[index]
            switch crowded {
            case 0:
                crowdImage.image = UIImage(named: "people-green")
            case 5:
                crowdImage.image = UIImage(named: "people-red")
            default: break
            }
        }
    }
    
    private func getPlaceInBackground(placeResult: PFObject -> ()) {
        
        if let googlePlace = googlePlace {
            googlePlace.getDetails({ (result: PlaceDetails) -> () in
                
                if let place = self.place {
                    
                    // update information
                    place["name"] = result.name
                    place["coordinates"] = PFGeoPoint(latitude: result.latitude, longitude: result.longitude);
                    
                    place.saveEventually {
                        (success: Bool, error: NSError?) -> Void in
                        if (success) {
                            DDLogDebug("Updated place.")
                        } else {
                            DDLogError("Error updaing Place to Parse: \(error)")
                        }
                    }
                    
                    let query = PFQuery(className:"CrowdScore")
                    query.whereKey("place", equalTo: place)
                    //should only be one
                    query.orderByDescending("updatedAt")
                    query.limit = 1
                    query.findObjectsInBackgroundWithBlock { (
                        crowdScores, error) -> Void in
                        if error == nil && crowdScores?.count > 0 {
                            self.isLoadingPlace = false;
                            if (self.loadingSpinner.isAnimating()) {
                                self.loadingSpinner.stopAnimating()
                            }
                            self.crowdScore = crowdScores![0]
                            placeResult(place)
                        } else {
                            DDLogError("Error retrieving Crowd Score from Parse by Place Id: \(error)")
                            self.isLoadingPlace = false;
                            if (self.loadingSpinner.isAnimating()) {
                                self.loadingSpinner.stopAnimating()
                            }
                        }
                    }
                    
                } else {
                    
                    // check if it exists first
                    let query = PFQuery(className:"Place")
                    query.whereKey("googlePlaceId", equalTo: googlePlace.id)
                    query.findObjectsInBackgroundWithBlock {
                        (objects: [PFObject]?, error: NSError?) -> Void in
                        
                        if error == nil {
                            var place: PFObject
                            
                            if (objects?.count > 0) {
                                place = objects![0]
                            } else {
                                place = PFObject(className:"Place")
                                let acl = PFACL()
                                acl.setPublicReadAccess(true)
                                acl.setPublicWriteAccess(true)
                                place.ACL = acl;
                            }
                            
                            place["name"] = result.name
                            place["coordinates"] = PFGeoPoint(latitude: result.latitude, longitude: result.longitude);
                            place["googlePlaceId"] = googlePlace.id
                            place["detail"] = googlePlace.detail
                            
                            place.saveInBackgroundWithBlock {
                                (success: Bool, error: NSError?) -> Void in
                                if (success) {
                                    
                                    let query = PFQuery(className:"CrowdScore")
                                    query.whereKey("place", equalTo: place)
                                    //should only be one
                                    query.orderByDescending("updatedAt")
                                    query.limit = 1
                                    query.findObjectsInBackgroundWithBlock { (
                                        crowdScores, error) -> Void in
                                        if error == nil && crowdScores?.count > 0 {
                                            self.isLoadingPlace = false;
                                            if (self.loadingSpinner.isAnimating()) {
                                                self.loadingSpinner.stopAnimating()
                                            }
                                            self.crowdScore = crowdScores![0]
                                            placeResult(place)
                                        } else {
                                            DDLogError("Error retrieving Crowd Score from Parse by Place Id: \(error)")
                                            self.isLoadingPlace = false;
                                            if (self.loadingSpinner.isAnimating()) {
                                                self.loadingSpinner.stopAnimating()
                                            }
                                        }
                                    }
                                } else {
                                    DDLogError("Error saving place to Parse: \(error)")
                                    self.isLoadingPlace = false;
                                    if (self.loadingSpinner.isAnimating()) {
                                        self.loadingSpinner.stopAnimating()
                                    }
                                }
                            }
                            
                        } else {
                            // Log details of the failure
                            DDLogError("Error retrieving Place from Parse by Google Place Id: \(error)")
                            self.isLoadingPlace = false;
                            if (self.loadingSpinner.isAnimating()) {
                                self.loadingSpinner.stopAnimating()
                            }
                        }
                    }
                }
            })
        }
    }
    
    private func loadInitialUserCrowdScores() {
        
        isLoadingCrowdScores = true
        let query = PFQuery(className: "UserScore")
        query.orderByDescending("updatedAt")
        query.whereKey("place", equalTo: self.place!)
        query.whereKey("updatedAt", greaterThan: NSDate().dateByAddingTimeInterval(-60*60*6))
        query.includeKey("user")
        query.findObjectsInBackgroundWithBlock({ (
            scores, error: NSError?) -> Void in
            if let scores = scores {
                self.userCrowdScores = scores;
                self.currentPage++;
                self.isLoadingCrowdScores = false
                self.crowdScoresTableView.reloadData()
                if (self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                    
                }
            } else {
                if (self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                self.isLoadingCrowdScores = false
                let alert = UIAlertController(title: "Error", message: "Could not load first crowd score results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
            
        })
    }
    
    private func loadAdditionalUserCrowdScores() {
        
        isLoadingCrowdScores = true
        let query = PFQuery(className: "UserScore")
        query.orderByDescending("updatedAt")
        query.whereKey("place", equalTo: self.place!)
        query.whereKey("updatedAt", greaterThan: NSDate().dateByAddingTimeInterval(-60*60*6))
        // Limit what could be a lot of points.
        query.limit = self.resultsLimit
        query.skip = currentPage * resultsLimit;
        query.includeKey("user")
        query.findObjectsInBackgroundWithBlock({ (
            scores, error: NSError?) -> Void in
            if let scores = scores {
                self.userCrowdScores = self.userCrowdScores + scores;
                self.currentPage++;
                self.isLoadingCrowdScores = false
                self.crowdScoresTableView.reloadData()
            } else {
                self.isLoadingCrowdScores = false
                let alert = UIAlertController(title: "Error", message: "Could not load crowd score results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
            
        })
    }
    
    private func initView() {
        
        PFGeoPoint.geoPointForCurrentLocationInBackground { (
            geoPoint, error) -> Void in
            if let geoPoint = geoPoint {
                self.userGeoPoint = geoPoint
            } else {
                DDLogError("Could not obtain user location \(error!.localizedDescription)")
            }
        }
        
        initSearchController()
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to Refresh",
            attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
        refreshControl.tintColor = UIColor.whiteColor()
        refreshControl.addTarget(self, action: "refresh:", forControlEvents: UIControlEvents.ValueChanged)
        crowdScoresTableView.addSubview(refreshControl)
        crowdScoresTableView.backgroundColor = UIColor.clearColor()
        
        crowdScoresTableView.estimatedRowHeight = 90
        crowdScoresTableView.rowHeight = UITableViewAutomaticDimension
        
        var frame: CGRect = loadingSpinner.frame
        frame.origin.x = (self.view.frame.size.width / 2 - frame.size.width / 2)
        frame.origin.y = (self.view.frame.size.height / 2 - frame.size.height / 2)
        loadingSpinner.frame = frame
        view.addSubview(loadingSpinner)
    }
    
    func refresh(sender:AnyObject){
        if let reachability = reachability {
            if(reachability.isReachable()) {
                refreshCrowdScore();
                loadInitialUserCrowdScores();
            } else {
                refreshControl.endRefreshing()
            }
        }
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
    
    func refreshCrowdScore() {
        crowdScore?.fetchInBackgroundWithBlock({ (refreshedCrowdScore, error) -> Void in
            if error == nil {
                self.crowdScore = refreshedCrowdScore
                self.loadPlace()
            } else {
                DDLogError("Error fetching/refreshing crowd score: \(error)")
            }
        })
    }
    
    private func updateViewForCrowdScore() {
        
        self.crowdScoreFirstImage.image = nil
        self.crowdScoreSecondImage.image = nil
        self.crowdScoreThirdImage.image = nil
        self.crowdScoreFirstLabel.text = ""
        self.crowdScoreSecondLabel.text = ""
        self.crowdScoreThirdLabel.text = ""
        
        if let crowdScore  = crowdScore {
            if let crowded = crowdScore["crowded"] as? Int {
                if(crowded >= 0 && crowded < 2) {
                    crowdScoreImage.image = UIImage(named: "people-green")
                } else if (crowded >= 2 && crowded < 4) {
                    crowdScoreImage.image = UIImage(named: "people-yellow")
                } else if (crowded >= 4) {
                    crowdScoreImage.image = UIImage(named: "people-red")
                } else {
                    crowdScoreImage.image = UIImage(named: "people-green")
                }
            }
            
            if let waitTime = crowdScore["waitTime"] as? Int {
                if(waitTime > 0 && waitTime < 2) {
                    crowdScoreFirstImage.image = UIImage(named: "clock-green")
                    crowdScoreFirstLabel.text = "1-9 min wait"
                    crowdScoreFirstLabel.textColor = greenColor
                } else if (waitTime >= 2 && waitTime < 4) {
                    crowdScoreFirstImage.image = UIImage(named: "clock-yellow")
                    crowdScoreFirstLabel.text = "10-30 min wait"
                    crowdScoreFirstLabel.textColor = yellowColor
                } else if (waitTime >= 4) {
                    crowdScoreFirstImage.image = UIImage(named: "clock-red")
                    crowdScoreFirstLabel.text = "Over 30 min wait"
                    crowdScoreFirstLabel.textColor = redColor
                } else {
                    crowdScoreFirstImage.image = UIImage(named: "clock-white")
                    crowdScoreFirstLabel.text = "No wait"
                    crowdScoreFirstLabel.textColor = UIColor.whiteColor()
                }
            }
            
            if let coverCharge = crowdScore["coverCharge"] as? Int {
                if(coverCharge > 0 && coverCharge < 2) {
                    crowdScoreSecondImage.image = UIImage(named: "money-green")
                    crowdScoreSecondLabel.text = "$1-5 cover"
                    crowdScoreSecondLabel.textColor = greenColor
                } else if (coverCharge >= 2 && coverCharge < 4) {
                    crowdScoreSecondImage.image = UIImage(named: "money-yellow")
                    crowdScoreSecondLabel.text = "$6-10 cover"
                    crowdScoreSecondLabel.textColor = yellowColor
                } else if (coverCharge >= 4) {
                    crowdScoreSecondImage.image = UIImage(named: "money-red")
                    crowdScoreSecondLabel.text = "Over $10 cover"
                    crowdScoreSecondLabel.textColor = redColor
                } else {
                    crowdScoreSecondImage.image = UIImage(named: "money-white")
                    crowdScoreSecondLabel.text = "No cover"
                    crowdScoreSecondLabel.textColor = UIColor.whiteColor()
                }
            }
            
            if let parking = crowdScore["parkingDifficult"] as? Int {
                if(parking >= 0 && parking < 2) {
                    crowdScoreThirdImage.image = UIImage(named: "car-green")
                    crowdScoreThirdLabel.text = "Easy parking"
                    crowdScoreThirdLabel.textColor = greenColor
                } else if (parking >= 2 && parking < 4) {
                    crowdScoreThirdImage.image = UIImage(named: "car-yellow")
                    crowdScoreThirdLabel.text = "Moderate parking"
                    crowdScoreThirdLabel.textColor = yellowColor
                } else if (parking >= 4) {
                    crowdScoreThirdImage.image = UIImage(named: "car-red")
                    crowdScoreThirdLabel.text = "Difficult parking"
                    crowdScoreThirdLabel.textColor = redColor
                } else {
                    crowdScoreThirdImage.image = UIImage(named: "car-green")
                    crowdScoreThirdLabel.text = "Easy parking"
                    crowdScoreThirdLabel.textColor = greenColor
                }
            }
        } else {
            crowdScoreFirstImage.image = UIImage(named: "car-green")
            crowdScoreFirstLabel.text = "Easy parking"
            crowdScoreFirstLabel.textColor = greenColor
        }
        
        crowdScoreImage.hidden = false
    }
    
    private func loadPlace() {
        
        if let place = self.place {
            
            name.text = place["name"] as? String
            detail.text = place["detail"] as? String
            
            updateViewForCrowdScore()
            
            if let reachability = reachability {
                if(reachability.isReachable()) {
                    loadInitialUserCrowdScores();
                }
            }
        }
    }
}