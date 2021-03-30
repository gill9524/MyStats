//
//  PeripheralTableViewCell.swift
//  MyStats
//
//  Created by Amrinder Gill on 5/27/20.
//  Copyright © 2020 Amrinder Gill. All rights reserved.
//

import Foundation
import UIKit

class PeripheralTableViewCell: UITableViewCell {

    @IBOutlet weak var peripheralLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
