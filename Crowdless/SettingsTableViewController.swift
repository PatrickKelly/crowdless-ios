//
//  SettingsTableViewController.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/27/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import ParseUI
import SpringIndicator
import CocoaLumberjack

class SettingsTableViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet var profileImageView: PFImageView!
    @IBOutlet var userNameLabel: UILabel!
    
    @IBOutlet var logoutCell: UITableViewCell!
    
    @IBOutlet weak var termsOfServiceCell: UITableViewCell!
    
    @IBOutlet weak var privacyPolicyCell: UITableViewCell!
    
    @IBOutlet var deactivateCell: UITableViewCell!
    @IBOutlet var displayProfilePictureSwitch: UISwitch!
    @IBOutlet var userNameTextField: UITextField!
    
    @IBOutlet var profilePictureReloadIndicator: SpringIndicator!
    
    private var userNameCharactersToBlock: NSCharacterSet?
    private var deactivateActionSheet: UIAlertController!
    let loadingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    
    let darkGrayColor = UIColor(red: 34/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
    let midGrayColor = UIColor(red: 51/255.0, green: 51/255.0, blue: 51/255.0, alpha: 1.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initView()
        
        if let user = PFUser.currentUser() {
            updateViewForUser(user);
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let user = PFUser.currentUser() {
            updateViewForUser(user);
        }
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        } else {
            return 10
        }
    }
    
    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = darkGrayColor
        return view
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let cell = self.tableView.cellForRowAtIndexPath(indexPath)!
        if cell == logoutCell {
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "CrowdsTrendingTutorialShown")
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "CrowdScoreTutorialShown")
            NSUserDefaults.standardUserDefaults().synchronize()
            let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
            delegate.logout()
        } else if cell == deactivateCell {
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "CrowdsTrendingTutorialShown")
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "CrowdScoreTutorialShown")
            NSUserDefaults.standardUserDefaults().synchronize()
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popPresenter: UIPopoverPresentationController = deactivateActionSheet.popoverPresentationController!
                popPresenter.permittedArrowDirections = .Up
                popPresenter.sourceView = cell
                popPresenter.sourceRect = cell.bounds
            }
            self.presentViewController(deactivateActionSheet, animated: true, completion: nil)
        } else if cell == privacyPolicyCell {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://www.crowdlessapp.com/privacy")!)
        } else if cell == termsOfServiceCell {
            UIApplication.sharedApplication().openURL(NSURL(string: "http://www.crowdlessapp.com/terms")!)
        }
    }
    
    @IBAction func refreshProfilePicturePressed(sender: AnyObject) {
        
        if let user = PFUser.currentUser() {
            profileImageView.hidden = true
            profilePictureReloadIndicator.hidden = false
            profilePictureReloadIndicator.animating = true
            
            let facebookId = user["facebookId"] as! String
            let fbPictureUrl = "https://graph.facebook.com/" + facebookId + "/picture?type=large";
            if let nsFbPictureUrl = NSURL(string: fbPictureUrl) {
                if let data = NSData(contentsOfURL: nsFbPictureUrl) {
                    if let imageFile = PFFile(data: data) {
                        user["image"] = imageFile
                        user.saveInBackgroundWithBlock({ (success, error) -> Void in
                            if success {
                                self.updateViewAfterProfilePictureRefresh()
                                self.retrieveAndDisplayProfilePicture(user)
                            }
                        })
                    } else {
                        DDLogError("Could not create image file.")
                        updateViewAfterProfilePictureRefresh()
                    }
                } else {
                    DDLogError("Could not retrieve Facebook picture data image.")
                    updateViewAfterProfilePictureRefresh()
                }
            } else {
                DDLogError("Could not create picture URL for Facebook.")
                updateViewAfterProfilePictureRefresh()
            }
        }
    }
    
    private func updateViewAfterProfilePictureRefresh() {
        self.profilePictureReloadIndicator.hidden = true
        self.profileImageView.hidden = false
        self.profilePictureReloadIndicator.animating = false
    }
    
    private func deactivateAccount() {
        
        if let user = PFUser.currentUser() {
            loadingSpinner.startAnimating()
            user["active"] = false
            user.saveInBackgroundWithBlock({ (saved, error) -> Void in
                if error == nil {
                    self.loadingSpinner.stopAnimating()
                    let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
                    delegate.logout()
                } else {
                    self.loadingSpinner.stopAnimating()
                    DDLogError("An error occurred while trying to deactivate user account: \(error)")
                    let alert = UIAlertController(title: "Error", message: "An error occurred while attempting to deactivate your account. Please try again.", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            })
        }
    }
    
    private func initView() {
        
        // fixes a bug where bar crowd from welcome screen occasionally appeared
        self.view.backgroundColor = UIColor(red: 34/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
        
        // set background color of cells; have to do this because the accessory arrow appears as white
        // on iPads unless this is done programmatically
        termsOfServiceCell.backgroundColor = midGrayColor
        privacyPolicyCell.backgroundColor = midGrayColor
        logoutCell.backgroundColor = midGrayColor
        deactivateCell.backgroundColor = midGrayColor
        
        let anChar = NSMutableCharacterSet(charactersInString: " ")
        anChar.formUnionWithCharacterSet(NSCharacterSet.alphanumericCharacterSet())
        userNameCharactersToBlock = anChar.invertedSet
        
        profileImageView.layer.masksToBounds = false
        profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
        profileImageView.clipsToBounds = true
        
        let tap = UITapGestureRecognizer(target: self, action: "endEditing")
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        tableView.tableFooterView = UIView(frame: CGRectZero)
        
        profilePictureReloadIndicator.hidden = true
        profileImageView.hidden = false
        
        userNameTextField.delegate = self
        userNameTextField.addTarget(self, action: "textFieldDidChange", forControlEvents: .EditingChanged)
        userNameTextField.autocorrectionType = .No
        
        deactivateActionSheet = UIAlertController(title: "Are you sure you want to deactivate your Crowdless account?", message: nil, preferredStyle: .ActionSheet)
        let deactivate = UIAlertAction(title: "Deactivate", style: .Destructive, handler: {
            (alert: UIAlertAction!) -> Void in
            self.deactivateAccount()
        })
        let cancelDeactivate = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        deactivateActionSheet.addAction(deactivate)
        deactivateActionSheet.addAction(cancelDeactivate)
        
        var frame: CGRect = loadingSpinner.frame
        frame.origin.x = (self.view.frame.size.width / 2 - frame.size.width / 2)
        frame.origin.y = (self.view.frame.size.height / 2 - frame.size.height / 2)
        loadingSpinner.frame = frame
        view.addSubview(loadingSpinner)
    }
    
    func textFieldDidChange() {
        userNameLabel.text = userNameTextField.text
    }
    
    func endEditing() {
        if userNameTextField.editing {
            view.endEditing(true)
            if userNameTextField.text?.characters.count > 0 {
                let name = userNameTextField.text
                userNameLabel.text = name
                
                if let user = PFUser.currentUser() {
                    user["name"] = name
                    user.saveEventually()
                }
            } else {
                if let user = PFUser.currentUser() {
                    userNameTextField.text = user["name"] as? String
                    userNameLabel.text = user["name"] as? String
                }
            }
        }
    }
    
    private func updateViewForUser(user: PFUser) {
        
        if let displayProfilePicture = user["displayProfilePicture"] as? Bool {
            if displayProfilePicture {
                retrieveAndDisplayProfilePicture(user)
            } else {
                profileImageView.image = UIImage(named: "crowdless-trending-200")
            }
            displayProfilePictureSwitch.on = displayProfilePicture
        }
        
        //set user name
        let userName = user["name"] as! String
        userNameLabel.text = userName
        userNameTextField.text = userName
    }
    
    private func retrieveAndDisplayProfilePicture(user: PFUser) {
        //set user image
        let userImageFile = user["image"] as? PFFile
        profileImageView.file = userImageFile
        profileImageView.loadInBackground()
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        
        let components = string.componentsSeparatedByCharactersInSet(userNameCharactersToBlock!)
        let filtered = components.joinWithSeparator("")
        if string != filtered {
            return false
        }
        
        guard let text = textField.text else { return true }
        
        let newLength = text.characters.count + string.characters.count - range.length
        return newLength <= 50
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let name = textField.text
        userNameLabel.text = name
        
        if let user = PFUser.currentUser() {
            user["name"] = name
            user.saveEventually()
        }
        
        return true
    }
    
    
    @IBAction func displayProfilePictureValueChanged(sender: AnyObject) {
        
        if let user = PFUser.currentUser() {
            if displayProfilePictureSwitch.on {
                user["displayProfilePicture"] = true
                retrieveAndDisplayProfilePicture(user)
            } else {
                user["displayProfilePicture"] = false
                profileImageView.image = UIImage(named: "crowdless-trending-200")
            }
            user.saveEventually()
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}
