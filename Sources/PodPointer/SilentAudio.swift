import AVFoundation

/// Plays silence so the audio connection to the AirPods stays active.
final class SilentAudio {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

