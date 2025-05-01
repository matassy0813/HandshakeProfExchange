//
//  BadgeModel.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import Foundation

struct Badge: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var imageName: String
}

enum PayloadType: String, Codable {
    case uuid
    case badge
}

