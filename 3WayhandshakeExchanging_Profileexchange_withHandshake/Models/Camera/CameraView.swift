//
//  CameraView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/20.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @ObservedObject var cameraManager: CameraManager
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var previewImage: UIImage? = nil
    @State private var showPreview = false

    var body: some View {
        ZStack {
            cameraPreview()              // 🔵 カメラプレビュー
            topOverlay()                 // 🔵 上部情報表示
            bottomOverlay()              // 🔵 シャッターと戻る
            CameraPreviewView(session: cameraManager.session)
                        .edgesIgnoringSafeArea(.all)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        
        if showPreview, let image = previewImage {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .padding()

                Text("🌟 最高のメンツ！")
                    .font(.title2)
                    .bold()
                    .padding(.bottom)

                Button("戻る") {
                    showPreview = false
                    onCancel()
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.7))
            .edgesIgnoringSafeArea(.all)
        }

    }

    // MARK: - カメラプレビュー
    private func cameraPreview() -> some View {
        GeometryReader { geometry in
            CameraPreviewView(session: cameraManager.session)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    // MARK: - 上部オーバーレイ
    private func topOverlay() -> some View {
        VStack {
            Text("📸 2分以内に撮影してください！")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - 下部オーバーレイ
    private func bottomOverlay() -> some View {
        VStack {
            Spacer()
            HStack(spacing: 40) {
                cancelButton()
                captureButton()
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - シャッターボタン
    private func captureButton() -> some View {
        Button(action: {
            // 撮影時は、まだ送信せずプレビューだけ表示
            cameraManager.capturePhoto { image in
                previewImage = image
                showPreview = true
            }
        }) {
            Image(systemName: "camera.circle.fill")
                .resizable()
                .frame(width: 70, height: 70)
                .foregroundColor(.white)
        }
        // プレビュー用fullScreenCover
        .fullScreenCover(isPresented: $showPreview) {
            if let image = previewImage {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text("最高のメンツ！")
                        .font(.title)
                        .padding()
                    HStack {
                        // ★★ ここで初めてonCaptureを呼び出して送信！
                        Button("送信") {
                            onCapture(image)
                            showPreview = false
                        }
                        .padding()
                        Button("撮り直し") {
                            previewImage = nil
                            showPreview = false
                        }
                        .padding()
                    }
                }
                .background(Color.black)
            }
        }
    }

    // MARK: - キャンセルボタン
    private func cancelButton() -> some View {
        Button(action: onCancel) {
            Text("キャンセル")
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
        }
    }
    // MARK: - カメラ切り替えボタン
    private func switchCameraButton() -> some View {
        Button(action: {
            cameraManager.toggleCamera()
        }) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
        }
    }

}
