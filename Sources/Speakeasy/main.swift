import AppKit

let arguments = CommandLine.arguments

// Developer checks (see DevTools.swift). Not used in normal running.
if let index = arguments.firstIndex(of: "--dev-render"), arguments.count > index + 1 {
    MainActor.assumeIsolated {
        DevTools.renderArt(to: arguments[index + 1])
    }
    exit(0)
}
if arguments.contains("--dev-overlay") {
    MainActor.assumeIsolated {
        DevTools.overlayDemo()
    }
}
if let index = arguments.firstIndex(of: "--dev-email"), arguments.count > index + 1 {
    // Prints what a dictation would be pasted as, e.g. --dev-email "email format hi sam …"
    MainActor.assumeIsolated {
        print(EmailFormat.apply(to: arguments[index + 1]))
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--dev-links"), arguments.count > index + 1 {
    // Prints a dictation with sample spoken links filled in, e.g. --dev-links "find me at linkedin link"
    let samples = [
        SavedLink(name: "LinkedIn", value: "https://www.linkedin.com/in/sample"),
        SavedLink(name: "Portfolio", value: "https://sample.design"),
        SavedLink(name: "Email", value: "hello@sample.design"),
        SavedLink(name: "Work email", value: "work@sample.design"),
        SavedLink(name: "GitHub", value: ""),
    ]
    MainActor.assumeIsolated {
        print(Links.apply(to: EmailFormat.apply(to: arguments[index + 1]), links: samples))
    }
    exit(0)
}
if let index = arguments.firstIndex(of: "--dev-transcribe"), arguments.count > index + 1 {
    // Optional: --engine whisperAccurate | whisperFast | apple
    var engine = Engine.current
    if let flag = arguments.firstIndex(of: "--engine"), arguments.count > flag + 1,
        let chosen = Engine(rawValue: arguments[flag + 1])
    {
        engine = chosen
    }
    DevTools.transcribe(path: arguments[index + 1], realtime: arguments.contains("--realtime"), engine: engine)
    RunLoop.main.run()
}

// Only one Speakeasy at a time, or the shortcut would be claimed twice.
if let bundleID = Bundle.main.bundleIdentifier,
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1
{
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
