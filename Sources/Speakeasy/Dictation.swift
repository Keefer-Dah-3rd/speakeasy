import AVFoundation
import Foundation
import Speech

enum DictationError: LocalizedError {
    case engineUnavailable
    case noMicrophone
    case modelMissing
    case modelUnreadable
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            return "The speech engine isn't available on this Mac right now."
        case .noMicrophone:
            return "No microphone was found."
        case .modelMissing:
            return "The Whisper model file is missing."
        case .modelUnreadable:
            return "The Whisper model file couldn't be opened."
        case .transcriptionFailed:
            return "Whisper couldn't transcribe that."
        }
    }
}

/// Converts microphone audio into the format the speech engine asks for.
final class BufferConverter {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        if inputFormat == format {
            return try copy(buffer)
        }

        if converter == nil || converter?.inputFormat != inputFormat || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none  // no added latency at the start
        }
        guard let converter else { throw DictationError.engineUnavailable }

        let ratio = format.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw DictationError.engineUnavailable
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if status == .error {
            throw conversionError ?? DictationError.engineUnavailable
        }
        return output
    }

    private func copy(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let duplicate = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            throw DictationError.engineUnavailable
        }
        duplicate.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(duplicate.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            if let fromData = from.mData, let toData = to.mData {
                memcpy(toData, fromData, Int(min(from.mDataByteSize, to.mDataByteSize)))
            }
        }
        return duplicate
    }
}

/// One dictation, start to finish, using Apple's on-device dictation engine.
/// Audio is transcribed while you are still talking, so when you stop only the
/// last moment of speech is left to process.
///
/// Marked `@unchecked Sendable` because `feed` is called from the audio thread:
/// everything it reads is set once in `prepare`, before the microphone starts.
final class DictationSession: DictationBackend, @unchecked Sendable {
    /// Live words, reported as you speak. `settled` will not change again;
    /// `tentative` is the engine's current guess at what you are saying right
    /// now and may still be revised. Set before `prepare`. Called off the main thread.
    var onWords: (@Sendable (_ settled: String, _ tentative: String) -> Void)?

    private var analyzer: SpeechAnalyzer?
    private var stream: AsyncStream<AnalyzerInput>?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var collector: Task<String, Error>?
    private var targetFormat: AVAudioFormat?
    private let converter = BufferConverter()

    private static var cachedLocale: Locale?

    /// The dictation language: the Mac's own language when the engine supports
    /// it, otherwise US English.
    static func resolveLocale() async -> Locale {
        if let cachedLocale { return cachedLocale }
        let fallback = Locale(identifier: "en_US")
        let supported = await DictationTranscriber.supportedLocales
        let current = Locale.current

        let match =
            supported.first { $0.identifier(.bcp47) == current.identifier(.bcp47) }
            ?? supported.first {
                $0.language.languageCode == current.language.languageCode
                    && $0.region == current.region
            }
        let locale = match ?? fallback
        cachedLocale = locale
        return locale
    }

    /// Run once at launch: makes sure the language model is on disk so the
    /// first dictation doesn't wait for a download.
    static func preflight() async {
        do {
            let locale = await resolveLocale()
            let transcriber = makeTranscriber(locale: locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                logger.notice("Downloading speech model for \(locale.identifier, privacy: .public)")
                try await request.downloadAndInstall()
            }
            logger.notice("Speech engine ready for \(locale.identifier, privacy: .public)")
        } catch {
            logger.error("Speech preflight failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func makeTranscriber(locale: Locale) -> DictationTranscriber {
        DictationTranscriber(
            locale: locale,
            contentHints: [],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults],  // report words while they are being said
            attributeOptions: [])
    }

    /// Joins two pieces of text with exactly one space, keeping any line breaks
    /// that came from saying "new line" or "new paragraph".
    private static func join(_ text: String, _ piece: String) -> String {
        guard !piece.isEmpty else { return text }
        let needsSpace =
            !(text.isEmpty || text.last?.isWhitespace == true || piece.first?.isWhitespace == true)
        return text + (needsSpace ? " " : "") + piece
    }

    /// Step 1: set up the engine. After this, `feed` accepts audio (it queues
    /// until `begin` is called, so no words are lost while the engine starts).
    func prepare() async throws {
        let locale = await Self.resolveLocale()
        let transcriber = Self.makeTranscriber(locale: locale)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw DictationError.engineUnavailable
        }
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()

        self.targetFormat = format
        self.stream = stream
        self.continuation = continuation
        self.analyzer = SpeechAnalyzer(modules: [transcriber])

        let report = onWords
        collector = Task {
            // The engine sends each stretch of speech several times: first as
            // tentative guesses that keep improving, then once as final.
            var settled = ""
            for try await result in transcriber.results {
                let piece = String(result.text.characters)
                if result.isFinal {
                    settled = Self.join(settled, piece)
                    report?(settled, "")
                } else {
                    report?(settled, piece.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            return settled
        }
    }

    /// Called from the audio thread with each chunk of microphone sound.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let targetFormat, let continuation else { return }
        guard let converted = try? converter.convert(buffer, to: targetFormat) else { return }
        continuation.yield(AnalyzerInput(buffer: converted))
    }

    /// Step 2: start transcribing whatever has been fed so far, and keep going.
    func begin() async throws {
        guard let analyzer, let stream else { throw DictationError.engineUnavailable }
        try await analyzer.start(inputSequence: stream)
    }

    /// Step 3: no more audio is coming. Returns everything that was said.
    func finish() async throws -> String {
        continuation?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        return try await collector?.value ?? ""
    }

    /// Throw the dictation away.
    func cancel() async {
        continuation?.finish()
        await analyzer?.cancelAndFinishNow()
        collector?.cancel()
    }
}

/// The microphone. It is only open between `start` and `stop`.
final class MicCapture {
    private let engine = AVAudioEngine()
    private var running = false

    /// Both callbacks run on the audio thread, not the main thread.
    func start(
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
        onLevel: @escaping @Sendable (Double) -> Void
    ) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DictationError.noMicrophone
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            onBuffer(buffer)
            onLevel(Self.level(of: buffer))
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        running = true
    }

    func stop() {
        guard running else { return }
        running = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Loudness of a chunk as 0...1, where 0 is silence and 1 is a raised voice.
    private static func level(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_01))
        return Double(min(1, max(0, (decibels + 52) / 38)))
    }
}
