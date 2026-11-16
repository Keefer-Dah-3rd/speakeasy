import AVFoundation
import Foundation

/// What every speech engine has to do for one dictation.
protocol DictationBackend: AnyObject, Sendable {
    /// Get ready. After this, `feed` accepts audio.
    func prepare() async throws
    /// A chunk of microphone sound. Called from the audio thread.
    func feed(_ buffer: AVAudioPCMBuffer)
    /// Start working on whatever has been fed so far.
    func begin() async throws
    /// No more audio is coming. Returns everything that was said.
    func finish() async throws -> String
    /// Throw the dictation away.
    func cancel() async
}

/// The speech engines you can pick from the menu bar.
enum Engine: String, CaseIterable {
    case whisperAccurate
    case whisperFast
    case apple

    private static let defaultsKey = "speechEngine"

    /// The engine in use: your saved choice, or the best one that's installed.
    static var current: Engine {
        get {
            if let saved = UserDefaults.standard.string(forKey: defaultsKey).flatMap(Engine.init(rawValue:)),
                saved.isInstalled
            {
                return saved
            }
            return allCases.first { $0.isInstalled } ?? .apple
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var title: String {
        switch self {
        case .whisperAccurate: return "Whisper Accurate"
        case .whisperFast: return "Whisper Fast"
        case .apple: return "Apple Dictation"
        }
    }

    var detail: String {
        switch self {
        case .whisperAccurate: return "Fewest mistakes. Adds punctuation. 1–3 seconds."
        case .whisperFast: return "Adds punctuation. About a second."
        case .apple: return "Instant. Say “comma” and “period” out loud."
        }
    }

    /// Where Whisper model files live. They are large, so they sit outside the app.
    static var modelsFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speakeasy/Models", isDirectory: true)
    }

    var modelURL: URL? {
        switch self {
        case .whisperAccurate: return Self.modelsFolder.appendingPathComponent("ggml-small.en.bin")
        case .whisperFast: return Self.modelsFolder.appendingPathComponent("ggml-base.en.bin")
        case .apple: return nil
        }
    }

    var isInstalled: Bool {
        guard let modelURL else { return true }
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    func makeSession() -> DictationBackend {
        if let modelURL {
            return WhisperSession(modelURL: modelURL)
        }
        return DictationSession()
    }
}
