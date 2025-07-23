//
//  ContentView.swift
//  GLTP-Conference-Administration-App
//
//  Created by 稲村 健太郎 on 2025/07/22.
//

//
// ContentView.swift
// アプリのメイン画面と画面遷移を管理します。
//
import SwiftUI
import Combine

// アプリ全体の状態を管理するための型
enum AppState: Equatable {
    case ready // 初期状態（ボタン表示）
    case scanning // スキャン中
    case loading // 通信中
    case result(VerificationResult) // 結果表示
}

// 照合結果を管理するための型
enum VerificationResult: Equatable {
    case success    // ○
    case priority   // ◎ ← 追加！
    case failure    // ×
}

struct ContentView: View {

    @State private var appState: AppState = .ready
    @State private var scannedCode: String?
    
    // 結果表示から初期画面に自動で戻るためのタイマー
    private let backToReadyTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // appStateの値に応じて表示するViewを切り替える
            switch appState {
            case .ready:
                readyView
            case .scanning:
                // スキャン状態のときはシートが表示されるので、背景は空でOK
                EmptyView()
            case .loading:
                loadingView
            case .result(let result):
                resultView(for: result)
            }
        }
        // appStateが.scanningになったらスキャナーシートを表示する
        .sheet(isPresented: Binding<Bool>(
            get: { self.appState == .scanning },
            // set: { if !$0 { self.appState = .ready } } // シートが閉じられたら初期状態に戻す
            set: { _ in /* 何もしない。状態遷移は別で制御する */ }
        )) {
            ScannerView(scannedCode: self.$scannedCode)
        }
        // scannedCode（@State）の値が変更されたのを検知する
        .onChange(of: scannedCode) {
            if let code = scannedCode {
                self.appState = .loading
                verifyAndMarkQRCode(code: code)  // ← ContentView内の関数を呼び出す！
                self.scannedCode = nil
            }
        }
    }

    // MARK: - Subviews
    
    // 初期画面のView
    private var readyView: some View {
        Button(action: {
            self.appState = .scanning
        }) {
            HStack(spacing: 15) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title)
                Text("QRコードを読み取る")
                    .fontWeight(.bold)
                    .font(.title2)
            }
            .padding()
            // --- iPad対応の変更点 ---
            // iPadでボタンが横に広がりすぎないように最大幅を設定
            .frame(maxWidth: 500)
            // -------------------------
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(radius: 5)
        }
        .padding(30)
    }
    
    // 通信中のView
    private var loadingView: some View {
        ProgressView("照合中...")
            .font(.title2)
    }

    // 結果表示のView
    private func resultView(for result: VerificationResult) -> some View {
        Group {
            switch result {
            case .success:
                Image(systemName: "circle")
                    .font(.system(size: 200, weight: .thin))
                    .foregroundColor(.blue)
            case .priority:
                ZStack {
                    // 外側の○
                    Circle()
                        .stroke(lineWidth: 6)
                        .frame(width: 200, height: 200)
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)) // ゴールド

                    // 内側の○
                    Circle()
                        .stroke(lineWidth: 6)
                        .frame(width: 100, height: 100)
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13)) // ゴールド
                }
            case .failure:
                Image(systemName: "multiply")
                    .font(.system(size: 200, weight: .thin))
                    .foregroundColor(.red)
            }
        }
        .transition(.scale.animation(.spring()))
    }

    // MARK: - API Call
    
    // Google Apps Scriptを呼び出す関数
    private func verifyAndMarkQRCode(code: String) {
        GoogleSheetsService.shared.verifyAndMarkQRCode(qrCode: code) { success, priority in
            DispatchQueue.main.async {
                let result: VerificationResult
                if success {
                    if priority == "yes" {
                        result = .priority
                    } else {
                        result = .success
                    }
                } else {
                    result = .failure
                }

                withAnimation {
                    self.appState = .result(result)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.appState = .ready
                    }
                }
            }
        }
    }
}
