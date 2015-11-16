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

class ScorecardViewController: UIViewController, UITextViewDelegate, BEMCheckBoxDelegate {
    
    @IBOutlet var scrollView: UIScrollView!
    
    @IBOutlet var contentView: UIView!
    
    @IBOutlet var parkingDifficultCheckbox: BEMCheckBox!
    
    @IBOutlet var driveCheckbox: BEMCheckBox!
    
    @IBOutlet var parkingDifficultLabel: UILabel!
    
    @IBOutlet var commentTextView: UITextView!
    
    @IBOutlet var crowdedCheckbox: BEMCheckBox!
    
    @IBOutlet var coverChargeSegment: UISegmentedControl!
    
    @IBOutlet var waitTimeSegment: UISegmentedControl!
    
    var place: PFObject!
    
    var userScore: PFObject!
    
    @IBAction override func unwindForSegue(unwindSegue: UIStoryboardSegue, towardsViewController subsequentVC: UIViewController) {
        
        if unwindSegue.identifier == "postAndUnwindSegue" {
            savePost();
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initView()
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
    
    private func initView() {
        
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
    
    private func savePost() {
        let score = PFObject(className:"UserScore")
        let currentUser = PFUser.currentUser()!
        score["user"] = currentUser
        score["drove"] = driveCheckbox.on
        score["place"] = place
        score["crowded"] = crowdedCheckbox.on ? 5 : 0
        
        if driveCheckbox.on {
            score["parkingDifficult"] = parkingDifficultCheckbox.on ? 5 : 0
        }
        
        score["coverCharge"] = getCoverChargeScoreFromSegmentIndex(coverChargeSegment.selectedSegmentIndex)
        score["waitTime"] = getWaitTimeScoreFromSegmentIndex(waitTimeSegment.selectedSegmentIndex)
        
        let trimmedComment = commentTextView.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if !trimmedComment.isEmpty {
            score["comment"] = commentTextView.text
        }
        
        score.saveInBackgroundWithBlock {
            (success: Bool, error: NSError?) -> Void in
            if (success) {
                DDLogDebug("Score succesfully saved.")
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
