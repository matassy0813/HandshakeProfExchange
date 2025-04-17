//
//  SafariView.swift
//  3WayhandshakeExchanging_Profileexchange_withHandshake
//
//  Created by 俣江悠聖 on 2025/04/15.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
