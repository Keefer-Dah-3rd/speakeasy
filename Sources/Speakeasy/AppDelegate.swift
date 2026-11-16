import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State {
        case idle        // waiting for the shortcut; microphone is off
        case starting    // shortcut pressed, microphone coming up
        case listening   // recording and transcribing
        case processing  // finishing the last words and pasting
    }

    /// A forgotten dictation stops itself after this long.
    private static let longestDictation: TimeInterval = 10 * 60

    private var state: State = .idle {
        didSet { refreshStatusIcon() }
    }

    private var statusItem: NSStatusItem!
    private let toggleItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleFromMenu), keyEquivalent: "s")
    private let problemItem = NSMenuItem(title: "", action: #selector(openSetup), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")

    private let overlay = MugOverlay()
    private let setup = SetupWindowController()
    private let links = LinksWindowController()

    private let engineMenu = NSMenu()
    private var session: DictationBackend?
    /// Supplies the live words when Whisper is doing the real transcription.
    private var preview: DictationSession?
    /// Counts dictations, so late words from an old one are never shown.
    private var dictationID = 0
    private var mic: MicCapture?
    private var startTask: Task<Bool, Never>?
    private var escapeHotKey: UInt32?
    private var capTimer: Timer?
    private var lastToggle = Date.distantPast
    private var hotKeyRegistered = false
    private var lastProblem: String?
    private var activeEngine = Engine.current

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        let id = HotKeyCenter.shared.register(keyCode: kVK_ANSI_S, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.toggle()
        }
        hotKeyRegistered = id != nil
        if hotKeyRegistered {
            logger.notice("Shortcut Command-Shift-S registered")
        } else {
            logger.error("Could not register Command-Shift-S")
            lastProblem = "Another app is already using ⇧⌘S, so the shortcut is off."
        }

        Task.detached(priority: .utility) {
            await DictationSession.preflight()
        }

        // "--links" opens the Spoken Links window straight away.
        if CommandLine.arguments.contains("--links") {
            links.show()
        }

        // "--quiet" skips the welcome window (used when measuring idle cost).
        let quiet = CommandLine.arguments.contains("--quiet")
        if !quiet, Permissions.microphone != .granted || !Permissions.accessibility {
            setup.show()
        }
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshStatusIcon()

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        problemItem.target = self
        problemItem.isHidden = true
        menu.addItem(problemItem)

        menu.addItem(.separator())

        let setupItem = NSMenuItem(title: "Setup & Permissions…", action: #selector(openSetup), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        let linksItem = NSMenuItem(title: "Spoken Links…", action: #selector(openLinks), keyEquivalent: "")
        linksItem.target = self
        menu.addItem(linksItem)

        let engineItem = NSMenuItem(title: "Speech Engine", action: nil, keyEquivalent: "")
        engineMenu.autoenablesItems = false
        for engine in Engine.allCases {
            let item = NSMenuItem(title: engine.title, action: #selector(chooseEngine(_:)), keyEquivalent: "")
            item.representedObject = engine.rawValue
            item.target = self
            engineMenu.addItem(item)
        }
        engineItem.submenu = engineMenu
        menu.addItem(engineItem)

        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Speakeasy", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        let active = state != .idle
        let image = NSImage(
            systemSymbolName: active ? "mug.fill" : "mug",
            accessibilityDescription: active ? "Speakeasy, listening" : "Speakeasy")
        if let image {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = "🍺"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = state == .idle ? "Start Dictation" : "Stop Dictation"
        toggleItem.isEnabled = state != .processing

        var problem = lastProblem
        if Permissions.microphone == .denied {
            problem = "Microphone access is off — fix…"
        } else if !Permissions.accessibility {
            problem = "Accessibility is off, so text won't paste — fix…"
        }
        problemItem.title = problem.map { "⚠︎ " + $0 } ?? ""
        problemItem.isHidden = problem == nil

        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let current = Engine.current
        for item in engineMenu.items {
            guard
                let raw = item.representedObject as? String,
                let engine = Engine(rawValue: raw)
            else { continue }
            item.state = engine == current ? .on : .off
            item.isEnabled = engine.isInstalled
            item.subtitle = engine.isInstalled ? engine.detail : "Model not installed."
        }
    }

    @objc private func chooseEngine(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let engine = Engine(rawValue: raw)
        else { return }
        Engine.current = engine
        logger.notice("Speech engine set to \(engine.title, privacy: .public)")
    }

    @objc private func toggleFromMenu() {
        toggle()
    }

    @objc private func openSetup() {
        setup.show()
    }

    @objc private func openLinks() {
        links.show()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            lastProblem = nil
        } catch {
            lastProblem = "Couldn't change Start at Login."
            logger.error("Login item change failed: \(String(describing: error), privacy: .public)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Dictation

    private func toggle() {
        // Ignore a bounce from one physical press.
        let now = Date()
        guard now.timeIntervalSince(lastToggle) > 0.25 else { return }
        lastToggle = now

        switch state {
        case .idle:
            startDictation()
        case .starting, .listening:
            stopDictation(insert: true)
        case .processing:
            break
        }
    }

    private func startDictation() {
        switch Permissions.microphone {
        case .granted:
            break
        case .undetermined:
            Permissions.requestMicrophone { [weak self] granted in
                if granted {
                    self?.startDictation()
                } else {
                    self?.setup.show()
                }
            }
            return
        case .denied:
            setup.show()
            return
        }

        state = .starting
        lastProblem = nil
        overlay.show()

        // Escape cancels, but only while a dictation is running.
        escapeHotKey = HotKeyCenter.shared.register(keyCode: kVK_Escape, modifiers: 0) { [weak self] in
            self?.stopDictation(insert: false)
        }

        let engine = Engine.current
        let session = engine.makeSession()
        let mic = MicCapture()

        // The words in the speech bubble always come from Apple's engine,
        // because it is the one that can report them while you are still
        // talking. When Whisper is doing the real transcription, a second
        // session listens alongside it just to supply them.
        let preview: DictationSession? = session is DictationSession ? nil : DictationSession()
        dictationID += 1
        let id = dictationID
        let live = (session as? DictationSession) ?? preview
        live?.onWords = { [weak self] settled, tentative in
            DispatchQueue.main.async {
                guard let self, self.dictationID == id else { return }
                self.overlay.setWords(settled: settled, tentative: tentative)
            }
        }

        self.session = session
        self.preview = preview
        self.mic = mic
        self.activeEngine = engine
        let pressed = Date()

        startTask = Task { @MainActor [weak self] in
            do {
                try await session.prepare()
                try? await preview?.prepare()  // the bubble is a nicety; never fail over it
                try mic.start(
                    onBuffer: { buffer in
                        session.feed(buffer)
                        preview?.feed(buffer)
                    },
                    onLevel: { level in
                        DispatchQueue.main.async { self?.overlay.setLevel(level) }
                    })
                let delay = Int(Date().timeIntervalSince(pressed) * 1000)
                logger.notice("Microphone live \(delay) ms after the shortcut")
                try await session.begin()
                try? await preview?.begin()
                if self?.state == .starting {
                    self?.state = .listening
                }
                return true
            } catch {
                self?.startFailed(error)
                return false
            }
        }

        capTimer = Timer.scheduledTimer(withTimeInterval: Self.longestDictation, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopDictation(insert: true)
            }
        }
    }

    private func startFailed(_ error: Error) {
        logger.error("Dictation could not start: \(String(describing: error), privacy: .public)")
        lastProblem = error.localizedDescription

        // If stop was already pressed, its own cleanup is running.
        guard state == .starting || state == .listening else { return }
        mic?.stop()
        clearSession()
        overlay.hide()
        NSSound.beep()
        state = .idle
    }

    private func stopDictation(insert: Bool) {
        guard state == .starting || state == .listening else { return }
        state = .processing

        let session = self.session
        let preview = self.preview
        let mic = self.mic
        let startTask = self.startTask
        clearSession()

        if insert {
            overlay.showProcessing()
        } else {
            overlay.hide()
        }
        let stopPressed = Date()

        Task { @MainActor in
            let started = await startTask?.value ?? false
            var text = ""

            if started, let session {
                if insert {
                    // Let the last syllable reach the microphone buffer.
                    try? await Task.sleep(for: .milliseconds(150))
                    mic?.stop()
                    // The bubble's own listener is done; free the processor for Whisper.
                    await preview?.cancel()
                    do {
                        text = try await session.finish()
                    } catch {
                        self.lastProblem = "That dictation couldn't be transcribed."
                        logger.error("Transcription failed: \(String(describing: error), privacy: .public)")
                        NSSound.beep()
                    }
                } else {
                    mic?.stop()
                    await preview?.cancel()
                    await session.cancel()
                }
            } else {
                mic?.stop()
            }

            // Saying "email format", "text message format", "bullet point format", "numbered list format", "formal letter format" or "meeting notes format" anywhere reformats the dictation.
            // Saying a saved name followed by "link" ("LinkedIn link", "email link") pastes what was saved for it.
            let cleaned = Links.apply(to: EmailFormat.apply(to: Self.tidy(text)))
            self.overlay.hide()

            if !cleaned.isEmpty {
                let outcome = await TextInserter.insert(cleaned)
                if outcome == .copiedOnly {
                    self.setup.show(
                        note: "Your words are on the clipboard — press ⌘V to paste them. "
                            + "Turn on Accessibility and Speakeasy will paste for you.")
                }
            }

            let wait = Int(Date().timeIntervalSince(stopPressed) * 1000)
            let engineName = self.activeEngine.title
            logger.notice(
                "Dictation finished with \(engineName, privacy: .public): \(cleaned.count) characters, \(wait) ms after stop")
            self.state = .idle
        }
    }

    private func clearSession() {
        capTimer?.invalidate()
        capTimer = nil
        if let escapeHotKey {
            HotKeyCenter.shared.unregister(escapeHotKey)
        }
        escapeHotKey = nil
        session = nil
        preview = nil
        mic = nil
        startTask = nil
    }

    /// Collapse stray spaces from the engine, keeping deliberate line breaks.
    private static func tidy(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
