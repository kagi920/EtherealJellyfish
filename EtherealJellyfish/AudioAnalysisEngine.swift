//
//  AudioAnalysisEngine.swift
//  EtherealJellyfish
//
//  Created by kagi on 2025/07/20.
//

import AVFoundation
import Accelerate

class AudioAnalysisEngine {
    private let audioEngine = AVAudioEngine()
    private let audioData: AudioDataActor

    private var fftSize = 1024
    private var fftSetup: vDSP.FFT<vDSP.Real>?

    init(audioData: AudioDataActor) {
        self.audioData = audioData
        self.fftSetup = vDSP.FFT(log2n: vDSP_Length(log2(Float(fftSize))),
                                 radix: .radix2,
                                 ofType: vDSP.Real.self)

        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: inputFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
        }
    }

    func start() throws {
        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0], let fftSetup = self.fftSetup else { return }

        let frameLength = Int(buffer.frameLength)

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var complexBuffer = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        let windowedSignal = vDSP.window(ofType: [Float].self,
                                         usingSequence: .hanning,
                                         count: frameLength,
                                         isHalfWindow: false)

        var multipliedSignal = [Float](repeating: 0, count: frameLength)
        vDSP_vmul(channelData, 1, windowedSignal, 1, &multipliedSignal, 1, vDSP_Length(frameLength))

        let pointer = UnsafePointer<Float>(multipliedSignal)
        pointer.withMemoryRebound(to: DSPComplex.self, capacity: complexBuffer.realp.count) { (complex) -> Void in
            vDSP_ctoz(complex, 2, &complexBuffer, 1, vDSP_Length(fftSize / 2))
        }

        fftSetup.forward(input: complexBuffer, output: &complexBuffer)

        var magnitudes = [Float](repeating: 0.0, count: fftSize / 2)
        vDSP_vsmul(complexBuffer.realp, 1, complexBuffer.realp, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        vDSP_vadd(magnitudes, 1, complexBuffer.imagp, 1, &magnitudes, 1, vDSP_Length(fftSize/2))

        Task {
            await audioData.updateMagnitudes(magnitudes)
        }
    }
}
