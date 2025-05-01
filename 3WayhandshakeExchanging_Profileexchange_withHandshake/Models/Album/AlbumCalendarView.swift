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
    @State private var selectedPhoto: AlbumPhoto?
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        VStack {
            Text("あなたの紡いだ思い出🎵")
                    .font(.title2)
                    .padding(.top, 16)
            // 日付リストを並べる（簡易カレンダー）
            let grouped = albumManager.photosGroupedByDate()
            ScrollView {
                ForEach(grouped.keys.sorted(by: >), id: \.self) { date in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatted(date))
                            .font(.headline)
                            .padding(.leading)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                            ForEach(grouped[date] ?? []) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 16)
                }
            }

        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            VStack {
                Image(uiImage: UIImage(data: photo.imageData)!)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                Button("閉じる") {
                    selectedPhoto = nil
                }
                Button("削除") {
                    showDeleteConfirm = true
                }
                .alert(isPresented: $showDeleteConfirm) {
                    Alert(
                        title: Text("削除してもよろしいですか？"),
                        primaryButton: .destructive(Text("削除")) {
                            albumManager.deletePhoto(photo)
                            selectedPhoto = nil // ✅ 拡大ビューだけ閉じる
                        },
                        secondaryButton: .cancel()
                    )
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
