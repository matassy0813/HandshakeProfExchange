//
//  AlbumView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/22.
//

import SwiftUI

struct AlbumView: View {
    @ObservedObject var albumManager: AlbumManager
    @State private var selectedPhoto: AlbumPhoto?
    @State private var showPhotoViewer = false
    
    let senderUUID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(albumManager.photos(from: senderUUID).sorted(by: { $0.date > $1.date })) { photo in
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(10)
                            .padding()
                            .onTapGesture {
                                selectedPhoto = photo
                                showPhotoViewer = true
                            }
                    }
                }
            }
        }
        .navigationTitle("この人とのアルバム📸")
        .sheet(isPresented: $showPhotoViewer) {
            if let photo = selectedPhoto, let image = UIImage(data: photo.imageData) {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                    Text("たまらないね！")
                        .font(.headline)
                        .padding()
                    Button("閉じる") {
                        showPhotoViewer = false
                    }
                }
                .padding()
            }
        }

    }
}
