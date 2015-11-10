//
//  SettingsViewController.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/20/15.
//  Copyright © 2015 Reactiv LLC. All rights reserved.
//

import UIKit
import Parse
import CocoaLumberjack

class SettingsViewController: UIViewController {
    
    @IBOutlet var profileImageView: UIImageView!
    
    @IBOutlet var userNameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = PFUser.currentUser() {
            initViewForUser(user);
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if let user = PFUser.currentUser() {
            initViewForUser(user);
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func logoutButtonPressed(sender: AnyObject) {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        delegate.logout()
    }
    
    private func initViewForUser(user: PFUser) {
        
        //set user image
        let userImageFile = user["image"] as! PFFile
        do {
            let imageData = try NSData(data: userImageFile.getData())
            self.profileImageView.image = UIImage(data: imageData);
        } catch {
            DDLogError("Could not load user image.");
        }
        
        profileImageView.layer.masksToBounds = false
        profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
        profileImageView.clipsToBounds = true
        
        //set user name
        let userName = user["name"] as! String
        userNameLabel.text = userName
    }
    
}
