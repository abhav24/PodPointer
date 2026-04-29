import AVFoundation

/// Plays silence so the audio connection to the AirPods stays active.
final class SilentAudio {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    func start() throws {
        guard sourceNode == nil else { return }
        let node = AVAudioSourceNode { _, _, _, bufferList in
            for buffer in UnsafeMutableAudioBufferListPointer(bufferList) {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
