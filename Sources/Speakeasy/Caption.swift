import AppKit
import SwiftUI

/// Breaks the words so far into lines, the way a live caption does: lines fill
/// up left to right and, once full, stay put while new words start the next
/// line. Only the most recent lines are shown, so long dictations scroll.
enum CaptionLayout {
    static let fontSize: CGFloat = 15
    static let maxLineWidth: CGFloat = 244
    static let visibleLines = 3

    static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        if let rounded = base.fontDescriptor.withDesign(.rounded),
            let font = NSFont(descriptor: rounded, size: fontSize)
        {
            return font
        }
        return base
    }()

    private static let spaceWidth = width(of: " ")

    private static func width(of text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// The last few lines of `text`, wrapped to the bubble's width.
    static func lines(for text: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var currentWidth: CGFloat = 0

        for word in text.split(whereSeparator: \.isWhitespace) {
            let word = String(word)
            let wordWidth = width(of: word)
            if current.isEmpty {
                current = word
                currentWidth = wordWidth
            } else if currentWidth + spaceWidth + wordWidth <= maxLineWidth {
                current += " " + word
                currentWidth += spaceWidth + wordWidth
            } else {
                lines.append(current)
                current = word
                currentWidth = wordWidth
            }
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return Array(lines.suffix(visibleLines))
    }
}

/// The live words shown in the speech bubble.
@MainActor
final class CaptionModel: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var visible = false
    /// True when there is no room to the right of the mug, so the bubble sits
    /// on its left instead.
    @Published var bubbleOnLeft = false

    private var text = ""

    func reset() {
        text = ""
        lines = []
        visible = false
    }

    /// `settled` words are final; `tentative` ones may still change.
    func update(settled: String, tentative: String) {
        let combined = [settled, tentative]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard combined != text else { return }
        text = combined

        let wrapped = CaptionLayout.lines(for: combined)
        if wrapped != lines {
            lines = wrapped
        }
        if !wrapped.isEmpty && !visible {
            visible = true
        }
    }

    func dismiss() {
        if visible {
            visible = false
        }
    }
}

/// The mug with its speech bubble: the whole floating overlay.
struct OverlayView<Mug: View>: View {
    @ObservedObject var caption: CaptionModel
    @ViewBuilder var mug: () -> Mug

    var body: some View {
        let onLeft = caption.bubbleOnLeft
        HStack(alignment: .top, spacing: 0) {
            if onLeft {
                bubbleSlot(onLeft: true)
            }
            mug()
                .frame(width: MugOverlay.mugSide, height: MugOverlay.mugSide)
            if !onLeft {
                bubbleSlot(onLeft: false)
            }
        }
        .frame(width: MugOverlay.width, height: MugOverlay.mugSide)
    }

    /// The area beside the mug that the bubble can grow into. It tucks slightly
    /// under the mug's empty margin so the bubble's tail lands near the mug.
    private func bubbleSlot(onLeft: Bool) -> some View {
        let overlap: CGFloat = onLeft ? 30 : 20
        return ZStack(alignment: onLeft ? .topTrailing : .topLeading) {
            Color.clear
            if caption.visible {
                CaptionBubble(lines: caption.lines, tailOnLeft: !onLeft)
                    .padding(.top, 34)
                    .transition(
                        .scale(scale: 0.5, anchor: onLeft ? .trailing : .leading)
                            .combined(with: .opacity))
            }
        }
        .frame(width: MugOverlay.bubbleZone + overlap, height: MugOverlay.mugSide)
        .padding(onLeft ? .trailing : .leading, -overlap)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: caption.visible)
    }
}

/// A comic-style speech bubble holding the live words.
struct CaptionBubble: View {
    let lines: [String]
    let tailOnLeft: Bool

    private static let tail: CGFloat = 9
    private static let outline: CGFloat = 3

    var body: some View {
        Text(lines.joined(separator: "\n"))
            .font(Font(CaptionLayout.font))
            .foregroundStyle(MugArt.ink)
            .lineLimit(CaptionLayout.visibleLines)
            .multilineTextAlignment(.leading)
            .lineSpacing(1)
            .fixedSize()  // lines are already wrapped; never re-wrap them
            .padding(.vertical, 10 + Self.outline)
            .padding(.leading, 12 + Self.outline + (tailOnLeft ? Self.tail : 0))
            .padding(.trailing, 12 + Self.outline + (tailOnLeft ? 0 : Self.tail))
            .background(BubbleBackground(tailOnLeft: tailOnLeft, tail: Self.tail, outline: Self.outline))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .accessibilityLabel(lines.joined(separator: " "))
    }
}

private struct BubbleBackground: View {
    let tailOnLeft: Bool
    let tail: CGFloat
    let outline: CGFloat

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: outline, dy: outline)
            let body = CGRect(
                x: bounds.minX + (tailOnLeft ? tail : 0),
                y: bounds.minY,
                width: bounds.width - tail,
                height: bounds.height)
            let bodyPath = Path(
                roundedRect: body, cornerRadius: min(15, body.height / 2), style: .continuous)

            // A small pointer toward the mug, near the top of the bubble.
            let y = min(body.minY + 21, body.midY)
            var tailPath = Path()
            if tailOnLeft {
                tailPath.move(to: CGPoint(x: body.minX + 3, y: y - 6))
                tailPath.addLine(to: CGPoint(x: bounds.minX, y: y + 3))
                tailPath.addLine(to: CGPoint(x: body.minX + 3, y: y + 7))
            } else {
                tailPath.move(to: CGPoint(x: body.maxX - 3, y: y - 6))
                tailPath.addLine(to: CGPoint(x: bounds.maxX, y: y + 3))
                tailPath.addLine(to: CGPoint(x: body.maxX - 3, y: y + 7))
            }
            tailPath.closeSubpath()

            // Ink first, then the fill on top, so the two pieces share one outline.
            let ink = StrokeStyle(lineWidth: outline * 2 - 1, lineJoin: .round)
            for path in [bodyPath, tailPath] {
                context.stroke(path, with: .color(MugArt.ink), style: ink)
            }
            for path in [bodyPath, tailPath] {
                context.fill(path, with: .color(MugArt.foam))
            }
        }
    }
}
