//
//  TrendingCrowdCell.swift
//  CrowdList
//
//  Created by Patrick Kelly on 10/28/15.
//  Copyright © 2015 Crowdless Inc. All rights reserved.
//

import UIKit

class TrendingCrowdCell: UITableViewCell {
    
    @IBOutlet var trendingScoreFirstImage: UIImageView!
    
    @IBOutlet var trendingScoreSecondImage: UIImageView!
    
    @IBOutlet var trendingScoreThirdImage: UIImageView!
    
    @IBOutlet var scoreImage: UIImageView!
    
    @IBOutlet var name: UILabel!
    
    @IBOutlet var detail: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
