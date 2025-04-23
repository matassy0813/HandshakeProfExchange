//
//  EditNicknameView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI
import SafariServices

struct EditNicknameView: View {
    let friend: Friend
    @ObservedObject var manager: FriendManager
    @Environment(\.presentationMode) var presentationMode

    @State private var newName: String = ""
    @State private var showSafari = false

    var body: some View {
        VStack(spacing: 20) {
            Text("ニックネームを編集")
                .font(.title2)

            TextField("新しいニックネーム", text: $newName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("保存") {
                manager.updateNickname(for: friend.uuid, newNickname: newName)
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            
            Divider()

            // ✅ URLがある場合のみボタンを表示
            if let url = friend.profileURL, !url.isEmpty {
                Text("プロフィールURL:")
                    .font(.subheadline)
                Text(url)
                    .font(.caption)
                    .foregroundColor(.gray)

                Button("Webで開く") {
                    showSafari = true
                }
                .sheet(isPresented: $showSafari) {
                    if let validURL = URL(string: url) {
                        SafariView(url: validURL)
                    } else {
                        Text("⚠️ 無効なURLです")
                    }
                }
            }

            // 🔴 ここに削除ボタンを追加
            Button("この友だちを削除", role: .destructive) {
                manager.removeFriend(uuid: friend.uuid)
                presentationMode.wrappedValue.dismiss()
            }
            // 友達とのアルバムを見るボタン
            Button("📸 アルバムを見る") {
                manager.selectedFriendForAlbum = friend
                manager.showFriendAlbum = true
            }
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(10)

            .padding()
            
            if let urlString = friend.profileURL, let url = URL(string: urlString) {
                Button("🌐 プロフィールURLを開く") {
                    UIApplication.shared.open(url)
                }
                .padding(.top, 8)
            }
            // 🔽 ここにバッジ表示を追加
            if !friend.badges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("付与されたバッジ")
                        .font(.headline)
                        .padding(.top)

                    ForEach(friend.badges) { badge in
                        HStack {
                            Image(badge.imageName)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(badge.name)
                                .font(.subheadline)
                            Spacer()
                            Text(badge.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 16)
            }

            
            
        }
        .padding()
        .onAppear {
            newName = friend.nickname
        }
        
    }
}


