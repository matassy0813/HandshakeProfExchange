import Foundation
import SwiftUI

// MARK: - 共有履歴データモデル
struct ShareLog: Codable, Identifiable {
    let id: UUID
    let date: Date
    let method: String // "QR" or "AirDrop"
    
    init(date: Date, method: String) {
        self.id = UUID()
        self.date = date
        self.method = method
    }
}

// MARK: - バッジ送信Payload
struct OutgoingPayload: Codable {
    let uuid: String
    let profileURL: String
    let badges: [Badge]
}

// MARK: - 写真送信Payload
struct PhotoPayload: Codable {
    let type: String  // "photo"
    let from: String
    let to: String
    let frontImage: Data
    let backImage: Data
    let message: String
} 
