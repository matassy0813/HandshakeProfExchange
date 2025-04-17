//
//  FriendsListView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI

struct FriendsListView: View {
    @ObservedObject var friendManager: FriendManager
    @Environment(\.dismiss) private var dismiss  // ✅ これを追加

    var body: some View {
        NavigationView {
            List {
                ForEach(friendManager.friends, id: \.id) { friend in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(friend.nickname.isEmpty ? "（ニックネーム未設定）" : friend.nickname)
                                .font(.headline)
                            Text(friend.uuid)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        NavigationLink(destination: EditNicknameView(friend: friend, manager: friendManager)) {
                            Text("編集")
                        }
                    }
                }
                .onDelete(perform: deleteFriends)
            }
            .navigationTitle("ともだちリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("戻る") {
                        dismiss()  // ✅ 画面を閉じる
                    }
                }
            }
        }
    }

    func deleteFriends(at offsets: IndexSet) {
        for index in offsets {
            let uuid = friendManager.friends[index].uuid
            friendManager.removeFriend(uuid: uuid)
        }
    }
}
