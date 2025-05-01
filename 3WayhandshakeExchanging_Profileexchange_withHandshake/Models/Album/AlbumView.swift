//
//  AlbumView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/22.
//

import SwiftUI
import CoreMotion

struct AlbumView: View {
    @ObservedObject var albumManager: AlbumManager
    @State private var selectedPhoto: AlbumPhoto?
    @State private var showPhotoViewer = false
    @Environment(\.dismiss) private var dismiss
    @State private var isShaking = false
    @State private var showDeleteConfirm = false

    
    let nickname: String
    let senderUUID: String
    let requiresShake: Bool
    
    @State private var showContent = false
    let motionManager = CMMotionManager()
    
    init(albumManager: AlbumManager, senderUUID: String, nickname: String = "ともだち", requiresShake: Bool = false) {
        self.albumManager = albumManager
        self.senderUUID = senderUUID
        self.nickname = nickname
        self.requiresShake = requiresShake
        self._showContent = State(initialValue: !requiresShake)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // カスタムナビゲーションバー
            HStack {
                Text("この人とのアルバム📸")
                    .font(.headline)
                Spacer()
                Button("閉じる") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            if !showContent {
                // シェイク前の表示
                VStack {
                    Spacer()
                    Text("📱 シェイクして表示！！")
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue)
                        .scaleEffect(isShaking ? 1.1 : 1.0)
                        .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isShaking)
                    Spacer()
                }
                .onAppear {
                    isShaking = true
                    startShakeDetection()
                }
            } else {
                // メインコンテンツ
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(nickname)とのアルバム！！")
                            .font(.title)
                            .bold()
                            .padding(.top, 8)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(albumManager.photos(from: senderUUID).sorted(by: { $0.date > $1.date })) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            selectedPhoto = photo
                                            showPhotoViewer = true
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
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
                    Button("削除") {
                        showDeleteConfirm = true
                    }
                    .alert(isPresented: $showDeleteConfirm) {
                        Alert(
                            title: Text("削除してもよろしいですか？"),
                            primaryButton: .destructive(Text("削除")) {
                                albumManager.deletePhoto(photo)
                                selectedPhoto = nil
                                showPhotoViewer = false 
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                .padding()
            }
        }
        .onDisappear {
            motionManager.stopAccelerometerUpdates()
        }
    }
    
    private func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
            guard let acceleration = data?.acceleration else { return }
            if abs(acceleration.x) > 2.5 || abs(acceleration.y) > 2.5 || abs(acceleration.z) > 2.5 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}
