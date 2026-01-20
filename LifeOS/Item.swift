//
//  Item.swift
//  LifeOS
//
//  Created by 程馨 on 2026/1/20.
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
