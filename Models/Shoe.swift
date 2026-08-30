//
//  Shoe.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 8/28/26.
//

import Foundation
import SwiftData

@Model
final class Shoe {
    var id: UUID
    var name: String
    var startDate: Date
    var isRetired: Bool

    init(name: String, startDate: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.isRetired = false
    }
}
