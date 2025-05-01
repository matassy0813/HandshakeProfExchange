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
    private var currentProcessor: AVCapturePhotoCaptureDelegate? = nil
    
    public var currentCameraPosition: AVCaptureDevice.Position = .back
    
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
        let processor = PhotoCaptureProcessor(completion: completion)
        self.currentProcessor = processor
        output.capturePhoto(with: settings, delegate: processor)
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
        
    /// カメラ切替（Position: .front or .back）
    func switchCamera(to position: AVCaptureDevice.Position, completion: @escaping () -> Void) {
        session.beginConfiguration()
        // Remove old input
        if let oldInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(oldInput)
        }
        // Add new input
        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let newInput = try? AVCaptureDeviceInput(device: newDevice),
           session.canAddInput(newInput) {
            session.addInput(newInput)
            currentCameraPosition = position
        }
        session.commitConfiguration()
        completion()
    }

    func sendPhoto(front: UIImage, back: UIImage, to uuid: String, multipeerManager: MultipeerManager) {
        guard let userUUID = UserDefaults.standard.string(forKey: "userUUID") else { return }

        let payload = PhotoPayload(
            type: "photo",
            from: userUUID,
            to: uuid,
            frontImage: front.jpegData(compressionQuality: 0.8)!,
            backImage: back.jpegData(compressionQuality: 0.8)!,
            message: "最高のメンツ！"
        )

        if let data = try? JSONEncoder().encode(payload) {
            multipeerManager.send(data: data)
        }
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
