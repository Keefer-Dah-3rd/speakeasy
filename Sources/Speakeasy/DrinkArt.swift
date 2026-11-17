import SwiftUI

/// The drink that dances beside the pointer. A different one is picked each
/// time you start dictating (see `DrinkRotation`).
enum Drink: String, CaseIterable {
    case beer
    case blueLagoon
    case margarita
    case pinaColada
    case negroni
    case espressoMartini
    case mojito
    case strawberryDaiquiri
    case oldFashioned
    case matchaLatte
    case tequilaSunrise

    var title: String {
        switch self {
        case .beer: "Beer"
        case .blueLagoon: "Blue Lagoon"
        case .margarita: "Margarita"
        case .pinaColada: "Piña Colada"
        case .negroni: "Negroni"
        case .espressoMartini: "Espresso Martini"
        case .mojito: "Mojito"
        case .strawberryDaiquiri: "Strawberry Daiquiri"
        case .oldFashioned: "Old Fashioned"
        case .matchaLatte: "Matcha Latte"
        case .tequilaSunrise: "Tequila Sunrise"
        }
    }

    /// Width of the ground shadow under the glass.
    var shadowWidth: CGFloat {
        switch self {
        case .beer: 52
        case .negroni, .oldFashioned: 54
        case .matchaLatte: 48
        default: 40
        }
    }
}

/// Deals drinks like a shuffled deck: every drink comes up once before any
/// repeats, and the same drink never shows twice in a row.
@MainActor
enum DrinkRotation {
    private static var deck: [Drink] = []
    private static var last: Drink?

    static func next() -> Drink {
        if deck.isEmpty {
            deck = Drink.allCases.shuffled()
            // The deck is dealt from the end; don't start a new round with the
            // drink that ended the last one.
            if deck.count > 1, deck.last == last {
                deck.swapAt(0, deck.count - 1)
            }
        }
        let drink = deck.removeLast()
        last = drink
        return drink
    }
}

/// Draws every drink except the beer mug, which keeps its own art in MugView.
/// Same style: thick ink outline, flat saturated fills, all on the 140-unit
/// design square with the glass resting on y = 93.
enum DrinkArt {
    private static let ink = MugArt.ink
    private static let glassTint = Color(red: 0.91, green: 0.97, blue: 1.00)

    // MARK: Glasses

    private enum GlassKind {
        case highball, rocks, martini, coupe, goblet, hurricane, latteGlass
    }

    private struct Glass {
        var bowl: Path          // the part that holds the drink
        var stem: Path?         // stemmed glasses only
        var foot: Path?
        var rim: CGFloat        // y of the rim
        var full: CGFloat       // liquid surface when full
        var empty: CGFloat      // liquid surface when drained
        var bottom: CGFloat     // lowest point liquid reaches (above a thick base)
        var left: CGFloat       // inside edges, for bubbles and ice
        var right: CGFloat
        var shine: (CGPoint, CGPoint)
        var handle = false
    }

    private static func glass(_ kind: GlassKind) -> Glass {
        switch kind {
        case .highball:
            return Glass(
                bowl: tumbler(top: 24, topLeft: 39, topRight: 75, bottomLeft: 41, bottomRight: 73),
                rim: 24, full: 31, empty: 84, bottom: 86, left: 42, right: 72,
                shine: (CGPoint(x: 46, y: 36), CGPoint(x: 46, y: 76)))
        case .rocks:
            return Glass(
                bowl: tumbler(top: 40, topLeft: 30, topRight: 84, bottomLeft: 32, bottomRight: 82),
                rim: 40, full: 49, empty: 83, bottom: 85, left: 33, right: 81,
                shine: (CGPoint(x: 37, y: 50), CGPoint(x: 37, y: 76)))
        case .latteGlass:
            return Glass(
                bowl: tumbler(top: 34, topLeft: 35, topRight: 79, bottomLeft: 37, bottomRight: 77),
                rim: 34, full: 40, empty: 84, bottom: 86, left: 38, right: 76,
                shine: (CGPoint(x: 42, y: 46), CGPoint(x: 42, y: 78)),
                handle: true)
        case .martini:
            var bowl = Path()
            bowl.move(to: CGPoint(x: 21, y: 30))
            bowl.addLine(to: CGPoint(x: 93, y: 30))
            bowl.addLine(to: CGPoint(x: 60.5, y: 64))
            bowl.addQuadCurve(to: CGPoint(x: 53.5, y: 64), control: CGPoint(x: 57, y: 68))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, stem: stem(from: 63), foot: foot(),
                rim: 30, full: 35, empty: 63, bottom: 68, left: 40, right: 74,
                shine: (CGPoint(x: 32, y: 36), CGPoint(x: 45, y: 50)))
        case .coupe:
            var bowl = Path()
            bowl.move(to: CGPoint(x: 22, y: 36))
            bowl.addLine(to: CGPoint(x: 92, y: 36))
            bowl.addCurve(to: CGPoint(x: 57, y: 62), control1: CGPoint(x: 92, y: 53), control2: CGPoint(x: 75, y: 62))
            bowl.addCurve(to: CGPoint(x: 22, y: 36), control1: CGPoint(x: 39, y: 62), control2: CGPoint(x: 22, y: 53))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, stem: stem(from: 60), foot: foot(),
                rim: 36, full: 40, empty: 60, bottom: 63, left: 34, right: 80,
                shine: (CGPoint(x: 29, y: 42), CGPoint(x: 36, y: 52)))
        case .goblet:
            var bowl = Path()
            bowl.move(to: CGPoint(x: 31, y: 32))
            bowl.addLine(to: CGPoint(x: 83, y: 32))
            bowl.addCurve(to: CGPoint(x: 57, y: 72), control1: CGPoint(x: 85, y: 57), control2: CGPoint(x: 73, y: 72))
            bowl.addCurve(to: CGPoint(x: 31, y: 32), control1: CGPoint(x: 41, y: 72), control2: CGPoint(x: 29, y: 57))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, stem: stem(from: 70), foot: foot(),
                rim: 32, full: 34, empty: 70, bottom: 73, left: 38, right: 76,
                shine: (CGPoint(x: 37, y: 42), CGPoint(x: 40, y: 58)))
        case .hurricane:
            // Flared lip, pinched waist, round belly: mirrored about x = 57.
            var bowl = Path()
            bowl.move(to: CGPoint(x: 37, y: 20))
            bowl.addLine(to: CGPoint(x: 77, y: 20))
            bowl.addCurve(to: CGPoint(x: 68, y: 46), control1: CGPoint(x: 76, y: 32), control2: CGPoint(x: 68, y: 38))
            bowl.addCurve(to: CGPoint(x: 63, y: 84), control1: CGPoint(x: 68, y: 56), control2: CGPoint(x: 86, y: 76))
            bowl.addQuadCurve(to: CGPoint(x: 51, y: 84), control: CGPoint(x: 57, y: 88))
            bowl.addCurve(to: CGPoint(x: 46, y: 46), control1: CGPoint(x: 28, y: 76), control2: CGPoint(x: 46, y: 56))
            bowl.addCurve(to: CGPoint(x: 37, y: 20), control1: CGPoint(x: 46, y: 38), control2: CGPoint(x: 38, y: 32))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, stem: stem(from: 83), foot: foot(),
                rim: 20, full: 24, empty: 84, bottom: 87, left: 46, right: 68,
                shine: (CGPoint(x: 41, y: 66), CGPoint(x: 44, y: 76)))
        }
    }

    /// A straight-sided glass with a thick base and rounded bottom corners.
    private static func tumbler(
        top: CGFloat, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: topLeft, y: top))
        path.addLine(to: CGPoint(x: topRight, y: top))
        path.addLine(to: CGPoint(x: bottomRight, y: 87))
        path.addQuadCurve(to: CGPoint(x: bottomRight - 6, y: 93), control: CGPoint(x: bottomRight, y: 93))
        path.addLine(to: CGPoint(x: bottomLeft + 6, y: 93))
        path.addQuadCurve(to: CGPoint(x: bottomLeft, y: 87), control: CGPoint(x: bottomLeft, y: 93))
        path.closeSubpath()
        return path
    }

    private static func stem(from top: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: 55, y: top, width: 4, height: 90 - top), cornerRadius: 1)
    }

    private static func foot() -> Path {
        Path(roundedRect: CGRect(x: 39, y: 88.5, width: 36, height: 5), cornerRadius: 2.5)
    }

    // MARK: Recipes

    private struct Recipe {
        var glass: GlassKind
        var liquid: [Gradient.Stop]
        var bubbles = false
        var cubes = false        // a few small ice cubes
        var bigCube = false      // one large cube
        var dome: Color?         // frozen or frothy top above the rim
    }

    private static func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }

    private static func stops(_ colors: Color...) -> [Gradient.Stop] {
        colors.enumerated().map { index, color in
            Gradient.Stop(color: color, location: Double(index) / Double(max(1, colors.count - 1)))
        }
    }

    private static func recipe(_ drink: Drink) -> Recipe {
        switch drink {
        case .beer:
            // Drawn by MugArt; here only so the switch is complete.
            return Recipe(glass: .latteGlass, liquid: stops(MugArt.beerLight, MugArt.beerDeep))
        case .blueLagoon:
            return Recipe(
                glass: .highball,
                liquid: stops(color(0.30, 0.86, 1.00), color(0.02, 0.50, 1.00)),
                bubbles: true, cubes: true)
        case .margarita:
            return Recipe(glass: .coupe, liquid: stops(color(0.84, 0.95, 0.42), color(0.56, 0.82, 0.16)))
        case .pinaColada:
            return Recipe(
                glass: .hurricane,
                liquid: stops(color(1.00, 0.98, 0.90), color(0.99, 0.89, 0.64)),
                dome: color(1.00, 0.98, 0.91))
        case .negroni:
            return Recipe(
                glass: .rocks,
                liquid: stops(color(0.95, 0.36, 0.16), color(0.72, 0.09, 0.07)),
                bigCube: true)
        case .espressoMartini:
            return Recipe(glass: .martini, liquid: stops(color(0.36, 0.20, 0.10), color(0.18, 0.09, 0.04)))
        case .mojito:
            return Recipe(
                glass: .highball,
                liquid: stops(color(0.80, 0.96, 0.55, 0.62), color(0.48, 0.84, 0.32, 0.78)),
                bubbles: true, cubes: true)
        case .strawberryDaiquiri:
            return Recipe(
                glass: .goblet,
                liquid: stops(color(1.00, 0.34, 0.42), color(0.86, 0.10, 0.20)),
                dome: color(1.00, 0.40, 0.48))
        case .oldFashioned:
            return Recipe(
                glass: .rocks,
                liquid: stops(color(0.99, 0.70, 0.28), color(0.82, 0.40, 0.07)),
                bigCube: true)
        case .matchaLatte:
            let milk = color(0.98, 0.92, 0.78)
            return Recipe(
                glass: .latteGlass,
                liquid: [
                    .init(color: milk, location: 0),
                    .init(color: milk, location: 0.36),
                    .init(color: color(0.62, 0.84, 0.30), location: 0.44),
                    .init(color: color(0.42, 0.70, 0.17), location: 1),
                ])
        case .tequilaSunrise:
            return Recipe(
                glass: .highball,
                liquid: [
                    .init(color: color(1.00, 0.80, 0.22), location: 0),
                    .init(color: color(1.00, 0.56, 0.10), location: 0.45),
                    .init(color: color(0.90, 0.13, 0.16), location: 1),
                ])
        }
    }

    // MARK: Drawing

    /// Draws one drink, already placed, leaning and squashed by the caller.
    /// `drain` runs 0...1 while the drink is being knocked back.
    static func draw(
        _ layer: inout GraphicsContext, drink: Drink, time: Double, drain: Double, energy: Double, wobble: Double
    ) {
        let recipe = recipe(drink)
        let glass = glass(recipe.glass)

        // A frothy or frozen top goes first, then the liquid level drops.
        let domeAmount = recipe.dome == nil ? 0 : max(0, 1 - drain * 2.5)
        let sink = recipe.dome == nil ? drain : max(0, drain - 0.25) / 0.75
        let surface = glass.full + (glass.empty - glass.full) * sink

        if glass.handle { drawHandle(&layer) }
        if drink == .mojito { drawStraw(&layer, glass: glass, part: .behind) }

        for part in [glass.stem, glass.foot].compactMap({ $0 }) {
            layer.fill(part, with: .color(glassTint))
            layer.stroke(part, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
        }
        layer.fill(glass.bowl, with: .color(glassTint))

        layer.drawLayer { inner in
            inner.clip(to: glass.bowl)
            inner.clip(to: Path(CGRect(x: 0, y: -40, width: 140, height: glass.bottom + 40)))

            if drink == .mojito {
                drawStraw(&inner, glass: glass, part: .inside)
                drawMuddledMint(&inner)
            }

            if surface < glass.empty + 0.5 {
                let liquid = wave(from: surface, to: 100, left: 10, right: 104, time: time, energy: energy)
                inner.fill(
                    liquid,
                    with: .linearGradient(
                        Gradient(stops: recipe.liquid),
                        startPoint: CGPoint(x: 0, y: surface),
                        endPoint: CGPoint(x: 0, y: glass.bottom)))
            }

            if drink == .espressoMartini {
                drawCrema(&inner, surface: surface, time: time, energy: energy)
            }
            if recipe.cubes { drawCubes(&inner, glass: glass, surface: surface, time: time) }
            if recipe.bigCube { drawBigCube(&inner, glass: glass, surface: surface, time: time) }
            if recipe.bubbles { drawBubbles(&inner, glass: glass, surface: surface, time: time) }

            var shine = Path()
            shine.move(to: glass.shine.0)
            shine.addLine(to: glass.shine.1)
            inner.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }

        layer.stroke(glass.bowl, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))

        if let dome = recipe.dome, domeAmount > 0.04 {
            drawDome(&layer, drink: drink, color: dome, amount: domeAmount, time: time, wobble: wobble)
        }

        switch drink {
        case .blueLagoon:
            drawCitrusWheel(&layer, center: CGPoint(x: 75, y: 25), radius: 10,
                            peel: color(1.00, 0.86, 0.10), flesh: color(1.00, 0.95, 0.45), spin: time)
        case .margarita:
            drawSaltRim(&layer, from: 22, to: 92, y: 36)
            drawCitrusWheel(&layer, center: CGPoint(x: 91, y: 35), radius: 9.5,
                            peel: color(0.30, 0.68, 0.12), flesh: color(0.72, 0.92, 0.38), spin: time)
        case .pinaColada:
            drawUmbrella(&layer, time: time)
            drawPineapple(&layer, at: CGPoint(x: 76, y: 20))
        case .espressoMartini:
            drawCoffeeBeans(&layer, surface: surface, time: time, energy: energy)
        case .mojito:
            drawStraw(&layer, glass: glass, part: .outside)
            drawMintSprig(&layer, time: time)
            drawCitrusWheel(&layer, center: CGPoint(x: 75, y: 26), radius: 9,
                            peel: color(0.30, 0.68, 0.12), flesh: color(0.72, 0.92, 0.38), spin: time)
        case .strawberryDaiquiri:
            drawStrawberry(&layer, at: CGPoint(x: 82, y: 31))
        case .oldFashioned:
            drawOrangePeel(&layer)
        case .matchaLatte:
            drawSteam(&layer, time: time, fade: 1 - drain)
        case .tequilaSunrise:
            drawCitrusWheel(&layer, center: CGPoint(x: 75, y: 25), radius: 10.5,
                            peel: color(1.00, 0.55, 0.05), flesh: color(1.00, 0.72, 0.25), spin: time)
            drawCherry(&layer, at: CGPoint(x: 66, y: 22))
        case .beer, .negroni:
            break
        }
    }

    /// The liquid: a sloshing top edge down to a flat bottom.
    private static func wave(
        from top: CGFloat, to bottom: CGFloat, left: CGFloat, right: CGFloat, time: Double, energy: Double
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: left, y: bottom))
        for x in stride(from: left, through: right, by: 2) {
            let slosh = sin(x * 0.28 + time * 7) * 1.2 * energy
            path.addLine(to: CGPoint(x: x, y: top + slosh))
        }
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.closeSubpath()
        return path
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// A pointed leaf from `base` to `tip`, `width` across at its widest.
    private static func leaf(_ base: CGPoint, _ tip: CGPoint, width: CGFloat) -> Path {
        let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
        let dx = tip.x - base.x, dy = tip.y - base.y
        let length = max(0.01, sqrt(dx * dx + dy * dy))
        let nx = -dy / length * width, ny = dx / length * width
        var path = Path()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        path.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
        path.closeSubpath()
        return path
    }

    private static func outlined(_ layer: inout GraphicsContext, _ path: Path, fill: Color, line: CGFloat = 2.2) {
        layer.fill(path, with: .color(fill))
        layer.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: line, lineJoin: .round))
    }

    // MARK: Parts inside the glass

    private static func drawCubes(_ layer: inout GraphicsContext, glass: Glass, surface: CGFloat, time: Double) {
        // (x, depth below the surface, size, tilt in degrees)
        let cubes: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (50, 2, 13, -12), (63, 9, 12, 14), (52, 22, 12, 6),
        ]
        for (index, cube) in cubes.enumerated() {
            let bob = sin(time * 3 + Double(index) * 2) * 0.8
            let y = min(surface + cube.1 + bob, glass.bottom - cube.2 * 0.55 - CGFloat(index) * 2)
            var ice = layer
            ice.translateBy(x: cube.0, y: y)
            ice.rotate(by: .degrees(cube.3 + bob * 3))
            let rect = Path(roundedRect: CGRect(x: -cube.2 / 2, y: -cube.2 / 2, width: cube.2, height: cube.2), cornerRadius: 2.5)
            ice.fill(rect, with: .color(.white.opacity(0.45)))
            ice.stroke(rect, with: .color(ink.opacity(0.45)), lineWidth: 1.4)
            ice.fill(
                Path(roundedRect: CGRect(x: -cube.2 / 2 + 2, y: -cube.2 / 2 + 2, width: 3, height: 3), cornerRadius: 1.5),
                with: .color(.white.opacity(0.9)))
        }
    }

    private static func drawBigCube(_ layer: inout GraphicsContext, glass: Glass, surface: CGFloat, time: Double) {
        let size: CGFloat = 25
        let bob = sin(time * 2.6) * 0.8
        // Floats with its top a little proud of the drink, then rests on the bottom.
        let top = min(surface - 6 + bob, glass.bottom - size)
        var ice = layer
        ice.translateBy(x: 57, y: top + size / 2)
        ice.rotate(by: .degrees(-6 + bob * 2))
        let rect = Path(roundedRect: CGRect(x: -size / 2, y: -size / 2, width: size, height: size), cornerRadius: 4)
        ice.fill(rect, with: .color(.white.opacity(0.42)))
        ice.stroke(rect, with: .color(ink.opacity(0.55)), lineWidth: 1.6)
        ice.fill(
            Path(roundedRect: CGRect(x: -size / 2 + 3, y: -size / 2 + 3, width: 4, height: 9), cornerRadius: 2),
            with: .color(.white.opacity(0.85)))
    }

    private static func drawBubbles(_ layer: inout GraphicsContext, glass: Glass, surface: CGFloat, time: Double) {
        let depth = glass.bottom - surface
        guard depth > 12 else { return }
        let width = glass.right - glass.left
        let bubbles: [(x: Double, speed: Double, offset: Double, radius: Double)] = [
            (0.15, 0.55, 0.10, 1.4), (0.85, 0.80, 0.45, 1.8), (0.45, 0.65, 0.70, 1.3),
            (0.70, 0.90, 0.25, 1.4), (0.30, 0.75, 0.85, 1.6),
        ]
        for bubble in bubbles {
            let progress = (time * bubble.speed + bubble.offset).truncatingRemainder(dividingBy: 1)
            let y = glass.bottom - 3 - progress * (depth - 5)
            let fade = min(1, (1 - progress) * 4)
            layer.fill(
                circle(CGPoint(x: glass.left + width * bubble.x, y: y), bubble.radius),
                with: .color(.white.opacity(0.8 * fade)))
        }
    }

    private static func drawCrema(_ layer: inout GraphicsContext, surface: CGFloat, time: Double, energy: Double) {
        let crema = wave(from: surface, to: surface + 4.5, left: 10, right: 104, time: time, energy: energy)
        layer.fill(crema, with: .color(color(0.86, 0.64, 0.38)))
    }

    private static func drawMuddledMint(_ layer: inout GraphicsContext) {
        let mint = color(0.16, 0.55, 0.22)
        layer.fill(leaf(CGPoint(x: 46, y: 82), CGPoint(x: 58, y: 76), width: 4), with: .color(mint))
        layer.fill(leaf(CGPoint(x: 69, y: 84), CGPoint(x: 60, y: 73), width: 3.6), with: .color(mint))
        layer.fill(leaf(CGPoint(x: 48, y: 64), CGPoint(x: 56, y: 56), width: 3.2), with: .color(mint.opacity(0.85)))
        layer.fill(leaf(CGPoint(x: 70, y: 62), CGPoint(x: 64, y: 52), width: 3), with: .color(mint.opacity(0.85)))
    }

    // MARK: Parts on and above the glass

    private static func drawHandle(_ layer: inout GraphicsContext) {
        var handle = Path()
        handle.move(to: CGPoint(x: 77, y: 46))
        handle.addCurve(to: CGPoint(x: 77, y: 78), control1: CGPoint(x: 99, y: 43), control2: CGPoint(x: 99, y: 81))
        layer.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 10.5, lineCap: .round))
        layer.stroke(handle, with: .color(glassTint), style: StrokeStyle(lineWidth: 4.8, lineCap: .round))
    }

    private static func drawDome(
        _ layer: inout GraphicsContext, drink: Drink, color fill: Color, amount: Double, time: Double, wobble: Double
    ) {
        let rim: CGFloat
        let blobs: [(CGFloat, CGFloat, CGFloat)]
        let base: CGRect
        if drink == .pinaColada {
            rim = 20
            base = CGRect(x: 36, y: 16.5, width: 42, height: 7)
            blobs = [(43, 18, 7), (52, 13, 9), (63, 13, 8.5), (72, 17, 6.5)]
        } else {
            rim = 32
            base = CGRect(x: 30, y: 28, width: 54, height: 8)
            blobs = [(39, 29, 8), (50, 23, 10), (63, 22, 10.5), (75, 27, 8.5)]
        }
        let a = CGFloat(amount)
        var shapes = [Path(roundedRect: base, cornerRadius: 3.5)]
        for (index, blob) in blobs.enumerated() {
            let bob = CGFloat(sin(time * 6.8 + Double(index) * 1.7) * 1.1 * wobble)
            let y = rim - (rim - blob.1) * a + bob
            shapes.append(circle(CGPoint(x: blob.0, y: y), blob.2 * (0.35 + 0.65 * a)))
        }
        for shape in shapes { layer.stroke(shape, with: .color(ink), lineWidth: 6) }
        for shape in shapes { layer.fill(shape, with: .color(fill)) }

        // Icy specks on the frozen daiquiri, a little sheen on the colada.
        if drink == .strawberryDaiquiri {
            let specks: [(CGFloat, CGFloat)] = [(44, 26), (55, 21), (66, 24), (60, 29), (74, 28), (48, 31), (38, 30)]
            for speck in specks {
                let y = rim - (rim - speck.1) * a
                layer.fill(circle(CGPoint(x: speck.0, y: y), 1.1), with: .color(.white.opacity(0.75)))
            }
        } else {
            layer.fill(circle(CGPoint(x: 49, y: rim - (rim - 11) * a), 2.2), with: .color(.white))
        }
    }

    private static func drawCitrusWheel(
        _ layer: inout GraphicsContext, center: CGPoint, radius: CGFloat, peel: Color, flesh: Color, spin: Double
    ) {
        layer.fill(circle(center, radius + 1.6), with: .color(ink))
        layer.fill(circle(center, radius), with: .color(peel))
        layer.fill(circle(center, radius - 1.8), with: .color(.white.opacity(0.95)))
        layer.fill(circle(center, radius - 2.8), with: .color(flesh))
        var segments = Path()
        let turn = sin(spin * 1.3) * 0.25
        for index in 0..<8 {
            let angle = Double(index) / 8 * 2 * .pi + turn
            segments.move(to: center)
            segments.addLine(to: CGPoint(
                x: center.x + CGFloat(cos(angle)) * (radius - 3),
                y: center.y + CGFloat(sin(angle)) * (radius - 3)))
        }
        layer.stroke(segments, with: .color(.white.opacity(0.9)), lineWidth: 1.1)
        layer.fill(circle(center, 1.4), with: .color(.white))
    }

    private static func drawSaltRim(_ layer: inout GraphicsContext, from left: CGFloat, to right: CGFloat, y: CGFloat) {
        var band = Path()
        band.move(to: CGPoint(x: left, y: y))
        band.addLine(to: CGPoint(x: right, y: y))
        layer.stroke(band, with: .color(ink), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        layer.stroke(band, with: .color(.white), style: StrokeStyle(lineWidth: 3.3, lineCap: .round))
        // Crystals poking up along the rim.
        for index in 0...11 {
            let x = left + 3 + (right - left - 6) * CGFloat(index) / 11
            let lift: CGFloat = index % 2 == 0 ? 2.6 : 1.8
            let crystal = Path(roundedRect: CGRect(x: x - 1.3, y: y - lift - 1.3, width: 2.6, height: 2.6), cornerRadius: 0.6)
            layer.fill(crystal, with: .color(.white))
            layer.stroke(crystal, with: .color(ink), lineWidth: 0.8)
        }
    }

    private enum StrawPart { case behind, inside, outside }

    /// The straw is drawn in pieces so the bit inside the glass sits behind
    /// the drink and the bit above the rim sits in front.
    private static func drawStraw(_ layer: inout GraphicsContext, glass: Glass, part: StrawPart) {
        var straw = Path()
        straw.move(to: CGPoint(x: 61, y: 84))
        straw.addLine(to: CGPoint(x: 70, y: glass.rim))
        straw.addLine(to: CGPoint(x: 76, y: glass.rim - 14))
        straw.addLine(to: CGPoint(x: 86, y: glass.rim - 17))

        var piece = layer
        switch part {
        case .behind:
            return
        case .inside:
            break
        case .outside:
            piece.clip(to: Path(CGRect(x: 0, y: -40, width: 140, height: glass.rim + 40 - 1.5)))
        }
        piece.stroke(straw, with: .color(ink), style: StrokeStyle(lineWidth: 6.4, lineCap: .round, lineJoin: .round))
        piece.stroke(straw, with: .color(color(1.00, 0.30, 0.38)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private static func drawMintSprig(_ layer: inout GraphicsContext, time: Double) {
        let sway = CGFloat(sin(time * 4.4) * 1.2)
        let mint = color(0.22, 0.70, 0.28)
        let leaves = [
            leaf(CGPoint(x: 50, y: 25), CGPoint(x: 40 + sway, y: 10), width: 5),
            leaf(CGPoint(x: 51, y: 25), CGPoint(x: 52 + sway, y: 7), width: 5),
            leaf(CGPoint(x: 52, y: 26), CGPoint(x: 63 + sway, y: 13), width: 4.6),
        ]
        for shape in leaves { outlined(&layer, shape, fill: mint) }
        var veins = Path()
        veins.move(to: CGPoint(x: 50, y: 25)); veins.addLine(to: CGPoint(x: 43 + sway, y: 14))
        veins.move(to: CGPoint(x: 51, y: 25)); veins.addLine(to: CGPoint(x: 51.6 + sway, y: 11))
        veins.move(to: CGPoint(x: 52, y: 26)); veins.addLine(to: CGPoint(x: 60 + sway, y: 16))
        layer.stroke(veins, with: .color(color(0.12, 0.45, 0.16)), lineWidth: 1)
    }

    private static func drawCherry(_ layer: inout GraphicsContext, at point: CGPoint) {
        var stalk = Path()
        stalk.move(to: CGPoint(x: point.x, y: point.y - 3))
        stalk.addQuadCurve(to: CGPoint(x: point.x + 6, y: point.y - 13), control: CGPoint(x: point.x, y: point.y - 11))
        layer.stroke(stalk, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        outlined(&layer, circle(point, 4.6), fill: color(0.86, 0.04, 0.14))
        layer.fill(circle(CGPoint(x: point.x - 1.5, y: point.y - 1.6), 1.2), with: .color(.white.opacity(0.9)))
    }

    private static func drawStrawberry(_ layer: inout GraphicsContext, at point: CGPoint) {
        var berry = layer
        berry.translateBy(x: point.x, y: point.y)
        berry.rotate(by: .degrees(18))
        var body = Path()
        body.move(to: CGPoint(x: 0, y: -6))
        body.addCurve(to: CGPoint(x: 0, y: 11), control1: CGPoint(x: 13, y: -9), control2: CGPoint(x: 9, y: 7))
        body.addCurve(to: CGPoint(x: 0, y: -6), control1: CGPoint(x: -9, y: 7), control2: CGPoint(x: -13, y: -9))
        body.closeSubpath()
        outlined(&berry, body, fill: color(0.93, 0.10, 0.20))
        let seeds: [(CGFloat, CGFloat)] = [(-4, -1), (0, -2), (4, -1), (-2, 3), (2, 3), (0, 7)]
        for seed in seeds {
            berry.fill(Path(ellipseIn: CGRect(x: seed.0 - 0.7, y: seed.1 - 1, width: 1.4, height: 2)),
                       with: .color(color(1.00, 0.88, 0.35)))
        }
        let green = color(0.25, 0.66, 0.22)
        for tip in [CGPoint(x: -7, y: -10), CGPoint(x: 0, y: -12), CGPoint(x: 7, y: -10)] {
            outlined(&berry, leaf(CGPoint(x: 0, y: -6), tip, width: 2.4), fill: green, line: 1.4)
        }
    }

    private static func drawPineapple(_ layer: inout GraphicsContext, at point: CGPoint) {
        var wedge = layer
        wedge.translateBy(x: point.x, y: point.y)
        wedge.rotate(by: .degrees(-8))
        let green = color(0.25, 0.66, 0.22)
        for tip in [CGPoint(x: 3, y: -17), CGPoint(x: 9, y: -16), CGPoint(x: 14, y: -12)] {
            outlined(&wedge, leaf(CGPoint(x: 6, y: -6), tip, width: 2.6), fill: green, line: 1.6)
        }
        var flesh = Path()
        flesh.move(to: CGPoint(x: -2, y: 2))
        flesh.addLine(to: CGPoint(x: 6, y: -8))
        flesh.addQuadCurve(to: CGPoint(x: 14, y: 12), control: CGPoint(x: 19, y: -1))
        flesh.closeSubpath()
        outlined(&wedge, flesh, fill: color(1.00, 0.86, 0.26))
        var rind = Path()
        rind.move(to: CGPoint(x: 6.5, y: -7.2))
        rind.addQuadCurve(to: CGPoint(x: 13.6, y: 11), control: CGPoint(x: 17.6, y: -0.6))
        wedge.stroke(rind, with: .color(color(0.80, 0.52, 0.12)), lineWidth: 2.6)
    }

    private static func drawUmbrella(_ layer: inout GraphicsContext, time: Double) {
        let twirl = sin(time * 3.4) * 4
        var umbrella = layer
        umbrella.translateBy(x: 49, y: 16)
        umbrella.rotate(by: .degrees(-24 + twirl))

        var stick = Path()
        stick.move(to: CGPoint(x: 0, y: 4))
        stick.addLine(to: CGPoint(x: 0, y: -20))
        umbrella.stroke(stick, with: .color(ink), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        umbrella.stroke(stick, with: .color(color(0.95, 0.82, 0.55)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        var canopy = Path()
        canopy.move(to: CGPoint(x: -13, y: -19))
        canopy.addQuadCurve(to: CGPoint(x: 13, y: -19), control: CGPoint(x: 0, y: -36))
        for index in 0..<3 {
            let x = 13 - CGFloat(index) * 26 / 3
            canopy.addQuadCurve(to: CGPoint(x: x - 26 / 3, y: -19), control: CGPoint(x: x - 13 / 3, y: -22.5))
        }
        canopy.closeSubpath()
        outlined(&umbrella, canopy, fill: color(1.00, 0.38, 0.60))
        var ribs = Path()
        for x in [-13.0 / 3, 13.0 / 3] {
            ribs.move(to: CGPoint(x: 0, y: -27.5))
            ribs.addLine(to: CGPoint(x: CGFloat(x), y: -20))
        }
        umbrella.stroke(ribs, with: .color(color(0.80, 0.16, 0.40)), lineWidth: 1.2)
        umbrella.fill(circle(CGPoint(x: 0, y: -28), 1.6), with: .color(ink))
    }

    private static func drawCoffeeBeans(_ layer: inout GraphicsContext, surface: CGFloat, time: Double, energy: Double) {
        let beans: [(CGFloat, Double)] = [(49, -25), (57, 8), (65, 30)]
        for (index, bean) in beans.enumerated() {
            let slosh = CGFloat(sin(bean.0 * 0.28 + time * 7) * 1.2 * energy)
            var b = layer
            b.translateBy(x: bean.0, y: surface + slosh - 1.2 - (index == 1 ? 0.8 : 0))
            b.rotate(by: .degrees(bean.1))
            let shell = Path(ellipseIn: CGRect(x: -3.4, y: -2.4, width: 6.8, height: 4.8))
            outlined(&b, shell, fill: color(0.32, 0.17, 0.07), line: 1.3)
            var crease = Path()
            crease.move(to: CGPoint(x: -2.4, y: 0.4))
            crease.addQuadCurve(to: CGPoint(x: 2.4, y: -0.4), control: CGPoint(x: 0, y: -1.2))
            b.stroke(crease, with: .color(color(0.62, 0.42, 0.24)), lineWidth: 0.9)
        }
    }

    private static func drawOrangePeel(_ layer: inout GraphicsContext) {
        // A twist hooked over the rim and curling down the outside.
        var peel = Path()
        peel.move(to: CGPoint(x: 72, y: 43))
        peel.addQuadCurve(to: CGPoint(x: 84, y: 39), control: CGPoint(x: 78, y: 35))
        peel.addCurve(to: CGPoint(x: 86, y: 64), control1: CGPoint(x: 91, y: 48), control2: CGPoint(x: 80, y: 56))
        peel.addQuadCurve(to: CGPoint(x: 92, y: 74), control: CGPoint(x: 92, y: 68))
        layer.stroke(peel, with: .color(ink), style: StrokeStyle(lineWidth: 7.6, lineCap: .round, lineJoin: .round))
        layer.stroke(peel, with: .color(color(1.00, 0.56, 0.08)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
    }

    private static func drawSteam(_ layer: inout GraphicsContext, time: Double, fade: Double) {
        guard fade > 0.05 else { return }
        for (index, x) in [50.0, 63.0].enumerated() {
            let phase = time * 1.6 + Double(index) * 0.5
            let rise = phase.truncatingRemainder(dividingBy: 1)
            var wisp = Path()
            for step in 0...10 {
                let t = Double(step) / 10
                let y = 29 - t * 16 - rise * 4
                let wiggle = sin(t * 2 * .pi + phase * 2 * .pi) * 2.6
                let point = CGPoint(x: x + wiggle, y: y)
                if step == 0 { wisp.move(to: point) } else { wisp.addLine(to: point) }
            }
            let alpha = 0.45 * fade * (1 - rise * 0.6)
            layer.stroke(wisp, with: .color(ink.opacity(alpha)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
}
