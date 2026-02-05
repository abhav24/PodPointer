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

