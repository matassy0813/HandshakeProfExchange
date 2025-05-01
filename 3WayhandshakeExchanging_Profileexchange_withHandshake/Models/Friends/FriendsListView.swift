//
//  FriendsListView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI

struct FriendRow: View {
    let friend: Friend
    let onTapAlbum: () -> Void
    let onShowAlbum: (Friend) -> Void
    @ObservedObject var friendManager: FriendManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(friend.nickname)
                    .font(.headline)
                if let url = friend.profileURL {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            NavigationLink(destination:
                EditNicknameView(
                manager: friendManager,
                uuid: friend.uuid,
                profileURL: friend.profileURL,
                onShowAlbum: onShowAlbum
            )) {
                Text("編集")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onTapAlbum()
            } label: {
                Label("アルバム", systemImage: "photo.on.rectangle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .leading) {
            Button(role: .destructive) {
                friendManager.removeFriend(uuid: friend.uuid)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

struct FriendsListView: View {
    @ObservedObject var friendManager: FriendManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAlbum = false
    @State private var selectedFriend: Friend?
    @EnvironmentObject private var albumManager: AlbumManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(friendManager.friends) { friend in
                    FriendRow(
                        friend: friend,
                        onTapAlbum: {
                            selectedFriend = friend
                            showAlbum = true
                        },
                        onShowAlbum: { friend in
                            selectedFriend = friend
                            showAlbum = true
                        },
                        friendManager: friendManager
                    )
                }
                .onDelete(perform: deleteFriends)
            }
            .navigationTitle("ともだちリスト")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showAlbum) {
            if let selectedFriend = selectedFriend {
                AlbumView(
                    albumManager: albumManager,
                    senderUUID: selectedFriend.uuid,
                    nickname: selectedFriend.nickname,
                    requiresShake: true
                )
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
