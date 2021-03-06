//
//  ScorecardViewController.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/20/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import Parse
import BEMCheckBox
import CocoaLumberjack

class ScorecardViewController: UIViewController, UITextViewDelegate, BEMCheckBoxDelegate, UINavigationBarDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet var parkingDifficultCheckbox: BEMCheckBox!
    
    @IBOutlet var driveCheckbox: BEMCheckBox!
    
    @IBOutlet var parkingDifficultLabel: UILabel!
    
    @IBOutlet var commentTextView: UITextView!
    
    @IBOutlet var crowdedCheckbox: BEMCheckBox!
    
    @IBOutlet var coverChargeSegment: UISegmentedControl!
    
    @IBOutlet var waitTimeSegment: UISegmentedControl!
    
    @IBOutlet var navigationBar: UINavigationBar!
    
    var userScore: PFObject?
    
    var crowdScore: PFObject?
    
    
    @IBAction func scoreButtonPressed(sender: AnyObject) {
        saveScore()
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func cancelButtonPressed(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initView()
    }
    
    override func viewWillAppear(animated: Bool) {
        
        if let _ = userScore {
            updateViewForUserScore()
        }
        
        super.viewWillAppear(animated);
    }
    
    private func updateViewForUserScore() {
        
        if let crowd = userScore!["crowded"] as? Int {
            switch crowd {
            case 0:
                crowdedCheckbox.on = false
            case 5:
                crowdedCheckbox.on = true
            default:
                crowdedCheckbox.on = false
            }
        }
        
        if let drove = userScore!["drove"] as? Bool where drove {
            driveCheckbox.on = true
            parkingDifficultLabel.enabled = true
            parkingDifficultCheckbox.hidden = false
            
            if let userParkingDifficult = userScore!["parkingDifficult"] as? Int {
                switch userParkingDifficult {
                case 0:
                    parkingDifficultCheckbox.on = false
                case 5:
                    parkingDifficultCheckbox.on = true
                default:
                    parkingDifficultCheckbox.on = false
                }
            }
        }
        
        if let userCoverCharge = userScore!["coverCharge"] as? Int {
            switch userCoverCharge {
            case 0:
                coverChargeSegment.selectedSegmentIndex = 0
            case 1:
                coverChargeSegment.selectedSegmentIndex = 1
            case 3:
                coverChargeSegment.selectedSegmentIndex = 2
            case 5:
                coverChargeSegment.selectedSegmentIndex = 3
            default:
                coverChargeSegment.selectedSegmentIndex = 0
            }
        }
        
        if let waitTime = userScore!["waitTime"] as? Int {
            switch waitTime {
            case 0:
                waitTimeSegment.selectedSegmentIndex = 0
            case 1:
                waitTimeSegment.selectedSegmentIndex = 1
            case 3:
                waitTimeSegment.selectedSegmentIndex = 2
            case 5:
                waitTimeSegment.selectedSegmentIndex = 3
            default:
                waitTimeSegment.selectedSegmentIndex = 0
            }
        }
        
        if let comment = userScore!["comment"] as? String {
            commentTextView.text = comment
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    func didTapCheckBox(checkBox: BEMCheckBox) {
        if driveCheckbox.on {
            parkingDifficultLabel.enabled = true
            parkingDifficultCheckbox.hidden = false
        } else {
            parkingDifficultLabel.enabled = false
            parkingDifficultCheckbox.hidden = true
        }
    }
    
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        return textView.text.characters.count + (text.characters.count - range.length) <= 140;
    }
    
    func keyboardDidShow(notification: NSNotification) {
        
        var info = notification.userInfo
        var kbRect = info![UIKeyboardFrameBeginUserInfoKey]!.CGRectValue
        kbRect = self.view.convertRect(kbRect, fromView: nil)
        let contentInsets: UIEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, kbRect.size.height, 0.0)
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
        var aRect: CGRect = self.view.frame
        aRect.size.height -= kbRect.size.height
        if !CGRectContainsPoint(aRect, commentTextView.frame.origin) {
            self.scrollView.scrollRectToVisible(commentTextView.frame, animated: true)
        }
    }
    
    func keyboardWillBeHidden(notification: NSNotification) {
        let contentInsets: UIEdgeInsets = UIEdgeInsetsZero
        self.scrollView.contentInset = contentInsets
        self.scrollView.scrollIndicatorInsets = contentInsets
    }
    
    func dismissKeyboard() {
        commentTextView.endEditing(true)
    }
    
    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    private func initView() {
        
        navigationBar.delegate = self
        
        commentTextView.layer.cornerRadius = 5
        commentTextView.layer.borderColor = UIColor(red: 85/255, green: 85/255, blue: 85/255, alpha: 1.0).CGColor
        commentTextView.layer.borderWidth = 0.5
        commentTextView.clipsToBounds = true
        
        driveCheckbox.delegate = self;
        parkingDifficultCheckbox.hidden = true
        
        let tap = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
        scrollView.addGestureRecognizer(tap)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardDidShow:", name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillBeHidden:", name: UIKeyboardWillHideNotification, object: nil)
        
    }
    
    private func saveScore() {
        
        var score: PFObject
        if let userScore = userScore {
            score = userScore
        } else {
            score = PFObject(className:"UserScore")
        }
        
        let currentUser = PFUser.currentUser()!
        score["user"] = currentUser
        score["drove"] = driveCheckbox.on
        
        if let userScore = userScore {
            score["place"] = userScore["place"]
        } else {
            score["crowdScore"] = crowdScore
            score["place"] = crowdScore!["place"]
        }
        score["crowded"] = crowdedCheckbox.on ? 5 : 0
        
        if driveCheckbox.on {
            score["parkingDifficult"] = parkingDifficultCheckbox.on ? 5 : 0
        } else {
            score.removeObjectForKey("parkingDifficult")
        }
        
        score["coverCharge"] = getCoverChargeScoreFromSegmentIndex(coverChargeSegment.selectedSegmentIndex)
        score["waitTime"] = getWaitTimeScoreFromSegmentIndex(waitTimeSegment.selectedSegmentIndex)
        
        let trimmedComment = commentTextView.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if !trimmedComment.isEmpty {
            score["comment"] = commentTextView.text
        } else {
            score.removeObjectForKey("comment")
        }
        
        score.saveInBackgroundWithBlock {
            (success: Bool, error: NSError?) -> Void in
            if (success) {
                DDLogDebug("Score successfully saved.")
            } else {
                DDLogError("Error saving Score to Parse: \(error)")
            }
        }
    }
    
    private func getCoverChargeScoreFromSegmentIndex(index: Int) -> Int {
        
        var score = 0;
        
        switch index {
        case 0:
            score = 0
        case 1:
            score = 1
        case 2:
            score = 3
        case 3:
            score = 5
        default: break
        }
        
        return score;
    }
    
    private func getWaitTimeScoreFromSegmentIndex(index: Int) -> Int {
        
        var score = 0;
        
        switch index {
        case 0:
            score = 0
        case 1:
            score = 1
        case 2:
            score = 3
        case 3:
            score = 5
        default: break
        }
        
        return score;
    }
}
