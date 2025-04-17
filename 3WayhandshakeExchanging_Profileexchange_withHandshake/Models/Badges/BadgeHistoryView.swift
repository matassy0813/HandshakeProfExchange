//
//  BadgeHistoryView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/17.
//

// ファイル名: Views/Badge/BadgeHistoryView.swift

import SwiftUI

struct BadgeHistoryView: View {
    let badges: [Badge]

    var body: some View {
        NavigationView {
            List(badges) { badge in
                HStack {
                    Image(badge.imageName)
                        .resizable()
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading) {
                        Text(badge.name)
                            .font(.headline)
                        Text(badge.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("🎖️ バッジ履歴")
        }
    }
}
