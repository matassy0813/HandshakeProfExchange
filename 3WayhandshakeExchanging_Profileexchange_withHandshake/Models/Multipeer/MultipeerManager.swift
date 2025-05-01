// MultipeerManager.swift
import Foundation
import MultipeerConnectivity
import CoreMotion
import UIKit
import Combine

public class MultipeerManager: NSObject, ObservableObject {
    @Published public var isConnected = false
    @Published public var receivedNickname = ""
    @Published public var receivedUUID = ""
    @Published public var isHandshakeDetected = false
    @Published public var receivedBadges: [String] = []
    @Published public var receivedData: Data?
    @Published public var lastReceivedID: String? = nil
    @Published public var receivedProfileURL: String? = nil

    public var userUUID: String = ""
    public var userProfileURL: String = ""
    var albumManager: AlbumManager?

    private let serviceType = "shkshare"
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private let motionManager = CMMotionManager()

    public override init() {
        super.init()
        setupSession()
        setupMotionManager()
    }

    private func setupSession() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        print("✅ Advertiser & Browser started")
    }

    private func setupMotionManager() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            let shakeThreshold = 2.5
            if abs(acceleration.x) > shakeThreshold || abs(acceleration.y) > shakeThreshold || abs(acceleration.z) > shakeThreshold {
                self.detectHandshake()
            }
        }
        print("✅ MotionManager started")
    }

    private func detectHandshake() {
        guard !isHandshakeDetected else { return }
        DispatchQueue.main.async {
            self.isHandshakeDetected = true
            print("🤝 Handshake detected")
        }
    }

    public func sendProfileAndBadges(nickname: String, uuid: String, profileURL: String = "", badges: [String] = []) {
        let payload: [String: Any] = [
            "type": "profile",
            "nickname": nickname,
            "uuid": uuid,
            "profileURL": profileURL,  // ✅ 追加！！
            "badges": badges
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            send(data: data)
        }
    }

    public func send(data: Data) {
        guard let session = session, !session.connectedPeers.isEmpty else {
            print("⚠️ No connected peers to send data")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("✅ Data sent successfully")
        } catch {
            print("❌ Send error: \(error.localizedDescription)")
        }
    }
    
    public func startAdvertisingAndBrowsingForLimitedTime(seconds: Int = 4) {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        print("🚀 探索開始（制限時間: \(seconds)秒）")

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
            self.advertiser.stopAdvertisingPeer()
            self.browser.stopBrowsingForPeers()
            print("🛑 探索停止")
        }
    }


    deinit {
        motionManager.stopAccelerometerUpdates()
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        print("🛑 MultipeerManager deinitialized")
    }
}

extension MultipeerManager: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = state == .connected
            switch state {
            case .connected:
                print("🟢 Connected to \(peerID.displayName)")
                self.sendProfileAndBadges(
                    nickname: self.myPeerId.displayName,
                    uuid: self.userUUID,
                    profileURL: self.userProfileURL
                )

            case .connecting:
                print("🟡 Connecting to \(peerID.displayName)")
            case .notConnected:
                print("🔴 Disconnected from \(peerID.displayName)")
                self.isHandshakeDetected = false
                self.receivedBadges = []
            @unknown default:
                print("❓ Unknown state for \(peerID.displayName)")
            }
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.receivedData = data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "profile":
                    self.receivedNickname = json["nickname"] as? String ?? ""
                    self.receivedUUID = json["uuid"] as? String ?? ""
                    self.receivedProfileURL = json["profileURL"] as? String ?? "" // ← ✅ ここ！！
                    self.lastReceivedID = self.receivedUUID
                    self.receivedBadges = json["badges"] as? [String] ?? []
                    print("📥 Profile received: \(self.receivedUUID)")

                case "badge":
                    if let badge = json["badge"] as? String {
                        self.receivedBadges.append(badge)
                        print("🎖️ Badge received: \(badge)")
                    }
                    
                case "photo":
                  if let photoPayload = try? JSONDecoder().decode(PhotoPayload.self, from: data) {
                      if let front = UIImage(data: photoPayload.frontImage),
                         let back = UIImage(data: photoPayload.backImage) {
                          if let albumManager = self.albumManager {
                              albumManager.addPhoto(front, from: photoPayload.from, message: "受信:自撮り")
                              albumManager.addPhoto(back, from: photoPayload.from, message: "受信:外カメ")
                          }

                      }
                  }
                default:
                    print("📦 Unknown data type received")
                }
            } else {
                print("❌ JSON decoding failed")
            }
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📡 Invitation received from \(peerID.displayName)")
        invitationHandler(true, session)
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("🔍 Found peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("⚠️ Lost peer: \(peerID.displayName)")
    }
}
