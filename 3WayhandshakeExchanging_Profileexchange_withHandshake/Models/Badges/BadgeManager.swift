//
//  BadgeManager.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI
import Foundation

// MARK: - バッジ管理
class BadgeManager: ObservableObject {
    @Published var allBadges: [Badge] = [
        Badge(id: UUID(), name: "ジェントルマン", description: "礼儀正しく、丁寧な印象", imageName: "GentleManBadge")
        // 他のバッジもここに追加可能
    ]

    // 単一バッジの付与
    func assignBadge(_ badge: Badge, to friendUUID: String, in friendManager: FriendManager) {
        friendManager.appendBadges(for: friendUUID, newBadges: [badge])
    }

    // 複数バッジの付与
    func assignBadges(_ badges: [Badge], to friendUUID: String, in friendManager: FriendManager) {
        for badge in badges {
            assignBadge(badge, to: friendUUID, in: friendManager)
        }
    }
}
