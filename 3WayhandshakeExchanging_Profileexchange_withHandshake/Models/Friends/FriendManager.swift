//
//  FriendManager.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//
import Foundation
import SwiftUI

class FriendManager: ObservableObject {
    @Published var friends: [Friend] = []
    private let key = "friends_list"
    
    private var pendingBadges: [Badge] = []


    init() {
        loadFriends()
    }

    // MARK: - 永続化処理
    // 1. データ読み込み
    func loadFriends() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            self.friends = decoded
        }
    }

    // 2. データ保存
    func saveFriends() {
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // 7. 全リセット
    func clearFriends() {
        friends.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - フレンド管理
    // 3. フレンドの存在確認
    func hasFriend(uuid: String) -> Bool {
        return friends.contains { $0.uuid == uuid }
    }

    // 4. 新しいフレンドを追加
    /// 新しいフレンドを追加（プロフィールURLも保存）
    func addFriend(uuid: String, nickname: String, profileURL: String?) {
        guard !hasFriend(uuid: uuid) else { return }

        if friends.contains(where: { $0.nickname == nickname }) {
            print("⚠️ このニックネームはすでに使われています")
            return
        }

        let newFriend = Friend(id: UUID(), uuid: uuid, nickname: nickname, profileURL: profileURL, badges: pendingBadges)
            friends.append(newFriend)
            pendingBadges = [] // ✅ 登録後はクリア
            saveFriends()
        }


    // 5. ニックネーム取得
    func getNickname(for uuid: String) -> String? {
        return friends.first(where: { $0.uuid == uuid })?.nickname
    }

    // 6. ニックネーム更新
    func updateNickname(for uuid: String, newNickname: String) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            friends[index].nickname = newNickname
            saveFriends()
        }
    }
    // 8. フレンドを削除（追加する関数）
    func removeFriend(uuid: String) {
        friends.removeAll { $0.uuid == uuid }
        saveFriends()
    }
    // 同じ名前がいないか確認
    func isNicknameDuplicate(_ nickname: String) -> Bool {
        return friends.contains { $0.nickname == nickname }
    }

    func updateProfileURL(for uuid: String, url: String) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            friends[index].profileURL = url
            saveFriends()
        }
    }
    // ✅ UUIDで指定されたフレンドのプロフィールURLを更新
    func updateProfileURL(for uuid: String, newURL: String) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            friends[index].profileURL = newURL
            saveFriends()
        }
    }
    
    // 友だちにバッジを追加
    func addBadge(to uuid: String, badge: Badge) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            // 重複バッジは追加しない
            if !friends[index].badges.contains(where: { $0.id == badge.id }) {
                friends[index].badges.append(badge)
                saveFriends()
            }
        }
    }


    
    func mergeBadges(for uuid: String, newBadges: [Badge]) {
        if let index = friends.firstIndex(where: { $0.uuid == uuid }) {
            let existing = friends[index].badges.map { $0.name }
            let filtered = newBadges.filter { !existing.contains($0.name) }
            friends[index].badges.append(contentsOf: filtered)
            saveFriends()
        }
    }

    // MARK: - 自分のバッジ取得
    // MARK: - 自分のバッジ取得
    func getMyBadges() -> [Badge] {
        // 一時的に "GentleMan" バッジを自分のバッジとして返す（実際にはユーザー設定に応じて管理する）
        return [Badge(id: UUID(), name: "GentleMan", description: "礼儀正しく、丁寧な印象", imageName: "GentleManBadge")]
    }


    // 新しいバッジを一時保存
    func storeTemporaryBadges(badges: [Badge]) {
        pendingBadges = badges
    }
    
    // すでに登録されている友達にバッジを追加（重複なし）
    func appendBadges(for uuid: String, newBadges: [Badge]) {
        guard let index = friends.firstIndex(where: { $0.uuid == uuid }) else { return }
        var existing = friends[index].badges
        for badge in newBadges {
            if !existing.contains(where: { $0.id == badge.id }) {
                existing.append(badge)
            }
        }
        friends[index].badges = existing
        saveFriends()
    }
    // すべての友達のバッジを結合して返す
    func getAllBadges() -> [Badge] {
        return friends.flatMap { $0.badges }
    }

    
    
}
