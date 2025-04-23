//
//  AlbumCalendarView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/22.
//

// 📁 Views/Album/AlbumCalendarView.swift（新規作成）

import SwiftUI

struct AlbumCalendarView: View {
    @ObservedObject var albumManager: AlbumManager
    @State private var selectedDate: Date?
    @State private var showPhotosForDate = false

    var body: some View {
        VStack {
            // 日付リストを並べる（簡易カレンダー）
            let grouped = albumManager.photosGroupedByDate()
            ScrollView {
                ForEach(grouped.keys.sorted(by: >), id: \.self) { date in
                    if let photos = grouped[date], let firstImage = photos.first?.imageData,
                       let uiImage = UIImage(data: firstImage) {
                        VStack {
                            Text(formatted(date))
                                .font(.headline)
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedDate = date
                                    showPhotosForDate = true
                                }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotosForDate) {
            if let date = selectedDate,
               let photos = albumManager.photosGroupedByDate()[date] {
                ScrollView {
                    VStack {
                        ForEach(photos) { photo in
                            if let image = UIImage(data: photo.imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                                    .onTapGesture {
                                        // 将来的に拡大表示
                                    }
                            }
                        }
                    }
                }
            }
        }
    }

    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
