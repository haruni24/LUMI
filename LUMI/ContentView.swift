//
//  ContentView.swift
//  LUMI
//
//  Created by 西島賢太朗 on 2025/10/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var userTranscript: String = ""
    @State private var assistantText: String = ""
    @State private var isRecording = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    private let recorder = AudioRecorder()
    private let player = AudioPlayer()
    private let client = OpenAIClient()

    var body: some View {
        VStack(spacing: 16) {
            // 会話表示
            VStack(alignment: .leading, spacing: 8) {
                Text("ユーザー")
                    .font(.caption).foregroundColor(.secondary)
                Text(userTranscript.isEmpty ? "(未入力)" : userTranscript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(.ultraThinMaterial).cornerRadius(8)
                Text("AI")
                    .font(.caption).foregroundColor(.secondary)
                Text(assistantText.isEmpty ? "(未応答)" : assistantText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12).background(.ultraThinMaterial).cornerRadius(8)
            }
            .frame(maxWidth: .infinity)

            // 3つのシンプルなUI要素
            HStack(spacing: 12) {
                Button(action: toggleRecord) {
                    Label(isRecording ? "停止" : "録音", systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .blue)
                .disabled(isBusy)

                Button(action: send) {
                    Label("送信", systemImage: "paperplane.fill").font(.title2)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)

                Button(action: clear) {
                    Label("クリア", systemImage: "trash").font(.title2)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(isBusy && !isRecording)
            }

            if isBusy { ProgressView("処理中...") }
            if let error = errorMessage { Text(error).foregroundColor(.red).font(.footnote) }
        }
        .padding()
        .onAppear { prepare() }
    }

    private func prepare() {
        recorder.requestPermission { allowed in
            if !allowed { errorMessage = "マイクの権限がありません (設定→LUMI)" }
        }
        if client == nil { errorMessage = ".envのOPENAI_API_KEYが見つかりません" }
    }

    private func toggleRecord() {
        if isRecording {
            recorder.stop()
            isRecording = false
        } else {
            do {
                try recorder.start()
                isRecording = true
                userTranscript = "" // 新規録音時はクリア
            } catch {
                errorMessage = "録音開始に失敗: \(error.localizedDescription)"
            }
        }
    }

    private func send() {
        guard !isBusy else { return }
        guard let client = client else {
            errorMessage = ".envのOPENAI_API_KEYが見つかりません"
            return
        }
        // 録音停止してから送信
        if isRecording { toggleRecord() }
        guard let url = recorder.fileURL else {
            errorMessage = "録音が見つかりません"
            return
        }
        errorMessage = nil
        isBusy = true

        Task {
            do {
                // 1) 文字起こし
                let transcript = try await client.transcribe(fileURL: url, language: "ja")
                await MainActor.run { self.userTranscript = transcript }

                // 2) 応答生成（gpt-4o-mini）
                let systemPrompt = "あなたはフレンドリーな英会話の先生です。簡潔に英語で返答し、日本語訳を括弧で添えてください。"
                let reply = try await client.chat(messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: transcript)
                ])
                await MainActor.run { self.assistantText = reply }

                // 3) 音声合成（TTS）
                let audio = try await client.synthesize(text: reply)
                try await MainActor.run { try self.player.play(data: audio) }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await MainActor.run { self.isBusy = false }
        }
    }

    private func clear() {
        userTranscript = ""
        assistantText = ""
        errorMessage = nil
    }
}

#Preview {
    ContentView()
}
