//
//  SettingsView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/14.
//

// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("countdownDuration") private var countdownDuration: Int = 5

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("⏳ 戻るまでの時間")) {
                    Picker("選択肢", selection: $countdownDuration) {
                        Text("5秒").tag(5)
                        Text("15秒").tag(15)
                        Text("30秒").tag(30)
                        Text("1分").tag(60)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("⚙️ 設定")
        }
    }
}

