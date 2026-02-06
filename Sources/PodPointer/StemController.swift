import AVFoundation
import MediaPlayer
import PodPointerCore

/// Listens for AirPods stem presses by acting as the Mac's Now Playing app.
/// macOS sends media commands to that app, and silent audio helps it claim the role.
final class StemController {
    var onPress: ((StemPress) -> Void)?

    private let center = MPRemoteCommandCenter.shared()
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var targets: [(MPRemoteCommand, Any)] = []

    func start() throws {
        try startSilentAudio()

        add(center.togglePlayPauseCommand, press: .single)
        add(center.playCommand, press: .single)
        add(center.pauseCommand, press: .single)
        add(center.nextTrackCommand, press: .double)
        add(center.previousTrackCommand, press: .triple)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "PodPointer",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    func stop() {
        for (command, target) in targets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        targets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
    }

    private func add(_ command: MPRemoteCommand, press: StemPress) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                // Stay "playing" so the next press is delivered here as well.
                MPNowPlayingInfoCenter.default().playbackState = .playing
                self?.onPress?(press)
            }
            return .success
        }
        targets.append((command, target))
    }

