//
//  CrowdScoreCell.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/29/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit
import ParseUI

class CrowdScoreCell: PFTableViewCell {
    
    @IBOutlet var userComment: UILabel!

    @IBOutlet var userScoreFirstImage: UIImageView!
    
    @IBOutlet var userScoreSecondImage: UIImageView!
    
    @IBOutlet var userScoreThirdImage: UIImageView!
    
    @IBOutlet var userScoreFourthImage: UIImageView!
    
    @IBOutlet var userName: UILabel!
    
    @IBOutlet var userImageView: PFImageView!
    
    @IBOutlet var time: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
