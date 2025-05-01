import SwiftUI
import CoreMotion
import CoreImage.CIFilterBuiltins
import UIKit
import MultipeerConnectivity
import Foundation

// MARK: - 履歴管理ViewModel
class ShareLogViewModel: ObservableObject {
    @Published var logs: [ShareLog] = []
    private let key = "share_logs"

    init() {
        load()
    }

    func addLog(method: String) {
        let newLog = ShareLog(date: Date(), method: method)
        logs.append(newLog)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([ShareLog].self, from: data) {
            logs = saved
        }
    }
    
    func clearLogs() {
        logs.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }

}

// MARK: - メインビュー

// 🔽 NEW: シートの種類を定義
enum ActiveSheet: Identifiable {
    case settings, friendsList, nickname
    case badgeHistory
    case calendarAlbum

    var id: Int {
        switch self {
        case .settings: return 0
        case .friendsList: return 1
        case .nickname: return 2
        case .badgeHistory: return 3
        case .calendarAlbum: return 4
        }
    }
}

struct ContentView: View {
    let motionManager = CMMotionManager()

    @State private var isSharing = false
    @State private var showQR = false
    @State private var didShake = false
    @State private var isSettingURL = false
    @State private var tempURL: String = ""
    @State private var showMenu = false
    @State private var isLoading = true
    @State private var showMessage = false
    @State private var messageText = ""
    @State private var showReadyMessage = false
    @State private var countdown = 5
    @State private var countdownTimer: Timer? = nil
    
    @State private var nicknameInput = ""
    @State private var newNickname: String = ""
    @State private var pendingUUID: String = ""
    @State private var pendingProfileURL: String? = nil
    
    @State private var selectedBadgeTargetUUID: String? = nil
    @State private var selectedBadges: [Badge] = [] // ✅ 選ばれたバッジ
    @State private var receivedBadges: [Badge] = []
    @State private var showBadgeReceivedSheet = false
    
    @State private var isConnectedToPeer = false // 他人と接続済みフラグ
    
    @State private var isCameraPresented = false
    @State private var capturedImage: UIImage? = nil
    @State private var receivedPhoto: UIImage? = nil
    @State private var showPhotoReceivedSheet: Bool = false
    @State private var receivedPhotoMessage: String? = nil
    @State private var showPreview = false
    @State private var frontImage: UIImage? = nil
    @State private var backImage: UIImage? = nil
    @State private var showBeRealPreview = false
    @State private var showCameraPrompt = false
    @State private var cameraPromptFriendName = ""
    
    @State private var selectedFriendForAlbum: Friend? = nil
    @State private var isAlbumPresented: Bool = false
    @State private var isAlbumViewVisible = false
    
    @State private var activeSheet: ActiveSheet? = nil

    @AppStorage("userProfileURL") private var profileURL: String = ""
    @AppStorage("userUUID") private var userUUID: String = UUID().uuidString
    @AppStorage("countdownDuration") private var countdownDuration: Int = 5

    @StateObject private var logVM = ShareLogViewModel()
    @StateObject private var multipeerManager = MultipeerManager()
    @StateObject private var friendManager = FriendManager()
    @StateObject private var badgeManager = BadgeManager()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var albumManager = AlbumManager()


    @State private var showPhotoPrompt = false
    @State private var photoPromptFriend: Friend? = nil
    @State private var cameraTargetFriend: Friend? = nil
    @State private var showPhotoPreview = false
    @State private var previewFrontImage: UIImage? = nil
    @State private var previewBackImage: UIImage? = nil
    @State private var showBadgePicker = false
    @State private var badgeTargetFriend: Friend? = nil
    @State private var badgeToSend: Badge? = nil
    @State private var showBadgeConfirm = false
    @State private var showBadgeReceivedPopup = false
    @State private var badgeReceivedFrom: String? = nil
    @State private var badgeReceived: Badge? = nil
    
    // MARK: - 自分のバッジ取得
    func getMyBadges() -> [Badge] {
        // 一時的に "GentleMan" バッジを自分のバッジとして返す（実際にはユーザー設定に応じて管理する）
        return [Badge(id: UUID(), name: "GentleMan", description: "礼儀正しく、丁寧な印象", imageName: "GentleManBadge")]
    }

    func showTemporaryMessage(_ text: String) {
        messageText = text
        showMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showMessage = false
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.pink.opacity(0.3), .blue.opacity(0.2)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("読み込み中…")
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                    }
                }
                else {
                    VStack(spacing: 24) {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showMenu.toggle()
                                }
                            }) {
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.white)
                                    .padding(.top, 60)         // ← ✅ 上部余白を明示的に確保
                                    .padding(.leading, 16)     // ← ✅ 左の余白だけ指定（必要に応じて）
                            }
                            Spacer()
                        }
                        Text("✨ Shake & Share ✨")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)

                        if showQR {
                            renderQRCodeView()
                        } else if didShake {
                            renderShareOptionsView()
                        } else {
                            renderShakePrompt()
                        }

                        if !logVM.logs.isEmpty {
                            renderShareLogView()
                        }

                        Spacer()
                    }
                }
                    
                
            }
            .padding()
            .blur(radius: showMenu ? 5 : 0)
            .disabled(showMenu) // ← メニュー表示中はUIを操作不可にする
        
        // サイドメニュー
            if showMenu {
                    // ✅ 背景タップで閉じる透明レイヤー
                    Color.black.opacity(0.001) // ← 非表示だがタップ検出される
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showMenu = false
                            }
                        }

                    // ✅ 左側メニュー表示
                    renderSideMenu()
                        .transition(.move(edge: .leading))
            }
            
        }
        .ignoresSafeArea(.all)
        .onReceive(multipeerManager.$receivedData.compactMap { $0 }) { (data:Data) in

            struct ReceivedPayload: Codable {
                let uuid: String
                let profileURL: String
                let badges: [Badge]
            }

            if let decoded = try? JSONDecoder().decode(ReceivedPayload.self, from: data) {
                let receivedID = decoded.uuid
                let receivedURL = decoded.profileURL
                let receivedBadges = decoded.badges

                print("🛰️ 受信したUUID: \(receivedID)")
                print("🌐 受信したURL: \(receivedURL)")
                print("🎖️ 受信したバッジ数: \(receivedBadges.count)")

                if friendManager.hasFriend(uuid: receivedID) {
                    friendManager.updateProfileURL(for: receivedID, newURL: receivedURL)
                    friendManager.appendBadges(for: receivedID, newBadges: receivedBadges)
                    if let name = friendManager.getNickname(for: receivedID) {
                        showTemporaryMessage("🎉 \(name) さんと通信しました！")

                        // ✅ バイブ追加
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } else {
                    // 新規ならニックネーム登録へ
                    pendingUUID = receivedID
                    pendingProfileURL = receivedURL
                    friendManager.storeTemporaryBadges(badges: receivedBadges)
                    activeSheet = .nickname
                }
                
                // 受信時の処理
                // onReceive(multipeerManager.$receivedData.compactMap { $0 }) { data in ... }
                if let photoPayload = try? JSONDecoder().decode(PhotoPayload.self, from: data),
                       photoPayload.type == "photo" {
                        if let front = UIImage(data: photoPayload.frontImage),
                           let back = UIImage(data: photoPayload.backImage) {
                            albumManager.addPhoto(front, from: photoPayload.from, message: "受信:自撮り")
                            albumManager.addPhoto(back, from: photoPayload.from, message: "受信:外カメ")
                            //　成功バイブ
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            // ここでプレビューUIやメッセージも出す
                            self.receivedPhoto = front // 片方だけプレビューするなら
                            self.receivedPhotoMessage = photoPayload.message
                            self.showPhotoReceivedSheet = true
                        }
                    }
            }
            print("📥 データ受信！解析開始")

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String {
                switch type {
                case "profile":
                    print("✅ プロフィール受信")
                    let uuid = json["uuid"] as? String ?? ""
                    multipeerManager.lastReceivedID = uuid
                    pendingUUID = uuid
                    pendingProfileURL = json["profileURL"] as? String
                    if !friendManager.hasFriend(uuid: uuid) {
                        activeSheet = .nickname
                    }
                case "badge":
                    print("🎖️ バッジ受信")
                    // バッジ処理
                default:
                    print("❓ 未知データ受信")
                }
            } else {
                print("❌ データ解析失敗")
            }
        }
        .onAppear {
            print("🌟 onAppear start")
            isLoading = true
            multipeerManager.albumManager = albumManager
            
            if UserDefaults.standard.string(forKey: "userUUID") == nil {
                UserDefaults.standard.set(userUUID, forKey: "userUUID")
            } else {
                userUUID = UserDefaults.standard.string(forKey: "userUUID")!
            }
            
            // ✅ ここを追加！！
            multipeerManager.userUUID = userUUID
            multipeerManager.userProfileURL = profileURL
            print("🛠 MultipeerManagerにuserUUIDを設定: \(userUUID)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🛠 check & shake start")
                checkInitialURL()
                startShakeDetection()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("✅ isLoading = false")
                    isLoading = false
                }
            }
        }
        .sheet(isPresented: $isSharing) {
            if let url = URL(string: profileURL), UIApplication.shared.canOpenURL(url) {
                ActivityView(activityItems: [url])
            } else {
                VStack {
                    Text("⚠️ URLが無効です。設定してください")
                        .foregroundColor(.red)
                    Button("設定する") {
                        tempURL = ""
                        isSettingURL = true
                        isSharing = false
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isSettingURL) {
            VStack(spacing: 20) {
                Text("プロフィールURLを入力")
                    .font(.headline)

                TextField("https://example.com", text: $tempURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("保存して閉じる") {
                    profileURL = tempURL
                    isSettingURL = false
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
            }
            .padding()
        }
        .sheet(item: $activeSheet) { item in
            switch item {
            case .settings:
                SettingsView()
            case .friendsList:
                FriendsListView(friendManager: friendManager)
                    .environmentObject(albumManager)
            case .nickname:
                EditNicknameView(
                    manager: friendManager,
                    uuid: pendingUUID,
                    profileURL: pendingProfileURL,
                    onShowAlbum: { friend in
                        selectedFriendForAlbum = friend
                        isAlbumViewVisible = true
                    }
                )
            case .badgeHistory:
                BadgeHistoryView(badges: friendManager.getAllBadges())
            case .calendarAlbum:
                AlbumCalendarView(albumManager: albumManager)
            }
        }
        .sheet(isPresented: $showBadgePicker) {
            if let friend = badgeTargetFriend {
                BadgePickerView(
                    badges: badgeManager.allBadges,
                    onBadgeSelected: { badge in
                        confirmBadgeSend(badge: badge, to: friend)
                    },
                    targetUUID: friend.uuid,
                    onSelectionConfirmed: { selected in
                        for badge in selected {
                            confirmBadgeSend(badge: badge, to: friend)
                        }
                    },
                    onSendBadges: { selected in
                        for badge in selected {
                            badgeManager.sendBadge(
                                badge,
                                to: friend.uuid,
                                from: userUUID,
                                friendManager: friendManager,
                                multipeerManager: multipeerManager
                            )
                        }
                        showBadgePicker = false
                    },
                    friendManager: friendManager
                )
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraView(cameraManager: cameraManager, onCapture: { front, back in
                previewFrontImage = front
                previewBackImage = back
                showPhotoPreview = true
                isCameraPresented = false
            }, onCancel: {
                isCameraPresented = false
            })
        }
        .sheet(isPresented: $showPhotoPreview) {
            PhotoPreviewView(
                frontImage: previewFrontImage,
                backImage: previewBackImage,
                onSend: {
                    if let friend = cameraTargetFriend, let front = previewFrontImage, let back = previewBackImage {
                        cameraManager.sendPhoto(front: front, back: back, to: friend.uuid, multipeerManager: multipeerManager)
                        if let myUUID = UserDefaults.standard.string(forKey: "userUUID") {
                            albumManager.addPhoto(front, from: myUUID, message: "自撮り")
                            albumManager.addPhoto(back, from: myUUID, message: "外カメ")
                        }
                        
                        presentBadgePicker(for: friend.uuid)
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        messageText = "📤 写真を送信しました！"
                        showMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showMessage = false
                        }
                    }
                    showPhotoPreview = false
                    previewFrontImage = nil
                    previewBackImage = nil
                },
                onRetry: {
                    isCameraPresented = true
                    showPhotoPreview = false
                }
            )
        }
        .alert(isPresented: $showBadgeConfirm) {
            Alert(
                title: Text("以下を\(badgeTargetFriend?.nickname ?? "")に送ります！"),
                message: Text(badgeToSend?.name ?? ""),
                primaryButton: .default(Text("送信")) {
                    if let friend = badgeTargetFriend, let badge = badgeToSend {
                        badgeManager.sendBadge(
                            badge,
                            to: friend.uuid,
                            from: userUUID,
                            friendManager: friendManager,
                            multipeerManager: multipeerManager
                        )
                        showTemporaryMessage("バッジを送信しました！")
                    }
                    showBadgeConfirm = false
                    showBadgePicker = false
                },
                secondaryButton: .cancel(Text("キャンセル")) {
                    showBadgeConfirm = false
                }
            )
        }
        .overlay(
            Group {
                if showMessage {
                    Text(messageText)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .transition(.opacity)
                }
            },
            alignment: .center
        )
        .overlay(cameraPromptOverlay)
        .sheet(isPresented: $showBadgeReceivedSheet) {
            VStack(spacing: 20) {
                Text("🎖️ バッジを受信しました！")
                    .font(.headline)
                
                ForEach(receivedBadges) { badge in
                    HStack {
                        Image(badge.imageName)
                            .resizable()
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(badge.name)
                                .font(.subheadline)
                            Text(badge.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Button("閉じる") {
                    showBadgeReceivedSheet = false
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showPhotoReceivedSheet) {
            VStack(spacing: 20) {
                Text("📸 写真を受信しました！")
                    .font(.title2)
                    .padding()

                if let image = receivedPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)

                    if let message = receivedPhotoMessage {
                        Text("💬 \(message)")
                            .font(.title3)
                            .padding()
                    }

                    Button("閉じる") {
                        showPhotoReceivedSheet = false
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        // .sheetでアルバム表示
        .sheet(isPresented: $friendManager.showFriendAlbum) {
            if let friend = friendManager.selectedFriendForAlbum {
                AlbumView(albumManager: albumManager, senderUUID: friend.uuid, nickname: friend.nickname)
            }
        }
        // ContentView.swift の sheetやNavigationLink呼び出し部分
        .sheet(isPresented: $isAlbumPresented, onDismiss: {
            selectedFriendForAlbum = nil
        }) {
            if let friend = selectedFriendForAlbum {
                AlbumView(
                    albumManager: albumManager,
                    senderUUID: friend.uuid,
                    nickname: friend.nickname
                )
            }
            if isAlbumViewVisible, let friend = selectedFriendForAlbum {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isAlbumViewVisible = false
                            selectedFriendForAlbum = nil
                        }
                    }
                AlbumView(albumManager: albumManager, senderUUID: friend.uuid, nickname: friend.nickname,)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .alert(isPresented: $showPhotoPrompt) {
            Alert(
                title: Text("「\(photoPromptFriend?.nickname ?? "")」と写真を撮ろう！"),
                message: Text("写真を撮りますか？"),
                primaryButton: .default(Text("撮る！")) {
                    presentCamera(for: photoPromptFriend!)
                },
                secondaryButton: .cancel(Text("今はやめとく")) {
                    if let friend = photoPromptFriend {
                        presentBadgePicker(for: friend.uuid)
                    }
                }
            )
        }
        .sheet(isPresented: $showBadgeReceivedPopup) {
            VStack {
                Text("\(badgeReceivedFrom ?? "")からバッジを受信しました！")
                if let badge = badgeReceived {
                    Text(badge.name)
                    Text(badge.description)
                }
                HStack {
                    Button("バッジを確認する") {
                        // バッジ履歴画面へ遷移
                        activeSheet = .badgeHistory
                        showBadgeReceivedPopup = false
                    }
                    Button("今は見ない") {
                        showBadgeReceivedPopup = false
                    }
                }
            }
        }
    }

    func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ 加速度センサーが使用できません")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, error in
            guard let acceleration = data?.acceleration else { return }
            if self.isShake(acceleration) {
                self.motionManager.stopAccelerometerUpdates() // 🔥 まずシェイク後、いったん止める！

                // ✅ シェイク検知 → 探索スタート
                self.multipeerManager.startAdvertisingAndBrowsingForLimitedTime(seconds: 4)
                self.handleShake()

                // 🔥 そして一定時間後（例: 3秒後）にシェイク再開
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.startShakeDetection()
                    print("🔄 シェイク検知再開")
                }
            }
        }
        showTemporaryMessage("🚀 シェイクの準備完了！")
    }
    
    var cameraPromptOverlay: some View {
        Group {
            if showCameraPrompt {
                SlideInPromptView(text: "📸 \(cameraPromptFriendName)さんと撮影します！タップして開始", onTap: {
                    if let friend = photoPromptFriend {
                        presentCamera(for: friend)
                        showCameraPrompt = false
                    }
                }, isVisible: $showCameraPrompt)
            }
        }
    }

    func isShake(_ acceleration: CMAcceleration) -> Bool {
        let threshold = 2.5
        return abs(acceleration.x) > threshold ||
               abs(acceleration.y) > threshold ||
               abs(acceleration.z) > threshold
    }
    
    func handleShake() {
        didShake = true
        print("🤝 シェイク検出")

        if let friendUUID = multipeerManager.lastReceivedID, multipeerManager.isConnected {
            print("🛰️ 受信UUIDあり: \(friendUUID)")
            if let friend = friendManager.friends.first(where: { $0.uuid == friendUUID }) {
                photoPromptFriend = friend
                cameraPromptFriendName = friend.nickname
                withAnimation {
                    showCameraPrompt = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showCameraPrompt = false
                    }
                }

            } else {
                pendingUUID = friendUUID
                pendingProfileURL = multipeerManager.receivedNickname
                activeSheet = .nickname
            }
        } else {
            print("❗UUID未受信、または接続未確立")
            showTemporaryMessage("近くに友達が見つかりませんでした。共有方法を選んでください！")
            didShake = true
        }
    }
    
    // バッジ選択画面
    func presentBadgePicker(for uuid: String) {
        if let friend = friendManager.friends.first(where: { $0.uuid == uuid }) {
            badgeTargetFriend = friend
            showBadgePicker = true
        }
    }

    // バッジ送信
    func sendBadge(to friend: Friend, badge: Badge, multipeerManager: MultipeerManager) {
        badgeManager.sendBadge(
            badge,
            to: friend.uuid,
            from: userUUID,
            friendManager: friendManager,
            multipeerManager: multipeerManager
        )
    }

    func showQRCode() {
        guard !profileURL.isEmpty else {
            tempURL = ""
            isSettingURL = true
            return
        }
        showQR = true
        logVM.addLog(method: "QR")
    }

    func shareViaAirDrop() {
        isSharing = true
        logVM.addLog(method: "AirDrop")
    }

    func returnToOptions() {
        showQR = false
        didShake = false
        startShakeDetection() // ← ここで毎回呼ぶ
    }


    func generateQRCode(from string: String) -> UIImage {
        guard !string.isEmpty else {
            return UIImage(systemName: "questionmark.circle") ?? UIImage()
        }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgimg = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }

    func checkInitialURL() {
        if profileURL.isEmpty {
            tempURL = ""
            isSettingURL = true
        }
    }
    
    func nicknameInputView() -> some View {
        VStack(spacing: 16) {
            Text("ニックネームを入力してください")
                .font(.headline)

            TextField("例: ユウスケ", text: $nicknameInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("保存") {
                if !pendingUUID.isEmpty {
                    // ✅ 1. 入力が空だったら警告してリターン！
                    if nicknameInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        showTemporaryMessage("⚠️ ニックネームを入力してください！")
                        return
                    }

                    // ✅ 2. 重複チェック
                    if friendManager.friends.contains(where: { $0.nickname == nicknameInput }) {
                        showTemporaryMessage("⚠️ 同じニックネームがすでに存在します！")
                    } else {
                        // ✅ 3. 登録処理
                        friendManager.registerFriend(
                            uuid: pendingUUID,
                            nickname: nicknameInput,
                            profileURL: pendingProfileURL
                        )

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        showTemporaryMessage("🌟 \(nicknameInput) さんを登録しました！")

                        // 後処理
                        nicknameInput = ""
                        pendingUUID = ""
                        pendingProfileURL = nil
                        activeSheet = nil
                    }
                }
            }

            Button("キャンセル", role: .cancel) {
                nicknameInput = ""
                pendingUUID = ""
                activeSheet = nil
            }
        }
        .padding()
    }


    func renderQRCodeView() -> some View {
        VStack(spacing: 16) {
            Spacer() // ← 上に余白を作って、全体を下に配置

            Image(uiImage: generateQRCode(from: profileURL))
                .interpolation(.none)
                .resizable()
                .frame(width: 180, height: 180)
                .background(Color.white)
                .cornerRadius(8)
                .transition(.scale) // ← アニメーション追加
                .animation(.easeInOut(duration: 0.3), value: showQR)

            Text("📡 QRコードが表示されました")
                .foregroundColor(.blue)

            Button(action: {
                withAnimation {
                    didShake = false
                    startShakeDetection()
                    returnToOptions()
                }
            }) {
                Text("🔙 戻る")
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
            }

            Spacer(minLength: 50) // ← 下にも少し余白
        }
    }


    func renderShareOptionsView() -> some View {
        VStack(spacing: 16) {
            Text("⏳ あと \(countdown) 秒で戻ります！")
                .foregroundColor(.white)
                .onAppear {
                    startCountdown()
                }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showQRCode()
                }
            }) {
                Text("🔳 QRコードで共有")
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.pink)
                    .cornerRadius(12)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    shareViaAirDrop()
                }
            }) {
                Text("📡 AirDropで送信")
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(12)
            }

            Button(action: {
                withAnimation {
                    countdownTimer?.invalidate() // タイマーを止める
                    didShake = false
                    startShakeDetection()
                }
            }) {
                Text("🔙 戻る")
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
            }
        }
    }


    func startCountdown() {
        countdown = countdownDuration
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                didShake = false
                startShakeDetection()
            }
        }
    }

    func renderShakePrompt() -> some View {
        VStack(spacing: 12) {
            Spacer() // 🔽 これを追加して上の余白を確保

            Text("🤝 iPhoneを振って、共有方法を選択")
                .foregroundColor(.white)

            Button(action: {
                tempURL = profileURL
                isSettingURL = true
            }) {
                Text("🔧 URLを設定")
                    .font(.caption)
                    .padding(6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }

            Spacer() // 🔼 これを追加して下の余白を確保
        }
    }

    func renderShareLogView() -> some View {
        let recentLogs = logVM.logs.suffix(10).reversed()
        return VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 20) // 🔽 上部にスペース追加（任意）

            HStack {
                Text("📜 共有履歴")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    logVM.clearLogs()
                }) {
                    Text("🗑️ 全削除")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            ForEach(recentLogs) { log in
                Text("\(formatted(log.date))：\(log.method)")
                    .font(.caption)
                    .foregroundColor(.white)
            }

            Spacer(minLength: 50) // 🔼 下に余白を追加（任意）
        }
    }

    
    func renderSideMenu() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Button("🔧 URLを設定") {
                tempURL = profileURL
                isSettingURL = true
                withAnimation {
                    showMenu = false
                }
            }
            .padding(.top, 100) // ← 今より20pxくらい下にずれる

            Button("❌ 閉じる") {
                withAnimation {
                    showMenu = false
                }
            }
            .foregroundColor(.red)
            
            Button("⚙️ 設定") {
                activeSheet = .settings // ✅ 先に表示フラグを立てる
                DispatchQueue.main.async {
                    showMenu = false // ✅ 次のランループで閉じる
                }
            }
            Button("👥 ともだちリスト") {
                activeSheet = .friendsList
                DispatchQueue.main.async {
                    showMenu = false
                }
            }
            Button("🎖️ バッジ履歴") {
                activeSheet = .badgeHistory
                DispatchQueue.main.async {
                    showMenu = false
                }
            }

            Button("📆 カレンダーアルバム") {
                activeSheet = .calendarAlbum // ← 必要に応じて enum に追加
                DispatchQueue.main.async {
                    showMenu = false
                }
            }


            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: 200, alignment: .leading) // ← 幅を200ptに制限（約5cm相当）
        .background(Color.black.opacity(0.9))
        .edgesIgnoringSafeArea(.all)
    }

    func openFriendAlbum(_ friend: Friend) {
        self.selectedFriendForAlbum = friend
        self.isAlbumPresented = true
    }
    
        
    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    func presentCamera(for friend: Friend) {
        cameraTargetFriend = friend
        isCameraPresented = true
    }

    func sendPhoto(front: UIImage, back: UIImage, to uuid: String, multipeerManager: MultipeerManager) {
        cameraManager.sendPhoto(front: front, back: back, to: uuid, multipeerManager: multipeerManager)
    }

    // BadgePickerViewのonBadgeSelected
    func confirmBadgeSend(badge: Badge, to friend: Friend) {
        badgeToSend = badge
        showBadgeConfirm = true
    }

    // 受信側
    func handleBadgeReceived(from: String, badge: Badge) {
        badgeReceivedFrom = from
        badgeReceived = badge
        showBadgeReceivedPopup = true
    }
    
    struct SlideInPromptView: View {
        let text: String
        let onTap: () -> Void
        @Binding var isVisible: Bool

        @GestureState private var dragOffset = CGSize.zero

        var body: some View {
            VStack {
                if isVisible {
                    HStack {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                    }
                    .background(Color.blue)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                    .padding()
                    .onTapGesture {
                        onTap()
                    }
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                if value.translation.height < -30 {  // 上にスワイプ
                                    withAnimation {
                                        isVisible = false
                                    }
                                }
                            }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .animation(.easeInOut, value: isVisible)
        }
    }

}

// MARK: - AirDrop用のView
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

