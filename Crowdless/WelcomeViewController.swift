/**
* Copyright (c) 2015-present, Crowdless, Inc.
* All rights reserved.
*/

import UIKit
import Parse
import ParseFacebookUtilsV4
import CocoaLumberjack

class WelcomeViewController: UIViewController {
    
    @IBOutlet var background: UIImageView!
    @IBAction func fbLoginButtonTUI(sender: AnyObject) {
        
        let permissions = ["public_profile"]
        PFFacebookUtils.logInInBackgroundWithReadPermissions(permissions) {
            (user: PFUser?, error: NSError?) -> Void in
            if let user = user {
                if user.isNew {
                    self.saveNewUser(user, withcompletionHandler: { (success) -> () in
                        if(success) {
                            self.dismissLoginScreen()
                            //self.dismissViewControllerAnimated(true, completion: nil)
                        } else {
                            self.displayErrorAlert("Registration failed. Please try again.")
                        }
                    })
                } else {
                    self.dismissLoginScreen()
                    //self.dismissViewControllerAnimated(true, completion: nil)
                }
            } else if let error = error {
                DDLogError("\(error)")
                self.displayErrorAlert("Login failed. Please try again.")
            } else {
                DDLogError("User cancelled or did not log in.")
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning();
        // Dispose of any resources that can be recreated.
    }
    
    func dismissLoginScreen() {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        delegate.showCrowdsTrendingViewController()
    }
    
    private func saveNewUser(user: PFUser, withcompletionHandler: (success:Bool) ->()) {
        let graphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields" : "id, name, gender, age"])
        graphRequest.startWithCompletionHandler { (
            connection, result, error) -> Void in
            
            if let error = error {
                DDLogError("\(error)")
                withcompletionHandler(success: false)
            } else if let result = result {
                
                user["gender"] = result["gender"]
                user["name"] = result["name"]
                user["facebookId"] = result["id"] as! String
                
                let facebookId = result["id"] as! String
                let fbPictureUrl = "https://graph.facebook.com/" + facebookId + "/picture?type=large";
                if let nsFbPictureUrl = NSURL(string: fbPictureUrl) {
                    if let data = NSData(contentsOfURL: nsFbPictureUrl) {
                        if let imageFile:PFFile = PFFile(data: data) {
                            user["image"] = imageFile
                        }
                    }
                }
                
                do {
                    try user.save();
                } catch {
                    DDLogError("An error occurred while saving the user image.")
                    withcompletionHandler(success: false);
                }
                
                withcompletionHandler(success: true)
            }
        }
    }
    
    func displayErrorAlert(errorText: String) {
        let alert = UIAlertController(title: "Login Error", message: errorText, preferredStyle: UIAlertControllerStyle.Alert);
        alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil));
        self.presentViewController(alert, animated: true, completion: nil);
    }
}
