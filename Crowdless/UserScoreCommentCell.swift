//
//  UserScoreCommentCellTableViewCell.swift
//  Crowdless
//
//  Created by Patrick Kelly on 11/11/15.
//  Copyright © 2015 Crowdless, Inc. All rights reserved.
//

import UIKit

class UserScoreCommentCell: UITableViewCell {

    @IBOutlet var userImage: UIImageView!
    
    @IBOutlet var time: UILabel!
    
    @IBOutlet var userName: UILabel!
    
    @IBOutlet var comment: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
