import SwiftUI
import CoreMotion
import CoreImage.CIFilterBuiltins
import UIKit
import MultipeerConnectivity

// MARK: - 共有履歴データモデル
struct ShareLog: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let method: String // "QR" or "AirDrop"
}

// MARK: - バッジ送信Payload
struct OutgoingPayload: Codable {
    let uuid: String
    let profileURL: String
    let badges: [Badge]
}

// ContentView.swift の上部（ContentView構造体の外）に追加
struct PhotoPayload: Codable {
    let type: String  // "photo"
    let from: String
    let to: String
    let imageData: Data
    let message: String
}


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
    @State private var showPreview = false         // 写真プレビュー画面の表示フラグ

    
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
                    // ✅ すでに存在 → 情報更新
                    friendManager.updateProfileURL(for: receivedID, newURL: receivedURL)
                    friendManager.appendBadges(for: receivedID, newBadges: receivedBadges)
                    let name = friendManager.getNickname(for: receivedID) ?? "Unknown"
                    showTemporaryMessage("🔄 \(name) さんの情報を更新しました")
                    if !receivedBadges.isEmpty {
                        self.receivedBadges = receivedBadges
                        self.showBadgeReceivedSheet = true
                    }


                } else {
                    // ✅ 新しい友達として登録フローへ
                    pendingUUID = receivedID
                    pendingProfileURL = receivedURL
                    friendManager.storeTemporaryBadges(badges: receivedBadges) // ✅ 次項を参照
                    activeSheet = .nickname
                }
                
                if let photoPayload = try? JSONDecoder().decode(PhotoPayload.self, from: data),
                       photoPayload.type == "photo",
                       let uiImage = UIImage(data: photoPayload.imageData) {
                        // 相手からの写真はfriendページ用アルバムに保存
                        albumManager.addPhoto(uiImage, from: photoPayload.from, message: photoPayload.message)
                        self.receivedPhoto = uiImage
                        self.receivedPhotoMessage = photoPayload.message
                        self.showPhotoReceivedSheet = true
                        showTemporaryMessage("📥 \(photoPayload.message)")
                }
            }
        }


        .onAppear {
            print("🌟 onAppear start")
            isLoading = true
            
            if UserDefaults.standard.string(forKey: "userUUID") == nil {
                    UserDefaults.standard.set(userUUID, forKey: "userUUID")
                }
            
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
            case .nickname:
                nicknameInputView()
            case .badgeHistory:
                BadgeHistoryView(badges: friendManager.getAllBadges())
            case .calendarAlbum:
                AlbumCalendarView(albumManager: albumManager)

            }

        }
        .sheet(isPresented: Binding<Bool>(
            get: { selectedBadgeTargetUUID != nil },
            set: { if !$0 { selectedBadgeTargetUUID = nil } }
        )) {
            if let uuid = selectedBadgeTargetUUID {
                BadgePickerView(
                    badges: badgeManager.allBadges,
                    onBadgeSelected: { badge in
                        badgeManager.assignBadge(badge, to: uuid, in: friendManager)
                    },
                    targetUUID: uuid,
                    onSelectionConfirmed: { selected in
                        for badge in selected {
                            badgeManager.assignBadge(badge, to: uuid, in: friendManager)
                        }
                    },
                    onSendBadges: { selected in
                        let payload = OutgoingPayload(
                            uuid: userUUID,
                            profileURL: profileURL,
                            badges: selected
                        )
                        if let data = try? JSONEncoder().encode(payload) {
                            multipeerManager.send(data: data)
                            showTemporaryMessage("🎁 バッジ送信完了: \(selected.map { $0.name }.joined(separator: ", "))")
                        }
                        selectedBadgeTargetUUID = nil
                    },
                    friendManager: friendManager
                )
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraView(cameraManager: cameraManager, onCapture: { image in
                showCapturedImagePreview(image: image)  // プレビュー表示
                isCameraPresented = false
            }, onCancel: {
                isCameraPresented = false
            })
        }

        // プレビューと送信確認のfullScreenCover
        .fullScreenCover(isPresented: $showPreview) {
            if let image = capturedImage {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text("最高のメンツ！")
                        .font(.title)
                        .padding()
                    HStack {
                        Button("送信") {
                            // 送信ロジック
                            if let imageData = image.jpegData(compressionQuality: 0.8),
                               let targetUUID = multipeerManager.lastReceivedID {
                                let photoPayload = PhotoPayload(type: "photo", from: userUUID, to: targetUUID, imageData: imageData, message: "最高の思い出！")
                                if let encoded = try? JSONEncoder().encode(photoPayload) {
                                    multipeerManager.send(data: encoded)
                                    albumManager.addPhoto(image, from: userUUID, message: "自分の写真") // カレンダーに追加
                                }
                            }
                            showPreview = false
                            isCameraPresented = false
                        }
                        .padding()
                        Button("撮り直し") {
                            showPreview = false
                        }
                        .padding()
                    }
                }
                .background(Color.black)
            }
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
        .sheet(isPresented: $friendManager.showFriendAlbum) {
            if let friend = friendManager.selectedFriendForAlbum {
                // 修正後（senderUUID も渡す必要があるなら）
                AlbumView(albumManager: albumManager, senderUUID: userUUID, )

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
            if isShake(acceleration) {
                handleShake()
            }
        }

        showTemporaryMessage("🚀 シェイクの準備完了！")
    }



    func isShake(_ acceleration: CMAcceleration) -> Bool {
        let threshold = 2.5
        return abs(acceleration.x) > threshold ||
               abs(acceleration.y) > threshold ||
               abs(acceleration.z) > threshold
    }
    
    /// iPhoneを振ったときに呼ばれる処理
    func handleShake() {
        guard !didShake else { return }
        didShake = true

        let payload = OutgoingPayload(
            uuid: userUUID,
            profileURL: profileURL,
            badges: selectedBadges
        )

        if let data = try? JSONEncoder().encode(payload) {
            multipeerManager.send(data: data)
            print("🚀 バッジ送信: \(selectedBadges.map { $0.name })")
            if !selectedBadges.isEmpty {
                showTemporaryMessage("🎁 バッジ送信完了: \(selectedBadges.map { $0.name }.joined(separator: ", "))")
            }
        }
        // 1. 自分のUUID送信はそのまま残す
        if let data = userUUID.data(using: .utf8) {
            multipeerManager.send(data: data)
        }

        // 2. 相手に送りたいバッジ情報（例：GentleManバッジ）を送信
        let badge = Badge(id: UUID(), name: "GentleMan", description: "礼儀正しく、丁寧な印象", imageName: "GentleManBadge") // ← 自分で定義してるバッジ定数がある場合
        let badgePayload = BadgePayload(type: .badge, from: userUUID, to: selectedBadgeTargetUUID ?? "", badge: badge)

        if let badgeData = try? JSONEncoder().encode(badgePayload) {
            multipeerManager.send(data: badgeData)
        }

        selectedBadges = [] // 送信後にリセット

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(countdownDuration)) {
            didShake = false
        }
        // 🔁 接続相手のUUIDを使ってバッジ送信対象に設定（selfは使わない！）
        if let targetUUID = multipeerManager.lastReceivedID {
            selectedBadgeTargetUUID = targetUUID
            isCameraPresented = true  // ← Cameraここで起動
            print("🎯 バッジ送信対象: \(targetUUID)")
        } else {
            print("⚠️ 接続相手のUUIDが取得できませんでした")
        }
    }

    func sendBadge(_ badge: Badge) {
        guard !pendingUUID.isEmpty else { return }

        let payload = BadgePayload(type: .badge, from: userUUID, to: pendingUUID, badge: badge)
        if let data = try? JSONEncoder().encode(payload) {
            multipeerManager.send(data: data)
            friendManager.appendBadges(for: pendingUUID, newBadges: [badge])  // 自分側にも履歴残す
            showTemporaryMessage("🎉 \(badge.name) を送りました！")
            pendingUUID = ""
        }
    }
    
    func handleReceivedBadge(from: String, badge: Badge) {
        // 受信者側で保存
        friendManager.appendBadges(for: from, newBadges: [badge])
        showTemporaryMessage("🎖️ \(badge.name) バッジを \(from.prefix(6)) から受信しました！")
        receivedBadges = [badge]
        showBadgeReceivedSheet = true
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
                    // 同じニックネームがすでに使われていないかチェック
                    if friendManager.friends.contains(where: { $0.nickname == nicknameInput }) {
                        showTemporaryMessage("⚠️ 同じニックネームがすでに存在します！")
                    } else {
                        // 🔽 プロフィールURLも一緒に保存！
                        friendManager.addFriend(uuid: pendingUUID, nickname: nicknameInput, profileURL: pendingProfileURL)
                        showTemporaryMessage("🌟 \(nicknameInput) さんを登録しました！")
                        nicknameInput = ""
                        pendingUUID = ""
                        pendingProfileURL = nil // ← リセットを忘れずに
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
    
    func showCapturedImagePreview(image: UIImage) {
        self.capturedImage = image
        self.showPreview = true
    }
    
    func sendCapturedPhoto(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let targetUUID = multipeerManager.lastReceivedID else {
            showTemporaryMessage("⚠️ 送信できる相手がいません")
            showPreview = false
            return
        }
        let photoPayload = PhotoPayload(
            type: "photo",
            from: userUUID,
            to: targetUUID,
            imageData: imageData,
            message: "最高の思い出！"
        )
        if let encoded = try? JSONEncoder().encode(photoPayload) {
            multipeerManager.send(data: encoded)
            albumManager.addPhoto(image, from: userUUID, message: "自分の写真") // カレンダーに追加
            showTemporaryMessage("📤 写真を送信しました！")
        }
        showPreview = false
        capturedImage = nil
    }

        
    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
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

