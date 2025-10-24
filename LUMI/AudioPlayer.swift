import Foundation
import AVFoundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var onFinish: (() -> Void)?

    func play(data: Data) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)

        self.player = try AVAudioPlayer(data: data)
        self.player?.delegate = self
        self.player?.prepareToPlay()
        self.player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var isPlaying: Bool { player?.isPlaying ?? false }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 再生セッションはここで解除
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onFinish?()
    }
}
