// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Whisper is compiled ahead of time into static libraries, so the app stays a
// single file with nothing extra to install. See Vendor/whisper/build-whisper.sh.
let whisperLibraries = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Vendor/whisper/lib")
    .path

let package = Package(
    name: "Speakeasy",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "CWhisper",
            path: "Sources/CWhisper"
        ),
        .executableTarget(
            name: "Speakeasy",
            dependencies: ["CWhisper"],
            path: "Sources/Speakeasy",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags(["-L\(whisperLibraries)"]),
                .linkedLibrary("whisper"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-blas"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("c++"),
                .linkedFramework("Accelerate"),
            ]
        ),
    ]
)
