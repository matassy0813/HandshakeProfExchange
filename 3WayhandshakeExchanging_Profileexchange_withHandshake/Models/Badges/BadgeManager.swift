//
//  BadgeManager.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI
import Foundation
import MultipeerConnectivity

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

    // バッジを友達に送信する（バッジ付与＋Multipeer通信）
    func sendBadge(
        _ badge: Badge,
        to friendUUID: String,
        from userUUID: String,
        friendManager: FriendManager,
        multipeerManager: MultipeerManager
    ) {
        // 1. ローカルで友達にバッジを付与
        assignBadge(badge, to: friendUUID, in: friendManager)
        // 2. Multipeer通信で相手にバッジ情報を送信
        let payload = BadgePayload(type: .badge, from: userUUID, to: friendUUID, badge: badge)
        if let data = try? JSONEncoder().encode(payload) {
            multipeerManager.send(data: data)
        }
        print("\(badge.name) バッジを \(friendUUID) に送信しました（ローカル付与＋通信）")
    }
}

struct BadgePayload: Codable {
    enum PayloadType: String, Codable {
        case uuid, badge
    }
    let type: PayloadType
    let from: String
    let to: String
    let badge: Badge
}

