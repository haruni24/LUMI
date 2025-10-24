# LUMI 英会話ミニアプリ

SwiftUIで、録音→文字起こし→応答生成（gpt-4o-mini）→音声合成の流れを最小構成で実装しています。

## 構成

- `LUMI/Env.swift` … `.env`や`Info.plist`/環境変数からAPIキー等を読み込む簡易ローダ
- `LUMI/OpenAIClient.swift` … OpenAI API呼び出し（STT/Chat/TTS）
- `LUMI/AudioRecorder.swift` … マイク録音（m4a）
- `LUMI/AudioPlayer.swift` … 音声再生
- `LUMI/ContentView.swift` … 画面（録音/送信/クリア の3要素UI）

## 事前準備

1. `.env` をプロジェクト直下に作成し、アプリのターゲットに「リソース」として追加してください（Build Phases > Copy Bundle Resources）。
2. `.env` の内容（個人利用想定）

```
OPENAI_API_KEY=sk-xxxxx
# 任意: 既定値は下記
OPENAI_CHAT_MODEL=gpt-4o-mini
OPENAI_STT_MODEL=whisper-1
OPENAI_TTS_MODEL=tts-1
OPENAI_TTS_VOICE=alloy
```

3. `Info.plist` にマイク権限メッセージを追加（必須）

```
Privacy - Microphone Usage Description (NSMicrophoneUsageDescription) = 音声入力のためマイクを使用します
```

4. iOS 17 以降を推奨。実機テスト時は「設定 > LUMI」でマイク許可をオンに。

## 使い方

- 「録音」開始→「停止」→「送信」で、文字起こし→応答→音声出力まで自動実行します。
- 画面は「録音／送信／クリア」の3要素＋会話表示のみのシンプルUIです。

## 注意

- `.env` をアプリに同梱するとバイナリ内に平文で含まれます。個人学習用途に限定し、公開配布は避けてください。
- 将来のAPI更新に備え、`.env`でモデル名を差し替え可能にしています。

