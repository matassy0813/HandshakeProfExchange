# Shake & Share

**Shake & Share** is a SwiftUI-based iOS app designed to make real-world profile sharing intuitive and fun. Simply shake your iPhone to reveal options to share your profile via a QR code or AirDrop. The app also includes a persistent history of sharing activity and customizable settings, all wrapped in a playful, modern interface.

---

## 🚀 Features

### 1. シェイクでアクション
- Uses CoreMotion to detect shake gestures via the device's accelerometer
- Triggers the sharing menu UI upon detection

```swift
func startShakeDetection() {
    motionManager.startAccelerometerUpdates(...) {
        if isShake(acceleration) {
            handleShake()
        }
    }
}
```

---

### 2. 共有方法を選択 (QRコード / AirDrop)
- User chooses how to share their profile
- Automatically logs the method and timestamp

```swift
func showQRCode() {
    showQR = true
    logVM.addLog(method: "QR")
}

func shareViaAirDrop() {
    isSharing = true
    logVM.addLog(method: "AirDrop")
}
```

---

### 3. QRコード生成 & 表示
- Generates a QR code from the user's set profile URL
- Displayed with animation and design enhancements

```swift
func generateQRCode(from string: String) -> UIImage {
    ... // using CoreImage
}
```

---

### 4. 利用履歴の保存
- Keeps the last 10 share actions (QR or AirDrop)
- Stored via UserDefaults, persisted across sessions

```swift
struct ShareLog: Codable, Identifiable { ... }
class ShareLogViewModel: ObservableObject { ... }
```

---

### 5. ユーザープロフィールURLの設定
- First launch prompts for profile URL input
- User can change the URL anytime via the side menu

```swift
@AppStorage("userProfileURL") private var profileURL: String
```

---

### 6. サイドメニュー
- Pull-tab style menu from the left side (width = 200pt)
- Includes buttons to edit URL or close the menu manually
- Background tap to dismiss the menu

```swift
if showMenu {
    Color.black.opacity(0.001).onTapGesture { showMenu = false }
    renderSideMenu()
}
```

---

## 🖥 UI Flow

1. App launches and optionally prompts for URL
2. User shakes device
3. Share options appear
4. User selects QR or AirDrop
5. Sharing method is logged
6. Side menu available to update URL or view history

---

## 📦 Tech Stack
- **SwiftUI** for UI design
- **CoreMotion** for shake detection
- **CoreImage** for QR code generation
- **UserDefaults** via `@AppStorage` and custom ViewModel
- **UIKit integration** for AirDrop via `UIActivityViewController`

---

## 📄 License
MIT

---

Happy shaking & sharing! 🤝
