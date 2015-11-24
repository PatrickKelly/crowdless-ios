//
//  UserScoreTableViewCell.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/24/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit

class UserScoreTableViewCell: UITableViewCell {

    @IBOutlet var userScoreFirstImage: UIImageView!
    
    @IBOutlet var userScoreSecondImage: UIImageView!
    
    @IBOutlet var userScoreThirdImage: UIImageView!
    
    @IBOutlet var userScoreFourthImage: UIImageView!
    
    @IBOutlet var userComment: UILabel!
    
    @IBOutlet var time: UILabel!
    
    @IBOutlet var placeName: UILabel!
    
    @IBOutlet var helpfulCount: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
