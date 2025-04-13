import SwiftUI
import CoreMotion
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - 共有履歴データモデル
struct ShareLog: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let method: String // "QR" or "AirDrop"
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
struct ContentView: View {
    let motionManager = CMMotionManager()

    @State private var isSharing = false
    @State private var showQR = false
    @State private var didShake = false
    
    @AppStorage("userProfileURL") private var profileURL: String = ""
    @State private var isSettingURL = false
    @State private var tempURL: String = ""
    @State private var showMenu = false
    @State private var isLoading = true


    @StateObject private var logVM = ShareLogViewModel()

    var body: some View {
        ZStack(alignment: .leading) {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [.pink.opacity(0.3), .blue.opacity(0.2)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
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
                                    .padding()
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
        .onAppear {
            print("🌟 onAppear start")
            isLoading = true

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
    }


    func isShake(_ acceleration: CMAcceleration) -> Bool {
        let threshold = 2.5
        return abs(acceleration.x) > threshold ||
               abs(acceleration.y) > threshold ||
               abs(acceleration.z) > threshold
    }
    
    

    func handleShake() {
        didShake = true
        motionManager.stopAccelerometerUpdates()
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
            .transition(.scale)
            .animation(.easeInOut, value: showQR)

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
            .transition(.scale)
            .animation(.easeInOut, value: isSharing)
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
            .padding(.top, 60)

            Button("❌ 閉じる") {
                withAnimation {
                    showMenu = false
                }
            }
            .foregroundColor(.red)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: 200, alignment: .leading) // ← 幅を200ptに制限（約5cm相当）
        .background(Color.black.opacity(0.9))
        .edgesIgnoringSafeArea(.all)
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

