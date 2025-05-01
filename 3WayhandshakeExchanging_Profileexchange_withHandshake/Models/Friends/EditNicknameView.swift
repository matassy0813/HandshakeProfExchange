//
//  EditNicknameView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

import SwiftUI
import SafariServices

struct EditNicknameView: View {
    @ObservedObject var manager: FriendManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var albumManager = AlbumManager()
    @State private var showAlbum = false

    @State private var newName: String = ""
    @State private var showSafari = false
    
    let uuid: String
    let profileURL: String?
    var badges: [Badge] {
        manager.getMyBadges()
    }


    var onShowAlbum: (Friend) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("ニックネームを編集")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            TextField("ニックネームを入力", text: $newName)
                .onAppear {
                    self.newName = manager.getNickname(for: uuid) ?? ""
                }

                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("保存") {
                guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                
                if manager.hasFriend(uuid: uuid) {
                    manager.updateNickname(for: uuid, newNickname: newName)
                    if let profileURL = profileURL {
                        manager.updateProfileURL(for: uuid, newURL: profileURL)
                    }
                } else {
                    manager.registerFriend(uuid: uuid, nickname: newName, profileURL: profileURL)
                }

                if let friend = manager.getFriend(by: uuid) {
                    onShowAlbum(friend)
                }

                presentationMode.wrappedValue.dismiss()
            }

            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            
            Divider()

            // ✅ URLがある場合のみボタンを表示
            if let url = profileURL, !url.isEmpty {
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
                manager.removeFriend(uuid: uuid)
                presentationMode.wrappedValue.dismiss()
            }
            
            // 友達とのアルバムを見るボタン
            Button("📸 アルバムを見る") {
                showAlbum = true
            }
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(10)

            .padding()
            
            if let urlString = profileURL, let url = URL(string: urlString) {
                Button("🌐 プロフィールURLを開く") {
                    UIApplication.shared.open(url)
                }
                .padding(.top, 8)
            }
            
            // 🔽 ここにバッジ表示を追加

            if !badges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("付与されたバッジ")
                        .font(.headline)
                        .padding(.top)

                    ForEach(badges) { badge in
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
        .fullScreenCover(isPresented: $showAlbum) {
            AlbumView(albumManager: albumManager, senderUUID: uuid, nickname: newName)
        }
    }
}


