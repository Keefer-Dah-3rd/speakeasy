import AppKit
import AVFoundation
import SwiftUI

/// Checks that can run without a microphone or a person at the keyboard.
/// Reached only through the `--dev-…` command-line flags in main.swift.
enum DevTools {
    // MARK: Art

    /// Writes still frames of the mug, plus the app icon, as PNG files.
    @MainActor
    static func renderArt(to directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // One full sway (two beats), quiet and loud.
        let dance = stride(from: 0.4, to: 0.4 + 0.92, by: 0.115).map { time in
            MugPose(time: time, phase: .listening, phaseTime: time, level: 0.15)
        }
        let loud = stride(from: 0.4, to: 0.4 + 0.92, by: 0.115).map { time in
            MugPose(time: time, phase: .listening, phaseTime: time, level: 0.95)
        }
        let lifecycle: [MugPose] = [
            MugPose(time: 0.05, phase: .listening, phaseTime: 0.05, level: 0),
            MugPose(time: 0.15, phase: .listening, phaseTime: 0.15, level: 0),
            MugPose(time: 2.0, phase: .processing, phaseTime: 0.1, level: 0),
            MugPose(time: 2.2, phase: .processing, phaseTime: 0.3, level: 0),
            MugPose(time: 2.6, phase: .processing, phaseTime: 0.7, level: 0),
            MugPose(time: 3.0, phase: .leaving, phaseTime: 0.06, level: 0, finished: true),
            MugPose(time: 3.0, phase: .leaving, phaseTime: 0.12, level: 0, finished: true),
            MugPose(time: 6.52, phase: .listening, phaseTime: 6.52, level: 0.4),
        ]

        let light = Color(white: 0.97)
        let dark = Color(white: 0.13)
        write(sheet(dance, background: light), to: folder.appendingPathComponent("dance-light.png"))
        write(sheet(loud, background: dark), to: folder.appendingPathComponent("dance-loud-dark.png"))
        write(sheet(lifecycle, background: light), to: folder.appendingPathComponent("lifecycle-light.png"))

        // True on-screen size, to judge legibility.
        write(
            sheet(Array(dance.prefix(4)), background: light, cell: 150, scale: 2),
            to: folder.appendingPathComponent("actual-size.png"))

        // The speech bubble: growing text, a long dictation that has scrolled,
        // and the bubble flipped to the mug's left.
        let captions: [(text: String, onLeft: Bool)] = [
            ("Hi Sarah", false),
            ("Hi Sarah thanks for getting back to me so quickly I can", false),
            ("Thanks for sending the proposal over I read through it last night and I have three thoughts first "
                + "the timeline feels tight especially the two weeks set aside for user testing second could we", false),
            ("Sounds good see you at six", true),
            ("Thanks for sending the proposal over I read through it last night and I have three thoughts", true),
        ]
        write(bubbleSheet(captions, pose: dance[2], background: light), to: folder.appendingPathComponent("bubble-light.png"))
        write(bubbleSheet(captions, pose: loud[5], background: dark), to: folder.appendingPathComponent("bubble-dark.png"))

        let icon = ImageRenderer(content: IconArt())
        icon.scale = 1
        write(icon.nsImage, to: folder.appendingPathComponent("icon-1024.png"))
    }

    @MainActor
    private static func sheet(
        _ poses: [MugPose], background: Color, cell: CGFloat = 200, scale: CGFloat = 1
    ) -> NSImage? {
        let view = HStack(spacing: 0) {
            ForEach(0..<poses.count, id: \.self) { index in
                MugCanvas(pose: poses[index])
                    .frame(width: cell, height: cell)
            }
        }
        .background(background)

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
    }

    @MainActor
    private static func bubbleSheet(
        _ captions: [(text: String, onLeft: Bool)], pose: MugPose, background: Color
    ) -> NSImage? {
        let models = captions.map { sample -> CaptionModel in
            let model = CaptionModel()
            model.bubbleOnLeft = sample.onLeft
            model.update(settled: "", tentative: sample.text)
            return model
        }
        let view = VStack(spacing: 0) {
            ForEach(0..<models.count, id: \.self) { index in
                OverlayView(caption: models[index]) {
                    MugCanvas(pose: pose)
                }
            }
        }
        .padding(12)
        .background(background)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage
    }

    private static func write(_ image: NSImage?, to url: URL) {
        guard
            let tiff = image?.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("could not render \(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
        print("wrote \(url.path)")
    }

    // MARK: Overlay

    /// Shows the real on-screen mug beside the pointer for a few seconds:
    /// dance, "bottoms up", pop away. Then quits.
    @MainActor
    static func overlayDemo() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let overlay = MugOverlay()
        overlay.show()

        let script =
            "Thanks for sending the proposal over I read through it last night and I have three thoughts "
            + "first the timeline feels tight especially the two weeks set aside for user testing"
        let words = script.split(separator: " ").map(String.init)

        var ticks = 0
        let voice = Timer(timeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                ticks += 1
                let t = Double(ticks) * 0.05
                overlay.setLevel(max(0, 0.5 + 0.45 * sin(t * 6)))

                // A new word roughly every 0.15 s, starting after a short pause.
                let spoken = min(words.count, max(0, (ticks - 8) / 3))
                overlay.setWords(settled: "", tentative: words.prefix(spoken).joined(separator: " "))
            }
        }
        RunLoop.main.add(voice, forMode: .common)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
            voice.invalidate()
            overlay.showProcessing()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            overlay.hide()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            print("overlay demo finished")
            exit(0)
        }
        app.run()
    }

    // MARK: Speech

    /// Sends an audio file through exactly the path live microphone audio
    /// takes, and prints what came out and how long it took.
    static func transcribe(path: String, realtime: Bool, engine: Engine) {
        Task {
            do {
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                let format = file.processingFormat
                let seconds = Double(file.length) / format.sampleRate

                let session = engine.makeSession()
                let begun = Date()

                // Record when live words arrive, to check they keep pace with speech.
                let updates = LiveWordLog()
                (session as? DictationSession)?.onWords = { settled, tentative in
                    updates.add(Date().timeIntervalSince(begun), settled: settled, tentative: tentative)
                }
                try await session.prepare()
                let prepared = Date()
                try await session.begin()

                while file.framePosition < file.length {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { break }
                    try file.read(into: buffer, frameCount: 4096)
                    if buffer.frameLength == 0 { break }
                    session.feed(buffer)
                    if realtime {
                        try await Task.sleep(for: .seconds(Double(buffer.frameLength) / format.sampleRate))
                    }
                }
                let stopped = Date()
                let text = try await session.finish()
                let done = Date()

                print(String(format: "%@ | audio %.1fs | engine ready in %.0f ms | wait after stop %.0f ms",
                             engine.title,
                             seconds,
                             prepared.timeIntervalSince(begun) * 1000,
                             done.timeIntervalSince(stopped) * 1000))
                print("text: \(text)")
                updates.printSummary()
                exit(0)
            } catch {
                print("FAILED: \(error)")
                exit(1)
            }
        }
    }
}

/// Collects live-word updates during a `--dev-transcribe` run.
private final class LiveWordLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(time: Double, settled: String, tentative: String)] = []

    func add(_ time: Double, settled: String, tentative: String) {
        lock.withLock { entries.append((time, settled, tentative)) }
    }

    func printSummary() {
        let all = lock.withLock { entries }
        guard !all.isEmpty else { return }
        print("live updates: \(all.count), first at \(String(format: "%.1f", all[0].time))s")
        // A handful of evenly spaced snapshots.
        let step = max(1, all.count / 6)
        for index in stride(from: 0, to: all.count, by: step) {
            let entry = all[index]
            let tail = String(entry.settled.suffix(40))
            print(String(format: "  %5.1fs  settled …%@ | tentative: %@", entry.time, tail, entry.tentative))
        }
    }
}

/// The app icon: the mug on a sky-blue tile.
private struct IconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.84, blue: 1.0),
                            Color(red: 0.22, green: 0.60, blue: 0.93),
                        ],
                        startPoint: .top,
                        endPoint: .bottom))
                .frame(width: 824, height: 824)

            MugCanvas(pose: MugPose(time: 4.75, phase: .listening, phaseTime: 4.75, level: 0.5))
                .frame(width: 800, height: 800)
                .offset(x: 6, y: 24)
        }
        .frame(width: 1024, height: 1024)
    }
}
