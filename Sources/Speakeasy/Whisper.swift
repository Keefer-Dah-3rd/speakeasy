import AVFoundation
import CWhisper
import Foundation

/// A Whisper model held in memory. It is loaded when a dictation starts and
/// released as soon as the dictation is done, so Speakeasy stays small while idle.
final class WhisperContext: @unchecked Sendable {
    private static let sampleRate = 16_000

    private let context: OpaquePointer

    /// Every entry in Whisper's vocabulary that is an ellipsis ("...", "…").
    /// Whisper writes one wherever you pause to think; these are switched off
    /// so it has to carry on with a real word or real punctuation instead.
    private let ellipsisTokens: [whisper_token]

    /// Whisper prints a great deal of diagnostic text by default; turn it off once.
    private static let silenceLogs: Void = {
        whisper_log_set({ _, _, _ in }, nil)
        ggml_log_set({ _, _, _ in }, nil)
    }()

    /// One thread per real processor core, up to eight.
    private static let threads: Int32 = {
        var cores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &cores, &size, nil, 0)
        return max(2, min(8, cores))
    }()

    init(modelPath: String) throws {
        _ = Self.silenceLogs
        var params = whisper_context_default_params()
        params.use_gpu = false  // on Intel Macs the processor is faster and more reliable
        guard let context = whisper_init_from_file_with_params(modelPath, params) else {
            throw DictationError.modelUnreadable
        }
        self.context = context

        var ellipses: [whisper_token] = []
        for token in 0..<whisper_n_vocab(context) {
            guard let raw = whisper_token_to_str(context, token) else { continue }
            let text = String(cString: raw)
            if text.contains("..") || text.contains("…") {
                ellipses.append(token)
            }
        }
        self.ellipsisTokens = ellipses
    }

    deinit {
        whisper_free(context)
    }

    /// Turns 16 kHz mono audio into text. Blocks while it works.
    func transcribe(_ audio: [Float]) throws -> String {
        // Whisper invents words when handed silence, so don't hand it any.
        guard audio.count > Self.sampleRate / 4, Self.containsSpeech(audio) else { return "" }

        // A pause to think is not part of what you said. Left in, Whisper marks
        // it with "..." or a full stop and a capital letter; shortened to a
        // normal breath, the sentence reads straight through.
        var samples = PauseTrimmer.tighten(audio)
        let removed = Double(audio.count - samples.count) / Double(Self.sampleRate)
        if removed > 0 {
            let total = Double(audio.count) / Double(Self.sampleRate)
            logger.notice(
                "Pauses shortened by \(removed, format: .fixed(precision: 1)) s of \(total, format: .fixed(precision: 1)) s")
        }

        // It also needs at least a second of audio; pad short clips with silence.
        let minimum = Self.sampleRate * 11 / 10
        if samples.count < minimum {
            samples.append(contentsOf: repeatElement(0, count: minimum - samples.count))
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Self.threads
        params.translate = false
        params.detect_language = false
        params.no_context = true
        params.no_timestamps = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_nst = true  // no "[music]"-style sound labels

        // Whisper normally analyses a full 30 seconds however little was said.
        // Shrinking that window to fit a short dictation makes it much quicker.
        let seconds = Double(samples.count) / Double(Self.sampleRate)
        if seconds < 28 {
            params.audio_ctx = Int32(min(1500, Int(seconds * 50) + 128))
        }

        // Each time Whisper is about to choose its next word, rule out the ellipses.
        params.logits_filter_callback = { _, _, _, _, logits, userData in
            guard let logits, let userData else { return }
            let banned = userData.assumingMemoryBound(to: TokenList.self).pointee
            guard let tokens = banned.tokens else { return }
            for index in 0..<banned.count {
                logits[Int(tokens[index])] = -.infinity
            }
        }

        let status: Int32 = "en".withCString { language in
            params.language = language
            return ellipsisTokens.withUnsafeBufferPointer { ellipses in
                var banned = TokenList(tokens: ellipses.baseAddress, count: ellipses.count)
                return withUnsafeMutablePointer(to: &banned) { bannedPointer in
                    params.logits_filter_callback_user_data = UnsafeMutableRawPointer(bannedPointer)
                    return samples.withUnsafeBufferPointer { buffer in
                        whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                    }
                }
            }
        }
        guard status == 0 else { throw DictationError.transcriptionFailed }

        var text = ""
        for index in 0..<whisper_full_n_segments(context) {
            if let segment = whisper_full_get_segment_text(context, index) {
                text += String(cString: segment)
            }
        }
        return WhisperText.clean(text)
    }

    /// True if any 50 ms stretch is louder than room noise.
    private static func containsSpeech(_ audio: [Float]) -> Bool {
        let window = sampleRate / 20
        var start = 0
        while start + window <= audio.count {
            var sum: Float = 0
            for index in start..<(start + window) {
                sum += audio[index] * audio[index]
            }
            if (sum / Float(window)).squareRoot() > 0.005 {
                return true
            }
            start += window
        }
        return false
    }
}

/// A list of vocabulary entries, in the plain form Whisper's C code can read.
private struct TokenList {
    var tokens: UnsafePointer<whisper_token>?
    var count: Int
}

/// Shortens long silences in a recording, so that stopping to think leaves no
/// trace in the text.
enum PauseTrimmer {
    private static let frame = 320           // 20 ms at 16 kHz
    private static let longestPause = 35     // frames: silences over 0.7 s are shortened…
    private static let keptEachSide = 10     // frames: …to 0.2 s either side of the cut
    private static let fade = 160            // samples: 10 ms, so the join makes no click

    static func tighten(_ audio: [Float]) -> [Float] {
        let frameCount = audio.count / frame
        guard frameCount > longestPause else { return audio }

        var loudness = [Float](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            var sum: Float = 0
            for sample in (index * frame)..<((index + 1) * frame) {
                sum += audio[sample] * audio[sample]
            }
            loudness[index] = (sum / Float(frame)).squareRoot()
        }

        // "Quiet" is judged against this recording: a little above its own
        // background hiss, and never more than a fifth of its speaking level.
        // In a noisy room nothing counts as quiet, and nothing is cut.
        let sorted = loudness.sorted()
        let hiss = sorted[frameCount * 15 / 100]
        let speech = sorted[frameCount * 95 / 100]
        guard speech > 0.005 else { return audio }
        let threshold = min(max(hiss * 2.5, 0.002), speech * 0.2)

        var quiet = loudness.map { $0 < threshold }

        // A click or key tap in the middle of a pause shouldn't split it in two.
        var index = 1
        while index < frameCount - 1 {
            if !quiet[index], quiet[index - 1] {
                var end = index
                while end < frameCount, !quiet[end] { end += 1 }
                if end - index <= 2, end < frameCount {
                    for blip in index..<end { quiet[blip] = true }
                }
                index = end
            } else {
                index += 1
            }
        }

        var output: [Float] = []
        output.reserveCapacity(audio.count)
        var copied = 0  // how much of `audio` has been dealt with, in samples

        func cut(from: Int, to: Int) {
            guard to > from, from >= copied else { return }
            output.append(contentsOf: audio[copied..<from])
            // Fade out into the cut and back in after it.
            let tail = min(fade, output.count)
            for step in 0..<tail {
                output[output.count - tail + step] *= 1 - Float(step + 1) / Float(tail)
            }
            let head = min(fade, audio.count - to)
            for step in 0..<head {
                output.append(audio[to + step] * Float(step + 1) / Float(head))
            }
            copied = to + head
        }

        var runStart: Int?
        for position in 0...frameCount {
            let isQuiet = position < frameCount && quiet[position]
            if isQuiet {
                if runStart == nil { runStart = position }
            } else if let start = runStart {
                runStart = nil
                guard position - start >= longestPause else { continue }
                // Keep a short breath beside the words; drop the rest. At the
                // very start or end of the recording there is only one side.
                let from = start == 0 ? 0 : (start + keptEachSide) * frame
                let to = position == frameCount ? audio.count : (position - keptEachSide) * frame
                cut(from: from, to: to)
            }
        }
        output.append(contentsOf: audio[min(copied, audio.count)...])
        return output
    }
}

enum WhisperText {
    static func clean(_ raw: String) -> String {
        var text = raw

        // Any leftover sound labels such as [BLANK_AUDIO].
        text = text.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)

        // Any ellipsis that still got through: a pause is not something you said.
        text = text.replacingOccurrences(
            of: #"(?:\s*(?:\.{2,}|…))+\s*"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" +([,.!?;:])"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)

        // Whisper writes clock times with a dot ("at 3.30"); use a colon instead.
        text = text.replacingOccurrences(
            of: #"\b(at|by|until|around|before|after) (\d{1,2})\.([0-5]\d)\b(?!\s?(?:%|percent|dollars|million|billion))"#,
            with: "$1 $2:$3",
            options: [.regularExpression, .caseInsensitive])

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One dictation using Whisper. Unlike Apple's engine, Whisper reads the whole
/// recording at once after you stop, which is what lets it punctuate properly.
final class WhisperSession: DictationBackend, @unchecked Sendable {
    private let modelURL: URL
    private let converter = BufferConverter()
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    private let lock = NSLock()
    private var samples: [Float] = []
    private var loading: Task<WhisperContext, Error>?

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    func prepare() async throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw DictationError.modelMissing
        }
        samples.reserveCapacity(16_000 * 30)

        // Load the model in the background while you are talking.
        let path = modelURL.path
        loading = Task.detached(priority: .userInitiated) {
            try WhisperContext(modelPath: path)
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard
            let converted = try? converter.convert(buffer, to: format),
            let channel = converted.floatChannelData?[0]
        else { return }

        let chunk = UnsafeBufferPointer(start: channel, count: Int(converted.frameLength))
        lock.withLock { samples.append(contentsOf: chunk) }
    }

    func begin() async throws {}

    func finish() async throws -> String {
        guard let loading else { throw DictationError.engineUnavailable }
        let context = try await loading.value

        let audio = lock.withLock {
            let recorded = samples
            samples = []
            return recorded
        }

        return try await Task.detached(priority: .userInitiated) {
            try context.transcribe(audio)
        }.value
    }

    func cancel() async {
        loading?.cancel()
        loading = nil
        lock.withLock { samples = [] }
    }
}
