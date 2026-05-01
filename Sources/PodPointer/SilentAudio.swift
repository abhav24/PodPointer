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
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
    }
}
