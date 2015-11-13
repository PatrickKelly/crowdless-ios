//
//  UserScoreViewController.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/10/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import Parse
import ReachabilitySwift
import CocoaLumberjack

class UserScoreViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var userScore: PFObject!
    private var userScoreComments = [PFObject]()
    
    @IBOutlet var userScoreTableView: UITableView!
    
    @IBOutlet var headerContentView: UIView!
    @IBOutlet var headerView: UIView!
    @IBOutlet var userComment: UILabel!
    @IBOutlet var userScoreTime: UILabel!
    @IBOutlet var userName: UILabel!
    @IBOutlet var reportButton: UIButton!
    @IBOutlet var commentButton: UIButton!
    @IBOutlet var helpfulButton: UIButton!
    @IBOutlet var wait: UILabel!
    @IBOutlet var waitImage: UIImageView!
    @IBOutlet var parking: UILabel!
    @IBOutlet var parkingImage: UIImageView!
    @IBOutlet var coverCharge: UILabel!
    @IBOutlet var coverChargeImage: UIImageView!
    @IBOutlet var crowded: UILabel!
    @IBOutlet var crowdedImage: UIImageView!
    
    private let resultsLimit = 10
    private var currentPage = 0
    private let pageLimit = 5
    
    private var isLoadingUserScore = false
    private var isLoadingUserScoreComments = false
    
    let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();
    
    private let greenColor = UIColor(red: 123/255, green: 191/255, blue: 106/255, alpha: 1.0)
    private let yellowColor = UIColor(red: 254/255, green: 215/255, blue: 0/255, alpha: 1.0)
    private let redColor = UIColor(red: 224/255, green: 64/255, blue: 51/255, alpha: 1.0)
    
    private var refreshControl:UIRefreshControl!
    private var reachability: Reachability?
    
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        var height: CGFloat = headerContentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height + headerContentView.frame.origin.y
        var headerFrame: CGRect = headerView.frame
        headerFrame.size.height = height
        self.headerView.frame = headerFrame
        userScoreTableView.tableHeaderView = headerView
    }
    
    override func viewWillAppear(animated: Bool) {
        
        isLoadingUserScore = true
        userScoreComments.removeAll()
        userScoreTableView.reloadData()
        
        updateView();
        
        super.viewWillAppear(animated);
        
        if let reachability = reachability {
            if(reachability.isReachable()) {
                //loadingSpinner.startAnimating()
                loadInitialUserScoreComments()
            } else {
                isLoadingUserScore = false;
                let alert = UIAlertController(title: "Error", message: "An Internet connection is required to get comments.", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
        } else {
            DDLogError("Reachability object is nil.")
        }
    }
    
    private func updateView() {
        
        let user = userScore["user"] as! PFUser
        userName.text = user["name"] as? String
        
        if let scoreTime = userScore.updatedAt {
            let formatter = NSDateFormatter()
            formatter.timeStyle = .ShortStyle
            if currentCalendar.isDateInToday(scoreTime) {
                userScoreTime.text = formatter.stringFromDate(scoreTime)
            } else if currentCalendar.isDateInYesterday(scoreTime) {
                userScoreTime.text = "Yesterday, " + formatter.stringFromDate(scoreTime)
            } else {
                formatter.dateStyle = .ShortStyle
                userScoreTime.text = formatter.stringFromDate(scoreTime)
            }
        } else {
            userScoreTime.text = ""
        }
        
        if let comment = userScore["comment"] {
            userComment.text = comment as? String
            userComment.font = UIFont(name:"HelveticaNeue", size: 14.0)
        } else {
            userComment.text = user["name"] as! String + " scored this crowd without a comment."
            userComment.font = UIFont(name:"HelveticaNeue-Italic", size: 14.0)
        }
        
        updateUserCrowdScoreImagesAndLabels();
    }
    
    private func updateUserCrowdScoreImagesAndLabels() {
        
        if let crowd = userScore["crowded"] as? Int {
            switch crowd {
            case 0:
                crowdedImage.image = UIImage(named: "people-green")
                crowded.text = "Not crowded"
                crowded.textColor = greenColor
            case 5:
                crowdedImage.image = UIImage(named: "people-red")
                crowded.text = "Crowded"
                crowded.textColor = redColor
            default:
                crowdedImage.image = UIImage(named: "people-green")
                crowded.text = "Not crowded"
                crowded.textColor = greenColor
            }
        }
        
        if let drove = userScore["drove"] as? Bool where drove {
            if let userParkingDifficult = userScore["parkingDifficult"] as? Int {
                if(userParkingDifficult == 5) {
                    parkingImage.image = UIImage(named: "car-red")
                    parking.text = "Difficult parking"
                    parking.textColor = redColor
                } else {
                    parkingImage.image = UIImage(named: "car-green")
                    parking.text = "Easy parking"
                    parking.textColor = greenColor
                }
            } else {
                parkingImage.image = UIImage(named: "car-white");
                parking.text = "Did not drive"
                parking.textColor = UIColor.whiteColor()
            }
        } else {
            parkingImage.image = UIImage(named: "car-white");
            parking.text = "Did not drive"
            parking.textColor = UIColor.whiteColor()
        }
        
        if let userEntranceCharge = userScore["coverCharge"] as? Int {
            switch userEntranceCharge {
            case 1:
                coverChargeImage.image = UIImage(named: "money-green")
                coverCharge.text = "$1-4 cover"
                coverCharge.textColor = greenColor
            case 3:
                coverChargeImage.image = UIImage(named: "money-yellow")
                coverCharge.text = "$5-10 cover"
                coverCharge.textColor = yellowColor
            case 5:
                coverChargeImage.image = UIImage(named: "money-red")
                coverCharge.text = "Over $10 cover"
                coverCharge.textColor = redColor
            default:
                coverChargeImage.image = UIImage(named: "money-white")
                coverCharge.text = "No cover"
                coverCharge.textColor = UIColor.whiteColor()
            }
        } else {
            coverChargeImage.image = UIImage(named: "money-white")
            coverCharge.text = "No cover"
            coverCharge.textColor = UIColor.whiteColor()
        }
        
        if let waitTime = userScore["waitTime"] as? Int {
            switch waitTime {
            case 1:
                waitImage.image = UIImage(named: "clock-green")
                wait.text = "1-9 min wait"
                wait.textColor = greenColor
            case 3:
                waitImage.image = UIImage(named: "clock-yellow")
                wait.text = "10-30 min wait"
                wait.textColor = yellowColor
            case 5:
                waitImage.image = UIImage(named: "clock-red")
                wait.text = "Over 30 min wait"
                wait.textColor = redColor
            default:
                waitImage.image = UIImage(named: "clock-white")
                wait.text = "No wait"
                wait.textColor = UIColor.whiteColor()
            }
        } else {
            waitImage.image = UIImage(named: "clock-white")
            wait.text = "No wait"
            wait.textColor = UIColor.whiteColor()
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (isLoadingUserScoreComments) {
            return 0;
        }
        
        if(userScoreComments.count == 0) {
            return 1;
        }
        
        return userScoreComments.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if (userScoreComments.count == 0) {
            let cell: UITableViewCell = UITableViewCell()
            cell.textLabel!.text = "Leave a comment above!"
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor.clearColor()
            cell.textLabel?.textColor = UIColor.whiteColor()
            cell.textLabel?.textAlignment = .Center;
            return cell
        }
        
        let cell = self.userScoreTableView.dequeueReusableCellWithIdentifier("userScoreCommentCell", forIndexPath: indexPath) as! UserScoreCommentCell
        
        if userScoreComments.count >= indexPath.row {
            
            cell.contentView.backgroundColor = UIColor.clearColor()
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
            
            let userScoreComment = userScoreComments[indexPath.row]
            let user = userScoreComment["user"] as! PFUser
            cell.userName.text = user["name"] as? String
            if let comment = userScoreComment["comment"] {
                cell.comment.text = comment as? String
                cell.comment.font = UIFont(name:"HelveticaNeue", size: 12.0)
            }
            
            if let commentTime = userScoreComment.updatedAt {
                let formatter = NSDateFormatter()
                formatter.timeStyle = .ShortStyle
                if currentCalendar.isDateInToday(commentTime) {
                    cell.time.text = formatter.stringFromDate(commentTime)
                } else if currentCalendar.isDateInYesterday(commentTime) {
                    cell.time.text = "Yesterday, " + formatter.stringFromDate(commentTime)
                } else {
                    formatter.dateStyle = .ShortStyle
                    cell.time.text = formatter.stringFromDate(commentTime)
                }
            }
            
            let userImageFile = user["image"] as! PFFile
            do {
                let imageData = try NSData(data: userImageFile.getData())
                cell.userImage.image = UIImage(data: imageData);
            } catch {
                DDLogError("Could not load user image.");
            }
            
            // See if we need to load more user score comments
            if (currentPage < pageLimit) {
                let rowsToLoadFromBottom = resultsLimit;
                let rowsLoaded = userScoreComments.count
                if (!self.isLoadingUserScoreComments && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom)))
                {
                    if let reachability = reachability {
                        if(reachability.isReachable()) {
                            loadInitialUserScoreComments();
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
    
    private func loadInitialUserScoreComments() {
        
        isLoadingUserScoreComments = true
        let query = PFQuery(className: "UserComments")
        query.orderByDescending("createdAt")
        query.whereKey("userScore", equalTo: self.userScore!)
        //query.whereKey("updatedAt", greaterThan: NSDate().dateByAddingTimeInterval(-60*60*12))
        query.includeKey("user")
        query.findObjectsInBackgroundWithBlock({ (
            comments, error: NSError?) -> Void in
            if let comments = comments {
                self.userScoreComments = comments;
                self.currentPage++;
                self.isLoadingUserScoreComments = false
                self.userScoreTableView.reloadData()
                if (self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                    
                }
            } else {
                
                DDLogError("Error loading initial user score comments : \(error)")
                
                if (self.refreshControl.refreshing) {
                    self.refreshControl.endRefreshing()
                }
                
                self.isLoadingUserScoreComments = false
                
                let alert = UIAlertController(title: "Error", message: "Could not load first crowd score results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
                alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
            }
            
        })
    }
    
    private func loadAdditionalUserScoreComments() {
        
        isLoadingUserScoreComments = true
        let query = PFQuery(className: "UserComments")
        query.orderByDescending("createdAt")
        query.whereKey("userScore", equalTo: self.userScore!)
        //query.whereKey("updatedAt", greaterThan: NSDate().dateByAddingTimeInterval(-60*60*12))
        // Limit what could be a lot of points.
        query.limit = self.resultsLimit
        query.skip = currentPage * resultsLimit;
        query.includeKey("user")
        query.findObjectsInBackgroundWithBlock({ (
            comments, error: NSError?) -> Void in
            if let comments = comments {
                self.userScoreComments = self.userScoreComments + comments;
                self.currentPage++;
                self.isLoadingUserScoreComments = false
                self.userScoreTableView.reloadData()
            } else {
                self.isLoadingUserScoreComments = false
                let alert = UIAlertController(title: "Error", message: "Could not load crowd score comments results \(error!.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
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
        
        userScoreTableView.addSubview(refreshControl)
        userScoreTableView.backgroundColor = UIColor.clearColor()
        
        var frame: CGRect = loadingSpinner.frame
        frame.origin.x = (self.view.frame.size.width / 2 - frame.size.width / 2)
        frame.origin.y = (self.view.frame.size.height / 2 - frame.size.height / 2)
        loadingSpinner.frame = frame
        view.addSubview(loadingSpinner)
    }
    
    func refresh(sender:AnyObject)
    {
        if let reachability = reachability {
            if(reachability.isReachable()) {
                loadInitialUserScoreComments()
            } else {
                refreshControl.endRefreshing()
            }
        }
    }
}
