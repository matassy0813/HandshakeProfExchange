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
    var onCapture: (UIImage, UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var frontImage: UIImage? = nil
    @State private var backImage: UIImage? = nil
    @State private var showPreview = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
            topOverlay()                 // 🔵 上部情報表示
            bottomOverlay()              // 🔵 シャッターと戻る
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    // MARK: - 上部オーバーレイ
    private func topOverlay() -> some View {
        VStack {
            HStack {
                Text("📸 2分以内に撮影してください！")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                switchCameraButton()
            }
            .padding([.top, .horizontal], 20)
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
        Button(action: captureBeRealPhoto) {
            Circle().frame(width: 80, height: 80).foregroundColor(.white)
                .overlay(Circle().stroke(Color.blue, lineWidth: 4))
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
    // --- 関数分離 ---
    // MARK: - BeReal風の2枚撮影ロジック
    private func captureBeRealPhoto() {
        
        let startPosition = cameraManager.currentCameraPosition
        cameraManager.switchCamera(to: startPosition) {
            cameraManager.capturePhoto { firstImage in
                if startPosition == .back {
                    self.backImage = firstImage
                } else {
                    self.frontImage = firstImage
                }

                // 3秒後に反対側
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let nextPosition: AVCaptureDevice.Position = (startPosition == .back) ? .front : .back
                    cameraManager.switchCamera(to: nextPosition) {
                        cameraManager.capturePhoto { secondImage in
                            if startPosition == .back {
                                self.frontImage = secondImage
                            } else {
                                self.backImage = secondImage
                            }
                            if let front = frontImage, let back = backImage {
                                onCapture(front, back)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func clearImages() {
        self.frontImage = nil
        self.backImage = nil
    }
}

struct PhotoPreviewView: View {
    var frontImage: UIImage?
    var backImage: UIImage?
    var onSend: () -> Void
    var onRetry: () -> Void

    var body: some View {
        VStack {
            HStack {
                if let front = frontImage {
                    Image(uiImage: front)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .cornerRadius(12)
                }
                if let back = backImage {
                    Image(uiImage: back)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .cornerRadius(12)
                }
            }
            Text("撮影した写真を確認")
                .font(.headline)
                .padding()
            HStack {
                Button("送信") { onSend() }
                    .padding()
                Button("撮り直し📷") { onRetry() }
                    .padding()
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}
