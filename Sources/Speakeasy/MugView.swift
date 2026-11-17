import SwiftUI

/// What the mug is doing right now.
enum MugPhase {
    case listening   // dancing while you talk
    case processing  // "bottoms up" while the last words are turned into text
    case leaving     // popping away
}

/// Everything needed to draw one frame. Drawing is a pure function of this, so
/// the same code animates live and renders still frames for checking the art.
struct MugPose {
    var time: Double            // seconds since the mug appeared
    var phase: MugPhase
    var phaseTime: Double       // seconds since the phase began
    var level: Double           // 0...1, how loud the microphone is
    var finished: Bool = false  // true when leaving after a completed dictation
    var drink: Drink = .beer    // which drink is dancing this time
}

struct MugCanvas: View {
    let pose: MugPose

    var body: some View {
        Canvas { context, size in
            var ctx = context
            MugArt.draw(&ctx, size: size, pose: pose)
        }
    }
}

enum MugArt {
    // Thick ink outline with flat, saturated fills.
    static let ink = Color(red: 0.11, green: 0.07, blue: 0.04)
    static let glass = Color(red: 1.00, green: 0.96, blue: 0.82)
    static let beerLight = Color(red: 1.00, green: 0.80, blue: 0.16)
    static let beerDeep = Color(red: 0.97, green: 0.60, blue: 0.05)
    static let foam = Color(red: 1.00, green: 0.99, blue: 0.96)

    /// The art is designed on a 140-unit square: a 120-unit mug area plus head
    /// room so the hop and the sway never clip at the window edge.
    static let designSize: CGFloat = 140

    /// Where the middle of the mug's base rests. The mug hops, leans and
    /// squashes about this point.
    private static let base = CGPoint(x: 57, y: 93)

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, pose: MugPose) {
        let unit = min(size.width, size.height) / designSize
        ctx.translateBy(
            x: (size.width - designSize * unit) / 2,
            y: (size.height - designSize * unit) / 2)
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: 12, y: 23)

        let listening = pose.phase == .listening
        let beat = 0.46
        let swing = sin(.pi * pose.time / beat)  // -1...1, one sway every two beats
        let energy = 0.6 + 0.4 * pose.level

        var hop = 0.0
        var lean = 0.0
        var squash = 0.0
        var drain = 0.0
        var scale = 0.25 + 0.75 * easeOutBack(min(1, pose.time / 0.26))

        func chug(_ t: Double) {
            lean = -22 * easeOut(min(1, t / 0.3)) + sin(t * 10) * 1.5
            drain = easeOut(min(1, t / 0.7))
        }

        switch pose.phase {
        case .listening:
            hop = abs(swing)
            lean = swing * 8 * energy
            squash = pow(1 - hop, 3)
        case .processing:
            chug(pose.phaseTime)
        case .leaving:
            if pose.finished { chug(10) }
            let p = min(1, pose.phaseTime / 0.18)
            scale *= 1 - p * p
        }

        let lift = hop * (5 + 7 * pose.level)

        // Ground shadow, which shrinks as the mug leaves the ground.
        let shadowWidth = pose.drink.shadowWidth * scale * (1 - 0.22 * hop)
        let shadowHeight = 8 * scale
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: base.x - shadowWidth / 2, y: base.y + 1.5 - shadowHeight / 2,
                width: shadowWidth, height: shadowHeight)),
            with: .color(.black.opacity(0.20)))

        // A thin light halo keeps the ink outline readable on dark windows.
        var haloed = ctx
        haloed.addFilter(.shadow(color: .white.opacity(0.95), radius: 1.3))
        haloed.drawLayer { layer in
            layer.translateBy(x: base.x, y: base.y - lift)
            layer.rotate(by: .degrees(lean))
            layer.scaleBy(x: scale * (1 + 0.06 * squash), y: scale * (1 - 0.08 * squash))
            layer.translateBy(x: -base.x, y: -base.y)

            if pose.drink == .beer {
                drawHandle(&layer)
                drawBody(&layer, time: pose.time, drain: drain, energy: energy)
                drawFoam(&layer, time: pose.time, wobble: listening ? energy : 0.15)
            } else {
                DrinkArt.draw(
                    &layer, drink: pose.drink, time: pose.time, drain: drain,
                    energy: energy, wobble: listening ? energy : 0.15)
            }
        }
    }

    // MARK: Parts

    private static var bodyPath: Path {
        var body = Path()
        body.move(to: CGPoint(x: 33, y: 36))
        body.addLine(to: CGPoint(x: 81, y: 36))
        body.addLine(to: CGPoint(x: 78, y: 86))
        body.addQuadCurve(to: CGPoint(x: 71, y: 93), control: CGPoint(x: 78, y: 93))
        body.addLine(to: CGPoint(x: 43, y: 93))
        body.addQuadCurve(to: CGPoint(x: 36, y: 86), control: CGPoint(x: 36, y: 93))
        body.closeSubpath()
        return body
    }

    private static func drawHandle(_ layer: inout GraphicsContext) {
        var handle = Path()
        handle.move(to: CGPoint(x: 78, y: 50))
        handle.addCurve(
            to: CGPoint(x: 77, y: 80),
            control1: CGPoint(x: 102, y: 47),
            control2: CGPoint(x: 101, y: 83))
        layer.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 11.5, lineCap: .round))
        layer.stroke(handle, with: .color(glass), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
    }

    private static func drawBody(_ layer: inout GraphicsContext, time: Double, drain: Double, energy: Double) {
        let body = bodyPath
        layer.fill(body, with: .color(glass))

        layer.drawLayer { inner in
            inner.clip(to: body)

            // Beer, with a sloshing surface that drops as the mug "drinks".
            let top = 47 + 33 * drain
            var beer = Path()
            beer.move(to: CGPoint(x: 28, y: 96))
            for x in stride(from: 28.0, through: 86.0, by: 2.0) {
                let wave = sin(x * 0.28 + time * 7) * 1.2 * energy
                beer.addLine(to: CGPoint(x: x, y: top + wave))
            }
            beer.addLine(to: CGPoint(x: 86, y: 96))
            beer.closeSubpath()
            inner.fill(
                beer,
                with: .linearGradient(
                    Gradient(colors: [beerLight, beerDeep]),
                    startPoint: CGPoint(x: 0, y: 44),
                    endPoint: CGPoint(x: 0, y: 94)))

            // Bubbles rising through whatever beer is left.
            let depth = 90 - top
            if depth > 12 {
                let bubbles: [(x: Double, speed: Double, offset: Double, radius: Double)] = [
                    (43, 0.55, 0.10, 1.6), (71, 0.80, 0.45, 2.0), (56, 0.65, 0.70, 1.4),
                    (74, 0.90, 0.25, 1.5), (40, 0.70, 0.85, 1.8),
                ]
                for bubble in bubbles {
                    let progress = (time * bubble.speed + bubble.offset).truncatingRemainder(dividingBy: 1)
                    let y = 90 - progress * (depth - 4)
                    let fade = min(1, (1 - progress) * 4)
                    let path = Path(ellipseIn: CGRect(
                        x: bubble.x - bubble.radius, y: y - bubble.radius,
                        width: bubble.radius * 2, height: bubble.radius * 2))
                    inner.fill(path, with: .color(.white.opacity(0.75 * fade)))
                }
            }

            // Glass shine.
            inner.fill(
                Path(roundedRect: CGRect(x: 39.5, y: 51, width: 4.5, height: 30), cornerRadius: 2.25),
                with: .color(.white.opacity(0.5)))
        }

        layer.stroke(body, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))
    }

    private static func drawFoam(_ layer: inout GraphicsContext, time: Double, wobble: Double) {
        func bob(_ index: Double) -> Double {
            sin(time * 6.8 + index * 1.7) * 1.1 * wobble
        }
        func blob(_ x: Double, _ y: Double, _ radius: Double) -> Path {
            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }

        let shapes: [Path] = [
            Path(roundedRect: CGRect(x: 31, y: 33, width: 52, height: 13), cornerRadius: 6),
            blob(38, 33 + bob(0), 8.5),
            blob(49, 28 + bob(1), 10.5),
            blob(62, 27 + bob(2), 11),
            blob(74, 31 + bob(3), 9.5),
            // A drip running down the left side of the glass.
            Path(roundedRect: CGRect(x: 30.5, y: 38, width: 9, height: 17 + bob(4) * 1.5), cornerRadius: 4.5),
        ]
        // Ink first, then the white fill on top, so the blobs read as one shape
        // with a single outline.
        for shape in shapes {
            layer.stroke(shape, with: .color(ink), lineWidth: 6.4)
        }
        for shape in shapes {
            layer.fill(shape, with: .color(foam))
        }
    }

    // MARK: Easing

    private static func easeOut(_ x: Double) -> Double {
        1 - pow(1 - x, 3)
    }

    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

/// Holds the mug's live state. Read once per frame by `MugLiveView`.
@MainActor
final class MugModel: ObservableObject {
    @Published var running = false

    private(set) var shownAt = Date()
    private(set) var phase: MugPhase = .listening
    private(set) var phaseStart = Date()
    private(set) var finished = false
    private(set) var drink: Drink = .beer

    /// Raw microphone level, set from outside; `level` eases toward it.
    var targetLevel: Double = 0
    private(set) var level: Double = 0

    func restart() {
        shownAt = Date()
        phase = .listening
        phaseStart = shownAt
        finished = false
        drink = DrinkRotation.next()
        targetLevel = 0
        level = 0
        running = true
    }

    func setPhase(_ newPhase: MugPhase) {
        if newPhase == .leaving {
            finished = phase == .processing
        }
        phase = newPhase
        phaseStart = Date()
    }

    func stop() {
        running = false
    }

    /// Rise quickly, fall slowly, so the mug feels lively rather than jittery.
    func easeLevel() {
        let rate = targetLevel > level ? 0.45 : 0.12
        level += (targetLevel - level) * rate
    }

    func pose(at date: Date) -> MugPose {
        MugPose(
            time: date.timeIntervalSince(shownAt),
            phase: phase,
            phaseTime: date.timeIntervalSince(phaseStart),
            level: level,
            finished: finished,
            drink: drink)
    }
}

struct MugLiveView: View {
    @ObservedObject var model: MugModel

    var body: some View {
        TimelineView(.animation(paused: !model.running)) { timeline in
            MugCanvas(pose: model.pose(at: timeline.date))
        }
    }
}
