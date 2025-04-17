//
//  BadgePickerView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI

struct BadgePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let badges: [Badge]
    let onBadgeSelected: (Badge) -> Void
    let targetUUID: String
    var onSelectionConfirmed: (([Badge]) -> Void)? = nil
    var onSendBadges: (([Badge]) -> Void)? = nil // ← 追加（OptionalにしてもOK）

    @State private var selectedBadges: [Badge] = []


    @ObservedObject var friendManager: FriendManager


    var body: some View {
        NavigationView {
            List(badges) { badge in
                HStack {
                    Image(badge.imageName) // ← Assetsの画像名
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(badge.name)
                            .font(.headline)
                        Text(badge.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    Button("追加") {
                        if !selectedBadges.contains(where: { $0.id == badge.id }) {
                            selectedBadges.append(badge)
                        }
                    }

                }
                .padding(.vertical, 4)
            }
            .navigationTitle("バッジを選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("選択完了") {
                        if let confirm = onSelectionConfirmed {
                            confirm(selectedBadges)
                        }
                        if let send = onSendBadges{
                            send(selectedBadges)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
