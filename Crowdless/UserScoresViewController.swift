//
//  UserScoresViewController.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/23/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import Parse
import ReachabilitySwift
import CocoaLumberjack

class UserScoresViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,
UISearchResultsUpdating, UISearchBarDelegate, ScrollableToTop {
    
    @IBOutlet var userScoresTableView: UITableView!
    
    //for Google places search
    private var filteredPlaces = [Place]()
    private var searchResultsController: UITableViewController!
    private var userGeoPoint: PFGeoPoint?
    private var searchController:UISearchController!
    private let googlePlacesHelper = GooglePlacesHelper()
    
    private var refreshControl:UIRefreshControl!
    private var userScores = [PFObject]()
    private let resultsLimit = 10
    private var currentPage = 0
    private let pageLimit = 20
    private var isLoadingUserScores = false
    let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();
    
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
    
    override func viewWillAppear(animated: Bool) {
        
        if !definesPresentationContext {
            definesPresentationContext = true
        }
        
        isLoadingUserScores = true
        userScores.removeAll()
        userScoresTableView.reloadData()
        
        super.viewWillAppear(animated);
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadingSpinner.startAnimating()
                loadInitialUserScores()
            } else {
                isLoadingUserScores = false;
                let alert = UIAlertController(title: "Error", message: "An Internet connection is required to get your scores.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
        } else {
            DDLogError("Reachability object is nil.")
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
    
    func scrollToTop() {
        userScoresTableView.setContentOffset(CGPointZero, animated:true)
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
    
    override func viewWillDisappear(animated: Bool) {
        definesPresentationContext = false
        super.viewWillDisappear(animated)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == searchResultsController.tableView {
            return filteredPlaces.count + 1
        } else {
            if (isLoadingUserScores) {
                return 0;
            }
            
            if(userScores.count == 0) {
                return 1;
            }
            
            
            return userScores.count
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
        
        
        if (userScores.count == 0) {
            let cell: UITableViewCell = UITableViewCell()
            cell.textLabel!.text = "You have no scores! Search for a place and get your score on!"
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.textAlignment = .Center;
            return cell
        }
        
        let cell = userScoresTableView.dequeueReusableCellWithIdentifier("userScoreTableCell", forIndexPath: indexPath) as! UserScoreTableViewCell
        if userScores.count >= indexPath.row {
            
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
            
            let userScore = userScores[indexPath.row]
            let place = userScore["place"] as! PFObject
            cell.placeName.text = place["name"] as? String
            if let comment = userScore["comment"] {
                cell.userComment.text = comment as? String
                cell.userComment.font = UIFont(name:"HelveticaNeue", size: 12.0)
            } else {
                cell.userComment.text = ""
            }
            
            if let scoreTime = userScore.updatedAt {
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
            
            setUserCrowdScoreImagesForCell(userScore, cell: cell)
            if let helpfulCount = userScore["helpfulCount"] as? Int {
                if helpfulCount > 0 {
                    cell.helpfulCount.text = String(helpfulCount) + " others found your score helpful!"
                    cell.helpfulCount.hidden = false
                    
                } else {
                    cell.helpfulCount.text = ""
                    cell.helpfulCount.hidden = true
                }
            } else {
                cell.helpfulCount.text = ""
                cell.helpfulCount.hidden = true
            }
            
            
            
            // See if we need to load more user crowdscores
            if (currentPage < pageLimit) {
                let rowsToLoadFromBottom = resultsLimit;
                let rowsLoaded = userScores.count
                if (!isLoadingUserScores && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom)))
                {
                    if let reachability = reachability {
                        if(reachability.isReachable()) {
                            loadAdditionalUserScores();
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
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showUserScoreView", let destination = segue.destinationViewController as? UserScoreViewController {
            let index = userScoresTableView.indexPathForSelectedRow!.row
            let userScore = userScores[index]
            destination.userScore = userScore
            destination.place = userScore["place"] as! PFObject
        }
    }
    
    private func setUserCrowdScoreImagesForCell(userCrowdScore: PFObject, cell: UserScoreTableViewCell) {
        
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
    
    private func loadInitialUserScores() {
        
        let currentUser = PFUser.currentUser()!
        
        isLoadingUserScores = true
        let query = PFQuery(className: "UserScore")
        query.orderByDescending("updatedAt")
        query.whereKey("user", equalTo: currentUser)
        query.includeKey("place")
        query.findObjectsInBackgroundWithBlock({ (
            scores, error: NSError?) -> Void in
            if let scores = scores {
                self.userScores = scores;
                self.currentPage++;
                self.isLoadingUserScores = false
                self.userScoresTableView.reloadData()
                if(self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                
                if(self.loadingSpinner.isAnimating()) {
                    self.loadingSpinner.stopAnimating()
                }
            } else {
                if(self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                
                if(self.loadingSpinner.isAnimating()) {
                    self.loadingSpinner.stopAnimating()
                }
                DDLogError("Could not load first crowd score results \(error!.localizedDescription)")
                self.isLoadingUserScores = false
                let alert = UIAlertController(title: "Error", message: "Could not load first crowd score results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
            
        })
    }
    
    private func loadAdditionalUserScores() {
        
        let currentUser = PFUser.currentUser()!
        
        isLoadingUserScores = true
        let query = PFQuery(className: "UserScore")
        query.orderByDescending("updatedAt")
        query.whereKey("user", equalTo: currentUser)
        // Limit what could be a lot of points.
        query.limit = self.resultsLimit
        query.skip = currentPage * resultsLimit;
        query.includeKey("place")
        query.findObjectsInBackgroundWithBlock({ (
            scores, error: NSError?) -> Void in
            if let scores = scores {
                self.userScores = self.userScores + scores;
                self.currentPage++;
                self.isLoadingUserScores = false
                self.userScoresTableView.reloadData()
                if(self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                
                if(self.loadingSpinner.isAnimating()) {
                    self.loadingSpinner.stopAnimating()
                }
            } else {
                if(self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                
                if(self.loadingSpinner.isAnimating()) {
                    self.loadingSpinner.stopAnimating()
                }
                DDLogError("Could not load additional crowd score results \(error!.localizedDescription)")
                self.isLoadingUserScores = false
                let alert = UIAlertController(title: "Error", message: "Could not load crowd score results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
            
        })
    }
    
    func refresh(sender:AnyObject){
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadInitialUserScores();
            } else {
                refreshControl.endRefreshing()
            }
        }
    }
    
    private func initView() {
        
        LocationHelper.sharedInstance.getRecentUserLocationInBackground { (
            geoPoint, error) -> Void in
            if let geoPoint = geoPoint {
                self.userGeoPoint = geoPoint
            } else {
                DDLogError("Could not obtain user location \(error!.localizedDescription)")
            }
        }
        
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
        userScoresTableView.addSubview(refreshControl)
        userScoresTableView.backgroundColor = UIColor.clearColor()
        
        userScoresTableView.estimatedRowHeight = 109
        userScoresTableView.rowHeight = UITableViewAutomaticDimension
        
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
