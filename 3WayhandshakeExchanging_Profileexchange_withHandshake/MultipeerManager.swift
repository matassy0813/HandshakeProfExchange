import Foundation
import MultipeerConnectivity
import Combine

class MultipeerManager: NSObject, ObservableObject {
    // MARK: - 公開プロパティ
    @Published var receivedData: Data? = nil
    @Published var lastReceivedID: String?

    private(set) var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    private let serviceType = "shkshare"

    // MARK: - 初期化
    override init() {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType) // ✅ ここも super.init の前に

        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }


    // MARK: - データ送信
    func send(data: Data) {
        guard !session.connectedPeers.isEmpty else {
            print("⚠️ 接続中のピアがいません")
            return
        }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("✅ データ送信成功")
        } catch {
            print("❌ 送信エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - 終了処理
    func stop() {
        advertiser.stopAdvertisingPeer()
        session.disconnect()
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            print("📥 データ受信: \(peerID.displayName)")
            self.receivedData = data

            // ✅ UUIDとして文字列に変換して保持
            if let receivedID = String(data: data, encoding: .utf8) {
                self.lastReceivedID = receivedID
                print("🛰️ 受信したUUID: \(receivedID)")
            }
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let stateString: String
        switch state {
        case .connected:
            stateString = "🟢 接続済み"
        case .connecting:
            stateString = "🟡 接続中"
        case .notConnected:
            stateString = "🔴 未接続"
        @unknown default:
            stateString = "❓ 未知の状態"
        }

        print("ℹ️ ピア状態変更: \(peerID.displayName) - 状態: \(stateString)")
    }



    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📡 招待を受信: \(peerID.displayName)")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ アドバタイズ開始失敗: \(error.localizedDescription)")
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("🔍 ピア発見: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("⚠️ ピアロスト: \(peerID.displayName)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ ブラウズ開始失敗: \(error.localizedDescription)")
    }
}

