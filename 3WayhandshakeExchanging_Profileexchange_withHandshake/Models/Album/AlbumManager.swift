//
//  AlbumManager.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/22.
//

import Foundation
import SwiftUI

class AlbumManager: ObservableObject {
    @Published var allPhotos: [AlbumPhoto] = []
    private let userDefaults = UserDefaults.standard
    private let photosKey = "saved_photos"
    
    init() {
        loadPhotos()
    }
    
    // 自分が受け取った写真のみを抽出
    func photos(from senderUUID: String) -> [AlbumPhoto] {
        return allPhotos.filter { $0.senderUUID == senderUUID }
    }

    // 日付ごとのグループ化（カレンダー表示に必要）
    func photosGroupedByDate() -> [Date: [AlbumPhoto]] {
        Dictionary(grouping: allPhotos) { photo in
            Calendar.current.startOfDay(for: photo.date)
        }
    }

    // 写真の追加
    func addPhoto(_ image: UIImage, from senderUUID: String, message: String = "思い出を紡ごう！") {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let newPhoto = AlbumPhoto(id: UUID(), imageData: imageData, date: Date(), senderUUID: senderUUID, message: message)
        allPhotos.append(newPhoto)
        savePhotos()
    }

    
    // 写真IDで1枚取得（拡大表示用）
    func photo(with id: UUID) -> AlbumPhoto? {
        return allPhotos.first { $0.id == id }
    }
    
    // 写真データの保存
    private func savePhotos() {
        if let encoded = try? JSONEncoder().encode(allPhotos) {
            userDefaults.set(encoded, forKey: photosKey)
        }
    }
    
    // 写真データの読み込み
    private func loadPhotos() {
        if let data = userDefaults.data(forKey: photosKey),
           let decoded = try? JSONDecoder().decode([AlbumPhoto].self, from: data) {
            DispatchQueue.main.async {
                self.allPhotos = decoded
            }
        }
    }
    
    func deletePhoto(_ photo: AlbumPhoto) {
        allPhotos.removeAll { $0.id == photo.id }
        savePhotos()
    }

}
