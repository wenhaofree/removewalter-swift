//
//  Item.swift
//  removewalter-swift
//
//  Created by wenhao on 2026/2/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
