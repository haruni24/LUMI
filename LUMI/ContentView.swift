//
//  ContentView.swift
//  LUMI
//
//  Created by 西島賢太朗 on 2025/10/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var messages: [ChatMessage] = []
    @State private var isListening = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    private let recorder = AudioRecorder()
    private let player = AudioPlayer()
    private let client = OpenAIClient()

    var body: some View {
        ZStack(alignment: .bottom) {
            // チャットリスト
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            // 状態表示 + 送信ボタン
            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error).font(.footnote).foregroundColor(.red)
                } else if isBusy {
                    Text("処理中...").font(.footnote).foregroundColor(.secondary)
                } else if isListening {
                    Text("準備完了、音声を聞いています").font(.footnote).foregroundColor(.secondary)
                }

                BottomSendBar(sendAction: send, enabled: !isBusy)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
        .onAppear { prepare() }
    }

    private func prepare() {
        player.onFinish = { Task { await self.startListeningIfNeeded() } }
        recorder.requestPermission { allowed in
            if !allowed { errorMessage = "マイクの権限がありません (設定→LUMI)" }
            else { Task { await self.startListeningIfNeeded() } }
        }
        if client == nil { errorMessage = ".envのOPENAI_API_KEYが見つかりません" }
    }

    @MainActor
    private func startListeningIfNeeded() async {
        guard !isBusy, !player.isPlaying, !recorder.isRecording else { return }
        do {
            try recorder.start()
            isListening = true
        } catch {
            errorMessage = "録音開始に失敗: \(error.localizedDescription)"
        }
    }

    private func send() {
        guard !isBusy else { return }
        guard let client = client else { errorMessage = ".envのOPENAI_API_KEYが見つかりません"; return }
        // 録音を停止して処理
        if recorder.isRecording { recorder.stop(); isListening = false }
        guard let url = recorder.fileURL else { errorMessage = "録音が見つかりません"; return }
        errorMessage = nil
        isBusy = true

        Task {
            do {
                // 1) STT
                let transcript = try await client.transcribe(fileURL: url, language: "ja")
                await MainActor.run {
                    self.messages.append(.init(role: .user, text: transcript))
                }

                // 2) Chat
                let systemPrompt = "あなたはフレンドリーな英会話の先生です。簡潔に英語で返答し、日本語訳を括弧で添えてください。"
                let reply = try await client.chat(messages: [
                    OpenAIClient.ChatRequestMessage(role: "system", content: systemPrompt),
                    OpenAIClient.ChatRequestMessage(role: "user", content: transcript)
                ])
                await MainActor.run {
                    self.messages.append(.init(role: .assistant, text: reply))
                }

                // 3) TTS 再生完了後に自動で録音再開
                let audio = try await client.synthesize(text: reply)
                try await MainActor.run { try self.player.play(data: audio) }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isBusy = false }
            // 再生完了時に player.onFinish から録音再開
        }
    }

    private func clear() {
        messages.removeAll()
        errorMessage = nil
        player.stop()
        if recorder.isRecording { recorder.stop() }
        isListening = false
        Task { await startListeningIfNeeded() }
    }
}

#Preview {
    ContentView()
}
