import AppKit
import NaturalLanguage

/// Spoken formats.
///
/// "Text message format" (or "text format") gives the same clean-up as one
/// short casual message instead.
///
/// "Bullet point format" (or "bullet list format") gives one bullet per item,
/// and "numbered list format" numbers them instead.
///
/// "Formal letter format" (or "letter format") gives a dated, formal letter.
///
/// "Meeting notes format" sorts what was said into notes, decisions and action items.
///
/// "Email format": say those two words anywhere in a dictation and what you said is pasted laid out as an email — greeting on its
/// own line, tidy paragraphs, sign-off and name at the bottom — with filler
/// words, doubled words, capitals, punctuation and grammar slips cleaned up.
///
/// Everything here runs on this Mac. Grammar fixes come from the same checker
/// macOS uses in Mail and Notes, and only its confident, unambiguous
/// suggestions are applied.
enum EmailFormat {
    /// The dictation as an email if it asked for one, otherwise exactly as given.
    @MainActor
    static func apply(to text: String) -> String {
        if let spoken = removingCommand(emailCommand, from: text) { return layOut(spoken) }
        if let spoken = removingCommand(meetingCommand, from: text) { return layOutAsMeetingNotes(spoken) }
        if let spoken = removingCommand(letterCommand, from: text) { return layOutAsLetter(spoken) }
        if let spoken = removingCommand(textCommand, from: text) { return layOutAsTextMessage(spoken) }
        if let spoken = removingCommand(bulletCommand, from: text, keepingColon: true) { return layOutAsList(spoken, numbered: false) }
        if let spoken = removingCommand(numberCommand, from: text, keepingColon: true) { return layOutAsList(spoken, numbered: true) }
        return text
    }

    // MARK: The spoken command

    /// "Email format", also heard as "e-mail format".
    private static let emailCommand = #"e[\s-]?mail\s+format(?:ting|ted|s)?"#
    /// "Text message format", or just "text format".
    private static let textCommand = #"text(?:ing)?(?:[\s-]+messag(?:e|ing))?\s+format(?:ting|ted|s)?"#

    /// "Bullet point list format", "bullet point format", "bullet list format" or "bullet format".
    private static let bulletCommand =
        #"bullet(?:s|ed)?(?:[\s-]+points?)?(?:[\s-]+list)?\s+format(?:ting|ted|s)?"#

    /// "Numbered list format", "number list format" or "numbered format".
    private static let numberCommand =
        #"number(?:s|ed)?(?:[\s-]+(?:points?|list))*\s+format(?:ting|ted|s)?"#

    /// "Formal letter format", "letter format" or "formal format".
    private static let letterCommand =
        #"(?:formal(?:[\s-]+letter)?|letter)\s+format(?:ting|ted|s)?"#

    /// "Meeting notes format", "meeting minutes format", "notes format" or "meeting format".
    private static let meetingCommand =
        #"(?:(?:meeting[\s-]+)?(?:notes?|minutes)|meeting)\s+format(?:ting|ted|s)?"#

    /// The dictation without the spoken command, or nil if it wasn't said.
    /// It counts anywhere: start, middle or end.
    static func removingCommand(_ command: String, from text: String, keepingColon: Bool = false) -> String? {
        // The commas and spaces around the words go with them. A full stop or
        // question mark before them belongs to the email and stays.
        let pattern = "([.!?…]?)[ \\t,:;—–-]*\\b\(command)\\b[ \\t.,:;!?…—–-]*"

        var found = false
        var remaining = text.replacingEachMatch(pattern, options: [.caseInsensitive]) { groups in
            found = true
            if !groups[1].isEmpty { return groups[1] + " " }
            // "…see you then email format. Next…": keep the sentence break.
            if let stop = groups[0].last(where: { ".!?".contains($0) }) { return "\(stop) " }
            // "To do today, bullet format: call the bank, …": keep the heading's colon.
            if keepingColon, groups[0].contains(":") { return ": " }
            // "Running late, text format, see you at six": keep the pause.
            return groups[0].contains(",") ? ", " : " "
        }
        // Said first, there is no sentence before it to end.
        while let first = remaining.first, first.isWhitespace || ".!?,:".contains(first) { remaining.removeFirst() }
        while let last = remaining.last, last.isWhitespace || ",:".contains(last) { remaining.removeLast() }
        return found ? remaining : nil
    }

    // MARK: Text message

    /// "Text message format": the same clean-up as an email, but kept as one
    /// short casual message — no greeting line and no sign-off block.
    @MainActor
    static func layOutAsTextMessage(_ spoken: String) -> String {
        removingFillers(spoken)
            .split(separator: "\n")
            .map { polish($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    // MARK: Bullet list

    /// "Bullet point format": one bullet per item. Items are, in order of
    /// preference: whatever you separated by saying "next bullet" (or "next
    /// point" / "next item") or "new line"; otherwise each sentence; otherwise,
    /// for a single sentence, the things between its commas. Anything before a
    /// colon ("Shopping list: …") becomes a heading line above the bullets.
    ///
    /// "Numbered list format" is the same with 1. 2. 3. in place of the bullets.
    @MainActor
    static func layOutAsList(_ spoken: String, numbered: Bool) -> String {
        let separator = #"[ \t.,:;!?—–-]*\b(?:next|new|another)\s+(?:bullet(?:\s+point)?|point|item|number)\b[ \t.,:;!?—–-]*"#
        let cleaned = removingFillers(spoken)
            .replacingMatches(separator, with: "\n", options: [.caseInsensitive])
        var items = cleaned.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !items.isEmpty else { return "" }

        var heading: String?
        var fragments = false
        if items.count == 1 {
            var only = items[0]
            if let colon = only.firstIndex(of: ":"), only[only.index(after: colon)...].contains(where: \.isLetter) {
                heading = polish(String(only[...colon]))
                only = String(only[only.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            }
            // Split by hand rather than with the system's sentence finder, which
            // reads "Press Command S. Say…" as someone's initial.
            var sentences: [String] = []
            var sentence = ""
            for word in only.split(separator: " ") {
                sentence += (sentence.isEmpty ? "" : " ") + word
                if let last = word.last, ".!?".contains(last), !abbreviations.contains(word.lowercased()) {
                    sentences.append(sentence)
                    sentence = ""
                }
            }
            if !sentence.isEmpty { sentences.append(sentence) }
            if sentences.count > 1 {
                items = sentences
            } else {
                // "milk, eggs and bread" → three bullets
                var parts = only.replacingMatches(#",\s*(?:and|or)\s+"#, with: ",", options: [.caseInsensitive])
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if parts.count >= 2, let last = parts.last,
                    let joiner = last.firstMatch(#"\s+(?:and|or)\s+"#, options: [.caseInsensitive])
                {
                    let text = last as NSString
                    parts.removeLast()
                    parts.append(text.substring(to: joiner.range.location))
                    parts.append(text.substring(from: NSMaxRange(joiner.range)))
                }
                if parts.count > 1 {
                    items = parts
                    fragments = true
                } else {
                    items = [only]
                }
            }
        }

        let bullets = items.map(polish).filter { !$0.isEmpty }.enumerated().map { index, item -> String in
            var item = item
            // Short list entries read better without a full stop.
            if fragments, item.hasSuffix("."), !item.hasSuffix("..") { item.removeLast() }
            return (numbered ? "\(index + 1). " : "• ") + item
        }
        return ([heading].compactMap { $0 } + bullets).joined(separator: "\n")
    }

    // MARK: Email layout

    @MainActor
    static func layOut(_ spoken: String) -> String {
        let email = parts(of: spoken)
        return ([email.greeting].compactMap { $0 } + email.paragraphs + [email.signOff].compactMap { $0 })
            .joined(separator: "\n\n")
    }

    /// A dictation taken apart into greeting line, cleaned-up body paragraphs
    /// and sign-off (with the name on a second line when one was said).
    @MainActor
    private static func parts(of spoken: String) -> (greeting: String?, paragraphs: [String], signOff: String?) {
        var paragraphs = removingFillers(spoken)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !paragraphs.isEmpty else { return (nil, [], nil) }

        // Apple's engine gives no punctuation unless it is spoken, which makes
        // the end of the greeting and the start of the sign-off harder to find.
        let punctuated = spoken.contains { ".!?".contains($0) }

        let (greeting, afterGreeting) = takeGreeting(from: paragraphs[0])
        paragraphs[0] = afterGreeting
        paragraphs.removeAll { $0.isEmpty }

        var signOff: String?
        if let last = paragraphs.last {
            let (body, found) = takeSignOff(from: last, punctuated: punctuated)
            if found != nil {
                paragraphs[paragraphs.count - 1] = body
                signOff = found
            } else if paragraphs.count >= 2 {
                // "Thanks" and the name were dictated on separate lines.
                let joined = paragraphs[paragraphs.count - 2] + " " + last
                let (body, found) = takeSignOff(from: joined, punctuated: punctuated)
                if found != nil {
                    paragraphs.removeLast()
                    paragraphs[paragraphs.count - 1] = body
                    signOff = found
                }
            }
        }

        paragraphs = paragraphs.map(polish).filter { !$0.isEmpty }
        if paragraphs.count == 1 {
            // No "new paragraph" was spoken, so find the breaks ourselves.
            paragraphs = splitIntoParagraphs(paragraphs[0])
        }

        return (greeting, paragraphs, signOff)
    }

    // MARK: Meeting notes

    private enum NotesSection { case notes, decisions, actions }

    private static let sectionNames: [(NotesSection, Set<String>)] = [
        (.notes, ["notes", "discussion", "discussion points", "key points", "general notes", "summary"]),
        (.decisions, ["decisions", "decision", "decisions made"]),
        (.actions, [
            "action items", "action item", "actions", "next steps", "to do", "to dos", "to-dos", "todos",
            "follow ups", "follow-ups",
        ]),
    ]
    /// Capitalised sentence openers that aren't a person's name.
    private static let notPeople: Set<String> = [
        "this", "that", "it", "there", "these", "those", "what", "which", "everything", "nothing", "nobody",
    ]

    /// "Meeting notes format": a dated heading, an attendees line, then what
    /// was said sorted into Notes, Decisions and Action items.
    ///
    /// Sorting is by plain wording. A sentence that starts "Attendees…",
    /// "Topic…", "Decision…" or "Action item…" goes where it says. Saying just
    /// "Decisions." or "Action items." sends everything after it there. Failing
    /// that, "we decided / agreed…" is a decision, "Sarah will…" or "we need
    /// to…" is an action item, and the rest are notes.
    @MainActor
    static func layOutAsMeetingNotes(_ spoken: String) -> String {
        let separator = #"[ \t.,:;!?—–-]*\b(?:next|new|another)\s+(?:bullet(?:\s+point)?|point|item|note)\b[ \t.,:;!?—–-]*"#
        let sentences = removingFillers(spoken)
            .replacingMatches(separator, with: "\n", options: [.caseInsensitive])
            .split(separator: "\n")
            .flatMap { sentencesByHand(in: $0.trimmingCharacters(in: .whitespaces)) }
        guard !sentences.isEmpty else { return "" }

        var topic: String?
        var attendees: String?
        var sticky: NotesSection?
        var notes: [String] = []
        var decisions: [String] = []
        var actions: [String] = []

        /// The sentence without a leading label, if it has that label.
        func afterLabel(_ sentence: String, _ label: String) -> String? {
            guard let match = sentence.firstMatch("^(?:\(label))[\\s:,—–-]+", options: [.caseInsensitive]) else { return nil }
            let rest = (sentence as NSString).substring(from: NSMaxRange(match.range))
            return rest.contains(where: \.isLetter) ? rest : nil
        }
        func bare(_ text: String) -> String {
            text.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;!?"))
        }

        for sentence in sentences {
            // A section name on its own: everything after it belongs there.
            let alone = bare(sentence).lowercased()
            if let section = sectionNames.first(where: { $0.1.contains(alone) })?.0 {
                sticky = section
                continue
            }
            if let rest = afterLabel(
                sentence, #"(?:the\s+)?(?:attendees|participants)(?:\s+(?:were|are|was|included|include))?|attending|present|in\s+attendance"#)
            {
                attendees = bare(rest)
                continue
            }
            if let rest = afterLabel(
                sentence, #"(?:the\s+)?(?:topic|subject|title|agenda)(?:\s+(?:is|was))?|(?:this\s+)?meeting\s+(?:(?:is|was)\s+)?(?:about|on)"#)
            {
                let name = bare(rest)
                topic = name.prefix(1).uppercased() + name.dropFirst()
                continue
            }
            if let rest = afterLabel(sentence, #"decisions?(?:\s+(?:is|was|were|made))?"#) {
                decisions.append(rest)
                continue
            }
            if let rest = afterLabel(
                sentence, #"action\s+items?(?:\s+(?:is|are))?|actions?|next\s+steps?(?:\s+(?:is|are))?|follow[\s-]?ups?|to[\s-]?dos?"#)
            {
                actions.append(rest)
                continue
            }

            if let sticky {
                switch sticky {
                case .notes: notes.append(sentence)
                case .decisions: decisions.append(sentence)
                case .actions: actions.append(sentence)
                }
                continue
            }

            let firstWord = sentence.split(separator: " ").first.map { bare(String($0)).lowercased() } ?? ""
            let someoneWill =
                sentence.firstMatch(
                    #"^(?:[A-Z][\w'’-]*(?:\s+and\s+[A-Z][\w'’-]*)?|we|they|he|she)\s+(?:will|to|needs?\s+to|is\s+going\s+to|are\s+going\s+to|has\s+to|have\s+to|should|must)\b"#
                ) != nil && !notPeople.contains(firstWord)
            let weWill = sentence.firstMatch(#"^(?:I|we|they|he|she)['’]ll\b"#, options: [.caseInsensitive]) != nil
            if sentence.firstMatch(
                #"\b(?:decided|agreed|approved|signed\s+off|settled\s+on|going\s+with)\b"#, options: [.caseInsensitive]) != nil
            {
                decisions.append(sentence)
            } else if someoneWill || weWill {
                actions.append(sentence)
            } else {
                notes.append(sentence)
            }
        }

        let date = DateFormatter()
        date.dateStyle = .long
        date.timeStyle = .none

        var blocks = ["Meeting notes" + (topic.map { ": " + $0 } ?? "") + "\n" + date.string(from: Date())]
        if let attendees, !attendees.isEmpty { blocks.append("Attendees: " + attendees) }
        for (title, items) in [("Notes", notes), ("Decisions", decisions), ("Action items", actions)] {
            let bullets = items.map(polish).filter { !$0.isEmpty }.map { "• " + $0 }
            if !bullets.isEmpty { blocks.append(([title] + bullets).joined(separator: "\n")) }
        }
        return blocks.joined(separator: "\n\n")
    }

    /// Sentences split at full stops and question marks. Done by hand rather
    /// than with the system's sentence finder, which reads "Press Command S.
    /// Say…" as someone's initial.
    private static func sentencesByHand(in text: String) -> [String] {
        var sentences: [String] = []
        var sentence = ""
        for word in text.split(separator: " ") {
            sentence += (sentence.isEmpty ? "" : " ") + word
            if let last = word.last, ".!?".contains(last), !abbreviations.contains(word.lowercased()) {
                sentences.append(sentence)
                sentence = ""
            }
        }
        if !sentence.isEmpty { sentences.append(sentence) }
        return sentences
    }

    // MARK: Formal letter

    private static let formalSignOffs: Set<String> = [
        "yours sincerely", "yours truly", "yours faithfully", "sincerely", "respectfully",
        "best regards", "kind regards", "warm regards", "regards",
    ]

    /// "Formal letter format": today's date, "Dear …," whatever greeting was
    /// spoken, the body with contractions written out in full, and a formal
    /// close. With no name to address it becomes "Dear Sir or Madam," and
    /// "Yours faithfully,"; a casual sign-off ("thanks", "cheers") becomes
    /// "Yours sincerely,".
    @MainActor
    static func layOutAsLetter(_ spoken: String) -> String {
        let letter = parts(of: spoken)
        guard letter.greeting != nil || !letter.paragraphs.isEmpty || letter.signOff != nil else { return "" }

        // "Hi Sarah," → "Dear Sarah,"
        var addressee = ""
        if let greeting = letter.greeting {
            let opener = greetings.map { $0.joined(separator: " ") }
                .first { greeting.lowercased().hasPrefix($0) } ?? ""
            addressee = greeting.dropFirst(opener.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        }
        let named = addressee.first?.isUppercase == true
        let salutation = named ? "Dear \(addressee)," : "Dear Sir or Madam,"

        var close = named ? "Yours sincerely" : "Yours faithfully"
        var name: String?
        if let signOff = letter.signOff {
            let lines = signOff.split(separator: "\n").map(String.init)
            let phrase = lines[0].trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if formalSignOffs.contains(phrase.lowercased()) { close = phrase }
            if lines.count > 1 { name = lines[1] }
        }

        let date = DateFormatter()
        date.dateStyle = .long
        date.timeStyle = .none

        var blocks = [date.string(from: Date()), salutation]
        blocks += letter.paragraphs.map(expandingContractions)
        blocks.append(close + "," + (name.map { "\n" + $0 } ?? ""))
        return blocks.joined(separator: "\n\n")
    }

    private static let contractions: [String: String] = [
        "can't": "cannot", "won't": "will not", "shan't": "shall not", "let's": "let us",
        "i'm": "I am", "i've": "I have", "i'll": "I will",
        "it's": "it is", "that's": "that is", "there's": "there is", "here's": "here is",
        "what's": "what is", "who's": "who is", "he's": "he is", "she's": "she is",
    ]

    /// "I'm" → "I am", "don't" → "do not", for formal writing. Ambiguous ones
    /// ("I'd", "she'd") are left as spoken.
    private static func expandingContractions(_ text: String) -> String {
        func matchingCase(_ expanded: String, _ original: String) -> String {
            original.first?.isUppercase == true ? expanded.prefix(1).uppercased() + expanded.dropFirst() : expanded
        }
        var text = text.replacingOccurrences(of: "’", with: "'")
        // "it's been" is "it has been", not "it is been".
        text = text.replacingMatches(
            #"\b(it|that|there|he|she|what|who)'s\s+(been|got)\b"#, with: "$1 has $2", options: [.caseInsensitive])
        let fixed = contractions.keys.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        text = text.replacingEachMatch("(?<![\\w'])(?:\(fixed))(?![\\w'])", options: [.caseInsensitive]) { groups in
            matchingCase(contractions[groups[0].lowercased()] ?? groups[0], groups[0])
        }
        text = text.replacingMatches(#"\b(\w+)n't\b"#, with: "$1 not")
        text = text.replacingEachMatch(#"\b(we|you|they)'(re|ve|ll)\b"#, options: [.caseInsensitive]) { groups in
            groups[1] + " " + ["re": "are", "ve": "have", "ll": "will"][groups[2].lowercased()]!
        }
        return text
    }

    // MARK: Greeting

    private static let greetings: [[String]] = [
        ["good", "morning"], ["good", "afternoon"], ["good", "evening"],
        ["hi"], ["hello"], ["hey"], ["dear"], ["greetings"],
    ]
    private static let titles: Set<String> = ["mr", "mrs", "ms", "miss", "dr", "prof", "professor"]
    /// Words that can follow "Hi" without being capitalised.
    private static let groupWords: Set<String> = [
        "and", "there", "all", "everyone", "everybody", "team", "folks", "both", "guys",
    ]
    /// Capitalised words that start the message rather than name a person.
    private static let notNames: Set<String> = ["i", "i'm", "i've", "i'll", "i'd", "thanks", "thank"]

    /// Splits "Hi Sarah, thanks for…" into "Hi Sarah," and "thanks for…".
    private static func takeGreeting(from paragraph: String) -> (greeting: String?, rest: String) {
        let words = paragraph.split(separator: " ").map(String.init)
        func bare(_ word: String) -> String {
            word.trimmingCharacters(in: .punctuationCharacters).lowercased().replacingOccurrences(of: "’", with: "'")
        }
        guard
            let opener = greetings.first(where: { opener in
                words.count >= opener.count && zip(opener, words).allSatisfy { $0 == bare($1) }
            })
        else { return (nil, paragraph) }

        let stops = ",.!?:;"
        var index = opener.count
        let openerEnd = words[index - 1].last ?? " "
        var closed = ".!?:;".contains(openerEnd)  // "Hi. Thanks…" names nobody
        var names: [String] = []

        while !closed, index < words.count, names.count < 4 {
            let word = words[index]
            let plain = bare(word)
            let isTitle = titles.contains(plain)
            let capitalised = word.first?.isUppercase == true && !notNames.contains(plain)
            guard isTitle || groupWords.contains(plain) || capitalised else { break }

            var name = word.trimmingCharacters(in: CharacterSet(charactersIn: stops))
            if isTitle {
                name = name.prefix(1).uppercased() + name.dropFirst()
                if word.hasSuffix(".") { name += "." }
            }
            names.append(name)
            index += 1
            if !isTitle, let last = word.last, stops.contains(last) { closed = true }
        }
        if names.last?.lowercased() == "and" {
            names.removeLast()
            index -= 1
        }
        if openerEnd == ",", !closed {
            // "Hi, Thanks for…": the comma already ended the greeting.
            names = []
            index = opener.count
        }

        let hello = opener.joined(separator: " ")
        let line = ([hello.prefix(1).uppercased() + hello.dropFirst()] + names).joined(separator: " ") + ","
        return (line, words[index...].joined(separator: " "))
    }

    // MARK: Sign-off

    private static let signOffs = [
        "thank you so much", "thank you very much", "thanks so much", "thanks a lot", "thanks again",
        "many thanks", "thank you", "thanks", "best regards", "kind regards", "warm regards", "regards",
        "best wishes", "all the best", "best", "cheers", "yours sincerely", "yours truly", "sincerely",
        "talk soon", "speak soon", "take care", "warmly", "respectfully",
    ]
    /// Sign-offs that are safe to spot even with no punctuation and no name after them.
    private static let unmistakableSignOffs = [
        "best regards", "kind regards", "warm regards", "many thanks", "best wishes", "all the best",
        "yours sincerely", "yours truly", "sincerely", "cheers",
    ]

    /// Splits "…see you then. Thanks, Keefer." into the body and "Thanks,\nKeefer".
    private static func takeSignOff(from paragraph: String, punctuated: Bool) -> (body: String, signOff: String?) {
        func alternatives(_ phrases: [String]) -> String {
            phrases.sorted { $0.count > $1.count }
                .map { $0.replacingOccurrences(of: " ", with: "\\s+") }
                .joined(separator: "|")
        }
        let name = #"[A-Z][\w'’-]*(?:\s+[A-Z][\w'’-]*){0,2}"#
        let any = alternatives(signOffs)

        // Normally a sign-off has to begin a sentence or clause, so "I wanted
        // to say thanks" is left alone.
        var patterns = ["(?:^|(?<=[.!?,;])\\s+)(?i:(\(any)))[,.!]?(?:\\s+(\(name)))?[.!]?\\s*$"]
        if !punctuated {
            patterns.append("(?:^|\\s)(?i:(\(any)))\\s+(\(name))\\s*$")
            patterns.append("(?:^|\\s)(?i:(\(alternatives(unmistakableSignOffs))))\\s*$")
        }

        let text = paragraph as NSString
        for pattern in patterns {
            guard let match = paragraph.firstMatch(pattern) else { continue }
            let phrase = text.substring(with: match.range(at: 1))
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            var line = phrase.prefix(1).uppercased() + phrase.dropFirst() + ","
            if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
                line += "\n" + text.substring(with: match.range(at: 2))
            }
            var body = text.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
            while let last = body.last, ",;".contains(last) { body.removeLast() }
            return (body, line)
        }
        return (paragraph, nil)
    }

    // MARK: Clean-up

    /// "Um", "uh" and friends.
    private static func removingFillers(_ text: String) -> String {
        text.replacingMatches(
            #"(?<![\w'’-])(?:u+m+|u+h+m*|erm+|er|hm+|mm+)(?![\w'’-])[,…]*[ \t]*"#, with: "",
            options: [.caseInsensitive])
    }

    /// Doubled words that are usually deliberate.
    private static let allowedDoubles: Set<String> = [
        "had", "that", "very", "really", "so", "no", "bye", "much", "many", "long", "far", "way",
    ]

    private static let missingApostrophes: [String: String] = [
        "dont": "don't", "doesnt": "doesn't", "didnt": "didn't", "cant": "can't", "wont": "won't",
        "isnt": "isn't", "arent": "aren't", "wasnt": "wasn't", "werent": "weren't", "couldnt": "couldn't",
        "shouldnt": "shouldn't", "wouldnt": "wouldn't", "havent": "haven't", "hasnt": "hasn't",
        "im": "I'm", "ive": "I've", "thats": "that's", "whats": "what's", "theres": "there's",
        "youre": "you're", "theyre": "they're", "weve": "we've", "alot": "a lot",
    ]

    /// One paragraph, cleaned up.
    @MainActor
    private static func polish(_ paragraph: String) -> String {
        var text = paragraph

        // "the the" → "the"
        text = text.replacingEachMatch(#"\b([\w'’]+)(?:\s+\1\b)+"#, options: [.caseInsensitive]) { groups in
            allowedDoubles.contains(groups[1].lowercased()) ? groups[0] : groups[1]
        }
        // "i" → "I", including "i'm" and "i'll"
        text = text.replacingMatches(#"(?<![\w'’])i(?=['’](?:m|ve|ll|d)\b|(?![\w'’]))"#, with: "I")
        // "dont" → "don't"
        let slips = missingApostrophes.keys.joined(separator: "|")
        text = text.replacingEachMatch("(?<![\\w'’])(?:\(slips))(?![\\w'’])", options: [.caseInsensitive]) { groups in
            let fixed = missingApostrophes[groups[0].lowercased()] ?? groups[0]
            return groups[0].first?.isUppercase == true ? fixed.prefix(1).uppercased() + fixed.dropFirst() : fixed
        }
        // "should of" → "should have" (but not "should of course")
        text = text.replacingMatches(
            #"\b(could|should|would|must|might)\s+of\b(?!\s+course)"#, with: "$1 have", options: [.caseInsensitive])

        // Punctuation: no space before, one after, no pile-ups.
        text = text.replacingMatches(#"[ \t]+([,.!?;:])"#, with: "$1")
        text = text.replacingMatches(#",(?:\s*,)+"#, with: ",")
        text = text.replacingMatches(#"[,;:]+\s*([.!?])"#, with: "$1")
        text = text.replacingMatches(#"([,;!?])(?=\p{L})"#, with: "$1 ")
        text = text.replacingMatches(#"[ \t]{2,}"#, with: " ")
        text = text.trimmingCharacters(in: .whitespaces)
        while let first = text.first, ",;:.".contains(first) {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty else { return "" }

        while let last = text.last, ",;".contains(last) { text.removeLast() }
        if let last = text.last, !".!?:…\"”')".contains(last) { text += "." }

        text = capitalisingSentences(text)
        text = fixingGrammar(text)
        return capitalisingSentences(text)
    }

    private static let abbreviations = [
        "e.g.", "i.e.", "etc.", "vs.", "mr.", "mrs.", "ms.", "dr.", "prof.", "a.m.", "p.m.", "approx.", "no.",
    ]

    private static func capitalisingSentences(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?:^|[.!?]["”')]?\s+)(\p{Ll})"#) else { return text }
        let result = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: result.length))
        for match in matches.reversed() {
            let letter = match.range(at: 1)
            let before = result.substring(to: letter.location).trimmingCharacters(in: .whitespaces).lowercased()
            if abbreviations.contains(where: { before.hasSuffix(" " + $0) || before == $0 }) { continue }
            result.replaceCharacters(in: letter, with: result.substring(with: letter).uppercased())
        }
        return result as String
    }

    /// Applies the macOS grammar checker's suggestions, but only where it is
    /// confident and offers a single answer ("we needs" → "we need").
    @MainActor
    private static func fixingGrammar(_ text: String) -> String {
        let checker = NSSpellChecker.shared
        var current = text

        // A fix can expose another problem, so look again a couple of times.
        for _ in 0..<3 {
            let whole = current as NSString
            let results = checker.check(
                current, range: NSRange(location: 0, length: whole.length),
                // Grammar results only come back when spelling is checked too.
                types: NSTextCheckingResult.CheckingType([.grammar, .spelling, .correction]).rawValue,
                options: nil, inSpellDocumentWithTag: 0, orthography: nil, wordCount: nil)

            var edits: [(range: NSRange, replacement: String)] = []
            // Spelling is left alone (names and jargon get flagged), except for
            // a missing capital: "friday" → "Friday".
            for result in results where result.resultType == .spelling || result.resultType == .correction {
                let word = whole.substring(with: result.range)
                let suggestion =
                    result.replacementString
                    ?? checker.guesses(
                        forWordRange: result.range, in: current, language: nil, inSpellDocumentWithTag: 0)?.first
                if let suggestion, suggestion != word, suggestion.lowercased() == word.lowercased() {
                    edits.append((result.range, suggestion))
                }
            }
            for result in results where result.resultType == .grammar {
                for detail in result.grammarDetails ?? [] {
                    guard
                        let local = (detail["NSGrammarRange"] as? NSValue)?.rangeValue,
                        let corrections = detail["NSGrammarCorrections"] as? [String], corrections.count == 1,
                        let confidence = (detail["NSGrammarConfidenceScore"] as? NSNumber)?.doubleValue,
                        confidence >= 0.9
                    else { continue }
                    let range = NSRange(location: result.range.location + local.location, length: local.length)
                    guard range.length > 0, NSMaxRange(range) <= whole.length else { continue }

                    var replacement = corrections[0]
                    if whole.substring(with: range).first?.isUppercase == true {
                        replacement = replacement.prefix(1).uppercased() + replacement.dropFirst()
                    }
                    edits.append((range, replacement))
                }
            }
            guard !edits.isEmpty else { break }

            let changed = NSMutableString(string: current)
            var limit = Int.max
            for edit in edits.sorted(by: { $0.range.location > $1.range.location }) {
                guard NSMaxRange(edit.range) <= limit else { continue }  // overlaps a later fix
                changed.replaceCharacters(in: edit.range, with: edit.replacement)
                limit = edit.range.location
            }
            if changed as String == current { break }
            current = changed as String
        }
        return current
    }

    // MARK: Paragraphs

    /// Openers that always start a new paragraph.
    private static let newTopicOpeners = [
        "first", "firstly", "second", "secondly", "third", "thirdly", "finally", "lastly", "separately",
        "anyway", "on another note", "on a separate note", "one more thing", "one last thing",
        "other than that", "moving on", "as for", "regarding",
    ]
    /// Openers that start one only after a couple of sentences.
    private static let softOpeners = ["also", "additionally", "in addition", "next", "meanwhile"]

    private static func splitIntoParagraphs(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let sentences = tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard sentences.count > 2 else { return [text] }

        func opens(_ sentence: String, with openers: [String]) -> Bool {
            let lowered = sentence.lowercased()
            return openers.contains { opener in
                lowered.hasPrefix(opener)
                    && !(lowered.dropFirst(opener.count).first.map { $0.isLetter || $0.isNumber } ?? false)
            }
        }
        func wordCount(_ sentences: [String]) -> Int {
            sentences.reduce(0) { $0 + $1.split(separator: " ").count }
        }

        var paragraphs: [[String]] = []
        var current: [String] = []
        var lastBreakWasForced = false
        for sentence in sentences {
            let newTopic = opens(sentence, with: newTopicOpeners)
            let soft = current.count >= 2 && opens(sentence, with: softOpeners)
            let full = current.count >= 4 || wordCount(current) >= 60
            if !current.isEmpty, newTopic || soft || full {
                paragraphs.append(current)
                current = []
                lastBreakWasForced = !(newTopic || soft)
            }
            current.append(sentence)
        }
        // Don't strand a short closing sentence that was only split off for length.
        if lastBreakWasForced, current.count == 1, wordCount(current) < 10, var previous = paragraphs.popLast() {
            previous += current
            current = previous
        }
        paragraphs.append(current)
        return paragraphs.map { $0.joined(separator: " ") }
    }
}

// MARK: - Regular expression helpers

private extension String {
    func firstMatch(_ pattern: String, options: NSRegularExpression.Options = []) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        return regex.firstMatch(in: self, range: NSRange(location: 0, length: (self as NSString).length))
    }

    func replacingMatches(
        _ pattern: String, with template: String, options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return self }
        return regex.stringByReplacingMatches(
            in: self, range: NSRange(location: 0, length: (self as NSString).length), withTemplate: template)
    }

    /// Replaces each match with whatever `replacement` returns. `groups[0]` is
    /// the whole match and the rest are its capture groups.
    func replacingEachMatch(
        _ pattern: String, options: NSRegularExpression.Options = [], replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return self }
        let result = NSMutableString(string: self)
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: result.length))
        for match in matches.reversed() {
            let groups = (0..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : result.substring(with: range)
            }
            result.replaceCharacters(in: match.range, with: replacement(groups))
        }
        return result as String
    }
}
