//
//  CrowdScoresTableViewController.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/17/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import Parse
import ParseUI

class CrowdScoresTableViewController: PFQueryTableViewController {
    
    var place: PFObject?
    private var currentCalendar = NSCalendar.autoupdatingCurrentCalendar();

    override init(style: UITableViewStyle, className: String?) {
        super.init(style: style, className: className)
        parseClassName = "UserScore"
        pullToRefreshEnabled = true
        paginationEnabled = true
        objectsPerPage = 10
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        parseClassName = "UserScore"
        pullToRefreshEnabled = true
        paginationEnabled = true
        objectsPerPage = 10
    }
    
    override func queryForTable() -> PFQuery {
        let query = PFQuery(className: self.parseClassName!)
        
        // If no objects are loaded in memory, we look to the cache first to fill the table
        // and then subsequently do a query against the network.
        if self.objects!.count == 0 {
            query.cachePolicy = .CacheThenNetwork
        }
        
        query.orderByDescending("createdAt")
        query.whereKey("place", equalTo: self.place!)
        query.whereKey("updatedAt", greaterThan: NSDate().dateByAddingTimeInterval(-60*60*6))
        query.includeKey("user")
        
        return query
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath, object: PFObject?) -> PFTableViewCell? {
        let cellIdentifier = "crowdScoreCell"
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! CrowdScoreCell
        
        if let userCrowdScore = object {
            let user = userCrowdScore["user"] as! PFUser
            cell.userName.text = user["name"] as! String
            if let comment = userCrowdScore["comment"] {
                cell.userComment.text = comment as? String
                cell.userComment.font = UIFont(name:"HelveticaNeue", size: 12.0)
            } else {
                cell.userComment.text = user["name"] as! String + " scored this crowd without a comment."
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
        }
        
        return cell
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
    
}
