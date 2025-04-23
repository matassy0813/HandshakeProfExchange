//
//  CameraManager.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/20.
//

import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    
    @Published var photo: UIImage? = nil

    override init() {
        super.init()
        configureSession()
    }

    // セッションを設定する
    private func configureSession() {
        session.beginConfiguration()

        // 入力デバイス設定
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        // 出力設定
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
    }

    // プレビュー用の AVCaptureVideoPreviewLayer を返す
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer!
    }

    // セッション開始・停止
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // 写真を撮る
    // MARK: - 写真撮影処理
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: PhotoCaptureProcessor(completion: completion))
    }



    // 撮影完了時に呼ばれる
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("⚠️ 写真の取得に失敗しました")
            return
        }
        DispatchQueue.main.async {
            self.photo = image
        }
    }
    
    func toggleCamera() {
        session.beginConfiguration()

        // Remove existing input
        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }

        // Toggle position
        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back

        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let newInput = try? AVCaptureDeviceInput(device: newDevice),
           session.canAddInput(newInput) {
            session.addInput(newInput)
        }

        session.commitConfiguration()
    }
}

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completionHandler: (UIImage) -> Void

    init(completion: @escaping (UIImage) -> Void) {
        self.completionHandler = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            completionHandler(image)
        }
    }

}
