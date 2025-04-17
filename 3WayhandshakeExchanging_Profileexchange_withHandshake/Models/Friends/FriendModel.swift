//
//  Friend.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import Foundation

struct Friend: Identifiable, Codable {
    let id: UUID
    let uuid: String
    var nickname: String
    var profileURL: String? = nil
    var badges: [Badge] = []
}

