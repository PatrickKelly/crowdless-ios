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

class CrowdScoreViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var googlePlace: Place?
    var place: PFObject?
    var crowdScore: PFObject?
    
    @IBOutlet var crowdScoreSummaryView: UIView!
    
    @IBOutlet var name: UILabel!
    @IBOutlet var detail: UILabel!
    
    @IBOutlet var crowdScoreImage: UIImageView!
    @IBOutlet var crowdScoreFirstImage: UIImageView!
    @IBOutlet var crowdScoreSecondImage: UIImageView!
    @IBOutlet var crowdScoreThirdImage: UIImageView!
    
    @IBOutlet var crowdScoreFirstLabel: UILabel!
    @IBOutlet var crowdScoreSecondLabel: UILabel!
    @IBOutlet var crowdScoreThirdLabel: UILabel!
    
    @IBOutlet var crowdScoresTableView: UITableView!
    
    private var refreshControl:UIRefreshControl!
    private let apiKey = "AIzaSyC_Ydzgdq62x0XXgy6vMp8p3aNs6PlOh0M"
    private var userCrowdScores = [PFObject]()
    private let resultsLimit = 10
    private var currentPage = 0
    private let pageLimit = 5
    private var isLoadingPlace = false
    private var isLoadingCrowdScores = false
    let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();
    private var refreshCrowdScoreTimer: NSTimer?
    lazy var searchBar:UISearchBar = UISearchBar()
    
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
        
        searchBar.placeholder = "Search..."
        self.navigationItem.titleView = searchBar
        
        initView()
    }
    
    override func viewWillAppear(animated: Bool) {
        
        isLoadingPlace = true
        userCrowdScores.removeAll()
        crowdScoresTableView.reloadData()
        
        clearView()
        
        super.viewWillAppear(animated);
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadingSpinner.startAnimating()
                isLoadingPlace = true;
                crowdScoresTableView.reloadData()
                if let crowdScore = crowdScore {
                    crowdScore.fetchIfNeededInBackgroundWithBlock({ (
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
        
        if (isLoadingPlace || isLoadingCrowdScores) {
            return 0;
        }
        
        if(userCrowdScores.count == 0) {
            return 1;
        }
        
        return userCrowdScores.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
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
            cell.userName.text = user["name"] as! String
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
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showScorecardView", let destination = segue.destinationViewController as? ScorecardViewController {
            destination.place = place
        } else if segue.identifier == "showUserScoreView", let destination = segue.destinationViewController as? UserScoreViewController {
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
                    
                    placeResult(place)
                    self.isLoadingPlace = false;
                    if (self.loadingSpinner.isAnimating()) {
                        self.loadingSpinner.stopAnimating()
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
                                    placeResult(place)
                                } else {
                                    DDLogError("Error saving place to Parse: \(error)")
                                }
                            }
                            
                        } else {
                            // Log details of the failure
                            DDLogError("Error retrieving Place from Parse by Google Place Id: \(error)")
                        }
                        
                        self.isLoadingPlace = false;
                        if (self.loadingSpinner.isAnimating()) {
                            self.loadingSpinner.stopAnimating()
                        }
                    }
                }
            })
        }
    }
    
    private func loadInitialUserCrowdScores() {
        
        isLoadingCrowdScores = true
        let query = PFQuery(className: "UserScore")
        query.orderByDescending("createdAt")
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
        query.orderByDescending("createdAt")
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
        
        let crowdScoreImages = [crowdScoreFirstImage, crowdScoreSecondImage, crowdScoreThirdImage]
        let crowdScoreLabels = [crowdScoreFirstLabel, crowdScoreSecondLabel, crowdScoreThirdLabel]
        var index = 0
        
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
                let waitTimeImage = crowdScoreImages[index]
                let waitTimeLabel = crowdScoreLabels[index]
                if(waitTime > 0 && waitTime < 2) {
                    waitTimeImage.image = UIImage(named: "clock-green")
                    waitTimeLabel.text = "1-9 min wait"
                    waitTimeLabel.textColor = greenColor
                    index++
                } else if (waitTime >= 2 && waitTime < 4) {
                    waitTimeImage.image = UIImage(named: "clock-yellow")
                    waitTimeLabel.text = "10-30 min wait"
                    waitTimeLabel.textColor = yellowColor
                    index++
                } else if (waitTime >= 4) {
                    waitTimeImage.image = UIImage(named: "clock-red")
                    waitTimeLabel.text = "Over 30 min wait"
                    waitTimeLabel.textColor = redColor
                    index++
                }
            }
            
            if let coverCharge = crowdScore["coverCharge"] as? Int {
                let coverChargeImage = crowdScoreImages[index]
                let coverChargeLabel = crowdScoreLabels[index]
                if(coverCharge > 0 && coverCharge < 2) {
                    coverChargeImage.image = UIImage(named: "money-green")
                    coverChargeLabel.text = "$1-5 cover"
                    coverChargeLabel.textColor = greenColor
                    index++
                } else if (coverCharge >= 2 && coverCharge < 4) {
                    coverChargeImage.image = UIImage(named: "money-yellow")
                    coverChargeLabel.text = "$6-10 cover"
                    coverChargeLabel.textColor = yellowColor
                    index++
                } else if (coverCharge >= 4) {
                    coverChargeImage.image = UIImage(named: "money-red")
                    coverChargeLabel.text = "Over $10 cover"
                    coverChargeLabel.textColor = redColor
                    index++
                }
            }
            
            if let parking = crowdScore["parkingDifficult"] as? Int {
                let userParkingImage = crowdScoreImages[index]
                let userParkingLabel = crowdScoreLabels[index]
                if(parking >= 0 && parking < 2) {
                    userParkingImage.image = UIImage(named: "car-green")
                    userParkingLabel.text = "Easy parking"
                    userParkingLabel.textColor = greenColor
                } else if (parking >= 2 && parking < 4) {
                    userParkingImage.image = UIImage(named: "car-yellow")
                    userParkingLabel.text = "Moderate parking"
                    userParkingLabel.textColor = yellowColor
                } else if (parking >= 4) {
                    userParkingImage.image = UIImage(named: "car-red")
                    userParkingLabel.text = "Difficult parking"
                    userParkingLabel.textColor = redColor
                } else {
                    userParkingImage.image = UIImage(named: "car-green")
                    userParkingLabel.text = "Easy parking"
                    userParkingLabel.textColor = greenColor
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
            
//            refreshCrowdScoreTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: "refreshCrowdScore", userInfo: nil, repeats: true)
        }
    }
}