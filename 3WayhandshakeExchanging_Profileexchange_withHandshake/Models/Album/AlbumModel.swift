//
//  AlbumModel.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/22.
//
import SwiftUI
import Foundation

// 修正後:
struct AlbumPhoto: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let date: Date
    let senderUUID: String  // ← 修正されたプロパティ名
    let message: String
}

