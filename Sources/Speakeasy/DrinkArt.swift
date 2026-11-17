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
    case dragonsBlood
    case fairyDustElixir
    case mermaidsTears
    case witchsBrew
    case phoenixFlame
    case moonlightNectar
    case goblinGrog
    case unicornTears
    case voidEssence
    case frozenFrostbite

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
        case .dragonsBlood: "Dragon's Blood"
        case .fairyDustElixir: "Fairy Dust Elixir"
        case .mermaidsTears: "Mermaid's Tears"
        case .witchsBrew: "Witch's Brew"
        case .phoenixFlame: "Phoenix Flame"
        case .moonlightNectar: "Moonlight Nectar"
        case .goblinGrog: "Goblin Grog"
        case .unicornTears: "Unicorn Tears"
        case .voidEssence: "Void Essence"
        case .frozenFrostbite: "Frozen Frostbite"
        }
    }

    /// Width of the ground shadow under the glass.
    var shadowWidth: CGFloat {
        switch self {
        case .beer: 52
        case .negroni, .oldFashioned, .frozenFrostbite: 54
        case .matchaLatte, .goblinGrog: 48
        case .fairyDustElixir: 44
        case .witchsBrew, .voidEssence: 36
        case .mermaidsTears: 38
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
        case roundFlask, potionBottle, teardrop
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
        var neck: (CGFloat, CGFloat)?  // bottles: the neck's left and right edges
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
        case .roundFlask:
            // A narrow neck on a round bulb, like a chemistry flask.
            let center = CGPoint(x: 57, y: 71)
            let radius: CGFloat = 22
            let start = atan2(-sqrt(radius * radius - 49), 7.0)
            var bowl = Path()
            bowl.move(to: CGPoint(x: 50, y: 26))
            bowl.addLine(to: CGPoint(x: 64, y: 26))
            for step in 0...80 {
                let angle = start + (Double.pi + 2 * -start) * Double(step) / 80
                bowl.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
            }
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, rim: 26, full: 44, empty: 89, bottom: 93, left: 40, right: 74,
                shine: (CGPoint(x: 41, y: 64), CGPoint(x: 42, y: 77)), neck: (50, 64))
        case .potionBottle:
            var bowl = Path()
            bowl.move(to: CGPoint(x: 51, y: 22))
            bowl.addLine(to: CGPoint(x: 63, y: 22))
            bowl.addLine(to: CGPoint(x: 63, y: 38))
            bowl.addQuadCurve(to: CGPoint(x: 78, y: 52), control: CGPoint(x: 78, y: 38))
            bowl.addLine(to: CGPoint(x: 78, y: 87))
            bowl.addQuadCurve(to: CGPoint(x: 72, y: 93), control: CGPoint(x: 78, y: 93))
            bowl.addLine(to: CGPoint(x: 42, y: 93))
            bowl.addQuadCurve(to: CGPoint(x: 36, y: 87), control: CGPoint(x: 36, y: 93))
            bowl.addLine(to: CGPoint(x: 36, y: 52))
            bowl.addQuadCurve(to: CGPoint(x: 51, y: 38), control: CGPoint(x: 36, y: 38))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, rim: 22, full: 44, empty: 88, bottom: 90, left: 38, right: 76,
                shine: (CGPoint(x: 41, y: 58), CGPoint(x: 41, y: 82)), neck: (51, 63))
        case .teardrop:
            var bowl = Path()
            bowl.move(to: CGPoint(x: 52, y: 22))
            bowl.addLine(to: CGPoint(x: 62, y: 22))
            bowl.addLine(to: CGPoint(x: 62, y: 32))
            bowl.addCurve(to: CGPoint(x: 80, y: 72), control1: CGPoint(x: 62, y: 44), control2: CGPoint(x: 80, y: 54))
            bowl.addCurve(to: CGPoint(x: 57, y: 93), control1: CGPoint(x: 80, y: 86), control2: CGPoint(x: 70, y: 93))
            bowl.addCurve(to: CGPoint(x: 34, y: 72), control1: CGPoint(x: 44, y: 93), control2: CGPoint(x: 34, y: 86))
            bowl.addCurve(to: CGPoint(x: 52, y: 32), control1: CGPoint(x: 34, y: 54), control2: CGPoint(x: 52, y: 44))
            bowl.closeSubpath()
            return Glass(
                bowl: bowl, rim: 22, full: 40, empty: 89, bottom: 92, left: 40, right: 74,
                shine: (CGPoint(x: 39, y: 66), CGPoint(x: 40, y: 80)), neck: (52, 62))
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
        var cork = false         // bottles: stoppered
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
        case .dragonsBlood:
            return Recipe(glass: .goblet, liquid: stops(color(0.98, 0.12, 0.20), color(0.52, 0.00, 0.06)))
        case .fairyDustElixir:
            return Recipe(
                glass: .potionBottle,
                liquid: stops(color(0.98, 0.62, 0.95), color(0.70, 0.36, 0.98), color(0.42, 0.30, 0.92)),
                cork: true)
        case .mermaidsTears:
            return Recipe(
                glass: .teardrop,
                liquid: stops(color(0.25, 0.85, 0.95), color(0.02, 0.48, 0.86), color(0.02, 0.28, 0.66)),
                bubbles: true, cork: true)
        case .witchsBrew:
            return Recipe(
                glass: .roundFlask,
                liquid: stops(color(0.72, 1.00, 0.20), color(0.30, 0.78, 0.08)),
                bubbles: true)
        case .phoenixFlame:
            return Recipe(
                glass: .highball,
                liquid: [
                    .init(color: color(1.00, 0.90, 0.25), location: 0),
                    .init(color: color(1.00, 0.84, 0.18), location: 0.32),
                    .init(color: color(1.00, 0.58, 0.08), location: 0.38),
                    .init(color: color(1.00, 0.50, 0.06), location: 0.64),
                    .init(color: color(0.94, 0.26, 0.06), location: 0.70),
                    .init(color: color(0.84, 0.16, 0.04), location: 1),
                ])
        case .moonlightNectar:
            return Recipe(glass: .coupe, liquid: stops(color(0.88, 0.92, 1.00), color(0.62, 0.72, 0.94)))
        case .goblinGrog:
            return Recipe(glass: .latteGlass, liquid: stops(color(0.52, 0.58, 0.20), color(0.26, 0.30, 0.08)))
        case .unicornTears:
            return Recipe(glass: .hurricane, liquid: stops(color(1.00, 0.76, 0.88), color(0.80, 0.70, 1.00)))
        case .voidEssence:
            return Recipe(
                glass: .roundFlask,
                liquid: stops(color(0.06, 0.03, 0.10), color(0.02, 0.01, 0.04)),
                cork: true)
        case .frozenFrostbite:
            return Recipe(glass: .rocks, liquid: stops(color(0.72, 0.98, 1.00), color(0.20, 0.78, 0.94)))
        }
    }

    // MARK: Drawing

    /// Draws one drink, already placed, leaning and squashed by the caller.
    /// `drain` runs 0...1 while the drink is being knocked back.
    static func draw(
        _ layer: inout GraphicsContext, drink: Drink, time: Double, drain: Double, energy: Double, wobble: Double,
        tilt: CGFloat = 0, listening: Bool = true
    ) {
        let recipe = recipe(drink)
        let glass = glass(recipe.glass)

        // A frothy or frozen top goes first, then the liquid level drops.
        let domeAmount = recipe.dome == nil ? 0 : max(0, 1 - drain * 2.5)
        let sink = recipe.dome == nil ? drain : max(0, drain - 0.25) / 0.75
        let surface = glass.full + (glass.empty - glass.full) * sink
        let move = specialMove(time: time, listening: listening) ?? -1
        let event: Double? = aura(drink) != nil && move >= 0 ? move : nil

        drawMagicBehind(&layer, drink: drink, glass: glass, drain: drain, time: time, event: event)
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

            let liquid = wave(from: surface, to: 100, left: 10, right: 104, time: time, energy: energy, tilt: tilt)
            if surface < glass.empty + 0.5 {
                inner.fill(
                    liquid,
                    with: .linearGradient(
                        Gradient(stops: recipe.liquid),
                        startPoint: CGPoint(x: 0, y: surface),
                        endPoint: CGPoint(x: 0, y: glass.bottom)))
            }

            if drink == .espressoMartini {
                drawCrema(&inner, surface: surface, time: time, energy: energy, tilt: tilt)
            }
            if recipe.cubes { drawCubes(&inner, glass: glass, surface: surface, time: time) }
            if recipe.bigCube { drawBigCube(&inner, glass: glass, surface: surface, time: time) }
            if recipe.bubbles { drawBubbles(&inner, glass: glass, surface: surface, time: time) }
            drawMagicInside(&inner, drink: drink, glass: glass, liquid: liquid, surface: surface,
                            level: 1 - sink, time: time)
            drawEnchantInside(&inner, drink: drink, glass: glass, liquid: liquid, surface: surface, time: time)

            var shine = Path()
            shine.move(to: glass.shine.0)
            shine.addLine(to: glass.shine.1)
            inner.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }

        layer.stroke(glass.bowl, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))

        if let neck = glass.neck {
            let pop = drink == .fairyDustElixir ? event.map { bump(min(1, $0 * 1.4)) } ?? 0 : 0
            drawBottleTop(&layer, neck: neck, rim: glass.rim, cork: recipe.cork,
                          lift: CGFloat(pop) * 16, spin: drink == .fairyDustElixir ? (event ?? 0) * 540 : 0)
        }
        drawMagicOutside(&layer, drink: drink, glass: glass, surface: surface, drain: drain, time: time, event: event)
        drawEnchantOutside(&layer, drink: drink, glass: glass, surface: surface, drain: drain, time: time)
        if let event {
            drawSpecialMove(&layer, drink: drink, glass: glass, surface: surface, move: event, time: time)
        }

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
            drawCoffeeBeans(&layer, surface: surface, time: time, energy: energy, tilt: tilt)
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
        default:
            break
        }
    }

    /// The liquid: a sloshing top edge down to a flat bottom.
    private static func wave(
        from top: CGFloat, to bottom: CGFloat, left: CGFloat, right: CGFloat, time: Double, energy: Double,
        tilt: CGFloat = 0
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: left, y: bottom))
        for x in stride(from: left, through: right, by: 2) {
            let slosh = sin(x * 0.28 + time * 7) * 1.2 * energy
            path.addLine(to: CGPoint(x: x, y: top + slosh + (x - 57) * tilt))
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

    private static func drawCrema(_ layer: inout GraphicsContext, surface: CGFloat, time: Double, energy: Double, tilt: CGFloat) {
        let crema = wave(from: surface, to: surface + 4.5, left: 10, right: 104, time: time, energy: energy, tilt: tilt)
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

    private static func drawCoffeeBeans(
        _ layer: inout GraphicsContext, surface: CGFloat, time: Double, energy: Double, tilt: CGFloat
    ) {
        let beans: [(CGFloat, Double)] = [(49, -25), (57, 8), (65, 30)]
        for (index, bean) in beans.enumerated() {
            let slosh = CGFloat(sin(bean.0 * 0.28 + time * 7) * 1.2 * energy)
            var b = layer
            b.translateBy(x: bean.0, y: surface + slosh + (bean.0 - 57) * tilt - 1.2 - (index == 1 ? 0.8 : 0))
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

    // MARK: Fantasy drinks

    /// A four-pointed twinkle.
    private static func star4(_ center: CGPoint, _ radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) / 8 * 2 * .pi - .pi / 2
            let r = index % 2 == 0 ? radius : radius * 0.3
            let point = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// 0...1, pulsing; each `seed` is out of step with the others.
    private static func twinkle(_ time: Double, _ seed: Double, speed: Double = 4) -> CGFloat {
        CGFloat(max(0, sin(time * speed + seed * 1.9)))
    }

    /// Keeps something floating in the drink: it rides at `y` while the drink
    /// is deep enough, and settles on the bottom as the drink runs out.
    private static func afloat(_ y: CGFloat, surface: CGFloat, glass: Glass, size: CGFloat) -> CGFloat {
        min(max(y, surface + size + 1), glass.bottom - size - 1)
    }

    private static func drawBottleTop(
        _ layer: inout GraphicsContext, neck: (CGFloat, CGFloat), rim: CGFloat, cork: Bool,
        lift: CGFloat = 0, spin: Double = 0
    ) {
        if cork {
            // The cork can pop up and spin.
            var corked = layer
            let middle = (neck.0 + neck.1) / 2
            corked.translateBy(x: middle, y: rim - 4 - lift)
            corked.rotate(by: .degrees(spin))
            corked.translateBy(x: -middle, y: -(rim - 4))
            let stopper = Path(roundedRect: CGRect(x: neck.0 + 1, y: rim - 10, width: neck.1 - neck.0 - 2, height: 13), cornerRadius: 2.5)
            outlined(&corked, stopper, fill: color(0.80, 0.58, 0.34), line: 2.4)
            for dot in [CGPoint(x: neck.0 + 4, y: rim - 6), CGPoint(x: neck.1 - 4.5, y: rim - 3), CGPoint(x: (neck.0 + neck.1) / 2, y: rim - 7.5)] {
                corked.fill(circle(dot, 0.9), with: .color(color(0.55, 0.36, 0.18)))
            }
        }
        // The lip around the mouth of the bottle.
        let lip = Path(roundedRect: CGRect(x: neck.0 - 2.5, y: rim - 1.5, width: neck.1 - neck.0 + 5, height: 4.5), cornerRadius: 2.2)
        outlined(&layer, lip, fill: glassTint, line: 2.4)
    }

    /// Effects inside the glass, drawn over the liquid and clipped to the glass.
    private static func drawMagicInside(
        _ inner: inout GraphicsContext, drink: Drink, glass: Glass, liquid: Path, surface: CGFloat, level: Double, time: Double
    ) {
        switch drink {
        case .dragonsBlood:
            // A glowing heart in the crimson.
            let pulse = 0.75 + 0.25 * sin(time * 3)
            inner.fill(liquid, with: .radialGradient(
                Gradient(colors: [color(1.00, 0.55, 0.35, 0.85 * pulse), color(1.00, 0.20, 0.20, 0)]),
                center: CGPoint(x: 57, y: 52), startRadius: 0, endRadius: 20))

        case .fairyDustElixir:
            shimmer(&inner, liquid: liquid, time: time, colors: [
                color(1, 1, 1, 0), color(0.60, 1.00, 0.95, 0.35), color(1.00, 0.85, 1.00, 0.5), color(1, 1, 1, 0),
            ])
            let sparks: [(CGFloat, CGFloat, CGFloat)] = [
                (44, 60, 3.2), (66, 56, 2.6), (55, 70, 3.6), (70, 78, 2.8), (46, 84, 2.4), (60, 86, 3), (52, 48, 2.2),
            ]
            for (index, spark) in sparks.enumerated() {
                let drift = CGFloat((time * 0.25 + Double(index) * 0.13).truncatingRemainder(dividingBy: 1)) * 6
                let y = spark.1 - drift
                guard y > surface + 2 else { continue }
                let size = spark.2 * (0.3 + 0.7 * twinkle(time, Double(index), speed: 5))
                inner.fill(star4(CGPoint(x: spark.0, y: y), size), with: .color(index % 2 == 0 ? .white : color(1.00, 0.92, 0.50)))
            }

        case .mermaidsTears:
            // Light rippling through the water.
            for index in 0..<3 {
                var ripple = Path()
                let base = 54 + CGFloat(index) * 11
                for x in stride(from: 36.0, through: 78.0, by: 2.0) {
                    let y = base + CGFloat(sin(x * 0.35 + time * 3 + Double(index) * 2)) * 1.6
                    if x == 36 { ripple.move(to: CGPoint(x: x, y: y)) } else { ripple.addLine(to: CGPoint(x: x, y: y)) }
                }
                if base > surface + 3 {
                    inner.stroke(ripple, with: .color(.white.opacity(0.22)), lineWidth: 1.4)
                }
            }
            let pearls: [(CGFloat, CGFloat, CGFloat)] = [(48, 62, 2.8), (64, 70, 3.2), (55, 80, 3.4), (69, 84, 2.6), (44, 78, 2.6)]
            for (index, pearl) in pearls.enumerated() {
                let bob = CGFloat(sin(time * 1.8 + Double(index) * 1.3)) * 1.5
                let center = CGPoint(x: pearl.0, y: afloat(pearl.1 + bob, surface: surface, glass: glass, size: pearl.2))
                inner.fill(circle(center, pearl.2), with: .radialGradient(
                    Gradient(colors: [.white, color(0.96, 0.90, 0.96), color(0.78, 0.76, 0.90)]),
                    center: CGPoint(x: center.x - 1, y: center.y - 1), startRadius: 0, endRadius: pearl.2 * 1.2))
                inner.stroke(circle(center, pearl.2), with: .color(ink.opacity(0.5)), lineWidth: 0.8)
                inner.fill(circle(CGPoint(x: center.x - pearl.2 * 0.35, y: center.y - pearl.2 * 0.35), pearl.2 * 0.3), with: .color(.white))
            }

        case .witchsBrew:
            inner.fill(liquid, with: .radialGradient(
                Gradient(colors: [color(0.90, 1.00, 0.40, 0.55), color(0.70, 1.00, 0.20, 0)]),
                center: CGPoint(x: 57, y: 72), startRadius: 0, endRadius: 20))
            let eyes: [(CGFloat, CGFloat, Color)] = [
                (48, 64, color(0.85, 0.12, 0.10)), (65, 70, color(0.95, 0.70, 0.05)), (55, 82, color(0.40, 0.20, 0.70)),
            ]
            for (index, eye) in eyes.enumerated() {
                let bob = CGFloat(sin(time * 2.2 + Double(index) * 2.1)) * 1.6
                let center = CGPoint(x: eye.0, y: afloat(eye.1 + bob, surface: surface, glass: glass, size: 4.4))
                drawEyeball(&inner, at: center, iris: eye.2, look: time * 1.4 + Double(index) * 2)
            }

        case .moonlightNectar:
            let stars: [(CGFloat, CGFloat, CGFloat)] = [(36, 44, 3), (47, 50, 3.8), (58, 44, 3.2), (68, 51, 3.6), (78, 44, 2.8), (57, 56, 2.4)]
            for (index, star) in stars.enumerated() {
                guard star.1 > surface + 1.5 else { continue }
                let size = star.2 * (0.55 + 0.45 * twinkle(time, Double(index), speed: 3.2))
                let center = CGPoint(x: star.0, y: star.1)
                var glow = inner
                glow.addFilter(.blur(radius: 2.2))
                glow.fill(circle(center, size * 1.3), with: .color(color(1.00, 0.98, 0.75, 0.9)))
                inner.fill(star4(center, size * 1.25), with: .color(color(1.00, 0.97, 0.70)))
                inner.fill(circle(center, size * 0.3), with: .color(.white))
            }

        case .goblinGrog:
            let specks: [(CGFloat, CGFloat)] = [(44, 60), (52, 72), (66, 64), (70, 80), (48, 84), (60, 54), (58, 86), (73, 56)]
            for (index, speck) in specks.enumerated() where speck.1 > surface + 2 {
                let wobble = CGFloat(sin(time * 1.5 + Double(index))) * 1.2
                inner.fill(circle(CGPoint(x: speck.0 + wobble, y: speck.1), 1.1), with: .color(color(0.20, 0.16, 0.05, 0.7)))
            }
            // Herbs bobbing at the surface.
            let herbs: [(CGFloat, Double, Color)] = [
                (45, -20, color(0.20, 0.42, 0.12)), (58, 30, color(0.36, 0.52, 0.14)), (69, -50, color(0.24, 0.36, 0.10)),
            ]
            for (index, herb) in herbs.enumerated() {
                let bob = CGFloat(sin(time * 2.4 + Double(index) * 1.7))
                let y = afloat(surface + 3 + bob, surface: surface, glass: glass, size: 2)
                var sprig = inner
                sprig.translateBy(x: herb.0, y: y)
                sprig.rotate(by: .degrees(herb.1 + Double(bob) * 8))
                outlined(&sprig, leaf(CGPoint(x: -5, y: 0), CGPoint(x: 5, y: 0), width: 3), fill: herb.2, line: 1.2)
            }
            var twig = Path()
            let twigY = afloat(surface + 6, surface: surface, glass: glass, size: 2)
            twig.move(to: CGPoint(x: 50, y: twigY + 2))
            twig.addLine(to: CGPoint(x: 62, y: twigY - 1))
            twig.move(to: CGPoint(x: 57, y: twigY))
            twig.addLine(to: CGPoint(x: 60, y: twigY + 3))
            inner.stroke(twig, with: .color(color(0.40, 0.25, 0.10)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        case .unicornTears:
            shimmer(&inner, liquid: liquid, time: time, colors: [
                color(1, 1, 1, 0), color(1.00, 0.45, 0.45, 0.45), color(1.00, 0.85, 0.35, 0.45),
                color(0.45, 0.90, 0.50, 0.45), color(0.40, 0.70, 1.00, 0.45), color(0.70, 0.45, 1.00, 0.45), color(1, 1, 1, 0),
            ])

        case .voidEssence:
            // A glowing purple heart in the black, with motes circling it.
            let pulse = CGFloat(0.85 + 0.15 * sin(time * 2.6)) * CGFloat(min(1, level * 1.4))
            inner.fill(liquid, with: .radialGradient(
                Gradient(colors: [color(1.00, 0.85, 1.00), color(0.78, 0.36, 1.00), color(0.45, 0.10, 0.80, 0.5), color(0.30, 0.0, 0.6, 0)]),
                center: CGPoint(x: 57, y: 72), startRadius: 0, endRadius: 17 * pulse))
            for index in 0..<5 {
                let angle = time * 1.6 + Double(index) / 5 * 2 * .pi
                let orbit: CGFloat = 12 + CGFloat(index % 2) * 3
                let point = CGPoint(x: 57 + orbit * CGFloat(cos(angle)), y: 72 + orbit * 0.7 * CGFloat(sin(angle)))
                guard point.y > surface + 1 else { continue }
                inner.fill(circle(point, 1.2), with: .color(color(0.90, 0.70, 1.00, 0.9)))
            }

        case .frozenFrostbite:
            // Frosted glass: a cloudy coat, heavier near the rim.
            inner.fill(Path(CGRect(x: 0, y: 0, width: 140, height: 100)), with: .color(.white.opacity(0.18)))
            var frost = Path()
            frost.move(to: CGPoint(x: 28, y: 38))
            frost.addLine(to: CGPoint(x: 86, y: 38))
            for step in 0...14 {
                let x = 86 - CGFloat(step) * 58 / 14
                frost.addLine(to: CGPoint(x: x, y: 48 + (step % 2 == 0 ? 0 : 3.5) + CGFloat(step % 3)))
            }
            frost.closeSubpath()
            inner.fill(frost, with: .color(.white.opacity(0.55)))
            for (x, y) in [(36.0, 58.0), (44, 70), (71, 62), (77, 76), (62, 80), (50, 56), (66, 52)] {
                inner.fill(star4(CGPoint(x: x, y: y), 2.2), with: .color(.white.opacity(0.75)))
            }

        default:
            break
        }
    }

    /// A band of colour sweeping diagonally across the drink.
    private static func shimmer(_ inner: inout GraphicsContext, liquid: Path, time: Double, colors: [Color]) {
        let sweep = CGFloat((time * 0.45).truncatingRemainder(dividingBy: 1)) * 120 - 40
        inner.fill(liquid, with: .linearGradient(
            Gradient(colors: colors),
            startPoint: CGPoint(x: sweep, y: 40), endPoint: CGPoint(x: sweep + 36, y: 90)))
    }

    private static func drawEyeball(_ layer: inout GraphicsContext, at center: CGPoint, iris: Color, look: Double) {
        let radius: CGFloat = 4.4
        outlined(&layer, circle(center, radius), fill: .white, line: 1.3)
        let glance = CGPoint(x: center.x + CGFloat(cos(look)) * 1.6, y: center.y + CGFloat(sin(look * 0.7)) * 1.2)
        layer.fill(circle(glance, 2.2), with: .color(iris))
        layer.fill(circle(glance, 1), with: .color(ink))
        layer.fill(circle(CGPoint(x: glance.x - 0.8, y: glance.y - 0.8), 0.5), with: .color(.white))
        // A couple of bloodshot veins.
        var veins = Path()
        veins.move(to: CGPoint(x: center.x - radius + 0.6, y: center.y + 1))
        veins.addLine(to: CGPoint(x: center.x - 2.4, y: center.y + 0.4))
        veins.move(to: CGPoint(x: center.x + radius - 0.6, y: center.y - 1.4))
        veins.addLine(to: CGPoint(x: center.x + 2.6, y: center.y - 0.6))
        layer.stroke(veins, with: .color(color(0.90, 0.20, 0.20, 0.8)), lineWidth: 0.6)
    }

    /// Effects on and above the glass.
    private static func drawMagicOutside(
        _ layer: inout GraphicsContext, drink: Drink, glass: Glass, surface: CGFloat, drain: Double, time: Double,
        event: Double?
    ) {
        let left = 1 - drain
        switch drink {
        case .dragonsBlood:
            drawWisps(&layer, from: [46, 58, 69], baseY: 30, height: 26, time: time, fade: left,
                      color: color(0.88, 0.10, 0.14), width: 3.2, blur: 0.9)

        case .fairyDustElixir:
            // Dust escaping round the cork.
            for index in 0..<5 {
                let t = (time * 0.5 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                let x = 57 + CGFloat(sin(t * 5 + Double(index) * 2)) * (6 + CGFloat(t) * 10)
                let y = 12 - CGFloat(t) * 16
                let size = 3.2 * CGFloat(sin(t * .pi)) * CGFloat(left)
                guard size > 0.4 else { continue }
                outlined(&layer, star4(CGPoint(x: x, y: y), size + 0.8), fill: index % 2 == 0 ? color(1.00, 0.92, 0.50) : color(0.90, 0.75, 1.00), line: 1)
            }

        case .mermaidsTears:
            // A small seashell charm hung on the neck.
            var shell = layer
            shell.translateBy(x: 66, y: 33)
            shell.rotate(by: .degrees(18 + sin(time * 2.4) * 6))
            var string = Path()
            string.move(to: CGPoint(x: -4, y: -9))
            string.addLine(to: CGPoint(x: 0, y: -3))
            shell.stroke(string, with: .color(ink), lineWidth: 1.2)
            var fan = Path()
            fan.move(to: CGPoint(x: 0, y: -4))
            fan.addCurve(to: CGPoint(x: 0, y: 6), control1: CGPoint(x: 9, y: -6), control2: CGPoint(x: 9, y: 5))
            fan.addCurve(to: CGPoint(x: 0, y: -4), control1: CGPoint(x: -9, y: 5), control2: CGPoint(x: -9, y: -6))
            fan.closeSubpath()
            outlined(&shell, fan, fill: color(1.00, 0.76, 0.80), line: 1.5)
            var ridges = Path()
            for x in [-3.5, 0, 3.5] {
                ridges.move(to: CGPoint(x: 0, y: 5))
                ridges.addLine(to: CGPoint(x: CGFloat(x), y: -2.5))
            }
            shell.stroke(ridges, with: .color(color(0.85, 0.45, 0.55)), lineWidth: 0.9)

        case .witchsBrew:
            // Bubbles bursting out of the open neck.
            guard left > 0.05 else { break }
            for index in 0..<3 {
                let t = (time * 0.9 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let x = 57 + CGFloat(sin(t * 6 + Double(index) * 2.5)) * 4
                let y = 24 - CGFloat(t) * 18
                let radius = (2 + CGFloat(t) * 3.2) * CGFloat(left)
                if t > 0.85 {
                    // Pop.
                    var burst = Path()
                    for k in 0..<6 {
                        let a = Double(k) / 6 * 2 * .pi
                        burst.move(to: CGPoint(x: x + CGFloat(cos(a)) * radius * 0.8, y: y + CGFloat(sin(a)) * radius * 0.8))
                        burst.addLine(to: CGPoint(x: x + CGFloat(cos(a)) * radius * 1.4, y: y + CGFloat(sin(a)) * radius * 1.4))
                    }
                    layer.stroke(burst, with: .color(color(0.40, 0.80, 0.10)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                } else {
                    outlined(&layer, circle(CGPoint(x: x, y: y), radius), fill: color(0.72, 1.00, 0.30), line: 1.6)
                    layer.fill(circle(CGPoint(x: x - radius * 0.35, y: y - radius * 0.35), radius * 0.28), with: .color(.white.opacity(0.9)))
                }
            }

        case .phoenixFlame:
            drawFlame(&layer, amount: max(0, 1 - drain * 2) * (1 + 0.4 * (event.map(bump) ?? 0)), time: time)

        case .moonlightNectar:
            drawCrescent(&layer, center: CGPoint(x: 88, y: 30), radius: 10, time: time,
                         flip: easeInOut(min(1, (event ?? 0) * 1.3)))

        case .goblinGrog:
            // A murky bubble glugging up now and then.
            let t = (time * 0.7).truncatingRemainder(dividingBy: 1)
            if left > 0.05, t < 0.7 {
                let radius = CGFloat(t / 0.7) * 3 + 1
                let center = CGPoint(x: 64, y: surface - radius * 0.6)
                outlined(&layer, circle(center, radius), fill: color(0.55, 0.60, 0.25), line: 1.3)
            }

        case .unicornTears:
            drawHorn(&layer, time: time)

        case .frozenFrostbite:
            // Ice shards jutting out of the drink, and icicles on the rim.
            let sinkBy = min(surface - glass.full, glass.bottom - 52)
            let shards: [[CGPoint]] = [
                [CGPoint(x: 42, y: 52), CGPoint(x: 39, y: 34), CGPoint(x: 45, y: 26), CGPoint(x: 50, y: 50)],
                [CGPoint(x: 54, y: 52), CGPoint(x: 57, y: 20), CGPoint(x: 63, y: 30), CGPoint(x: 64, y: 52)],
                [CGPoint(x: 66, y: 52), CGPoint(x: 72, y: 32), CGPoint(x: 76, y: 38), CGPoint(x: 73, y: 52)],
            ]
            var front = layer
            front.clip(to: glass.bowl)
            for points in shards {
                var shard = Path()
                shard.addLines(points.map { CGPoint(x: $0.x, y: $0.y + sinkBy) })
                shard.closeSubpath()
                // Above the rim the shard stands in the open; below it, seen through the frost.
                outlined(&layer, shard, fill: color(0.84, 0.98, 1.00), line: 2)
                front.fill(shard, with: .color(.white.opacity(0.35)))
                var facet = Path()
                facet.move(to: CGPoint(x: points[1].x, y: points[1].y + sinkBy))
                facet.addLine(to: CGPoint(x: (points[0].x + points[3].x) / 2 + 1, y: points[0].y + sinkBy))
                layer.stroke(facet, with: .color(color(0.45, 0.80, 0.95)), lineWidth: 1)
            }
            for (x, length) in [(33.0, 9.0), (39, 6), (76, 7), (82, 10)] {
                var icicle = Path()
                icicle.move(to: CGPoint(x: x - 2.4, y: 39))
                icicle.addLine(to: CGPoint(x: x + 2.4, y: 39))
                icicle.addLine(to: CGPoint(x: x, y: 39 + length))
                icicle.closeSubpath()
                outlined(&layer, icicle, fill: color(0.86, 0.98, 1.00), line: 1.6)
            }
            var rimFrost = Path()
            rimFrost.move(to: CGPoint(x: 30, y: 40))
            rimFrost.addLine(to: CGPoint(x: 84, y: 40))
            layer.stroke(rimFrost, with: .color(.white), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        default:
            break
        }
    }

    private static func drawWisps(
        _ layer: inout GraphicsContext, from xs: [Double], baseY: Double, height: Double,
        time: Double, fade: Double, color wispColor: Color, width: CGFloat, blur: CGFloat
    ) {
        guard fade > 0.05 else { return }
        var smoke = layer
        smoke.addFilter(.blur(radius: blur))
        for (index, x) in xs.enumerated() {
            let phase = time * 1.1 + Double(index) * 0.37
            let rise = phase.truncatingRemainder(dividingBy: 1)
            var wisp = Path()
            for step in 0...12 {
                let t = Double(step) / 12
                let y = baseY - t * height - rise * 6
                let curl = sin(t * 2.4 * .pi + phase * 2 * .pi) * (1.5 + t * 3.5)
                let point = CGPoint(x: x + curl, y: y)
                if step == 0 { wisp.move(to: point) } else { wisp.addLine(to: point) }
            }
            let alpha = 0.7 * fade * (1 - rise * 0.5)
            smoke.stroke(wisp, with: .color(wispColor.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    private static func drawFlame(_ layer: inout GraphicsContext, amount: Double, time: Double) {
        guard amount > 0.04 else { return }
        func tongue(width: CGFloat, height: CGFloat, lean: CGFloat) -> Path {
            let base: CGFloat = 27
            var path = Path()
            path.move(to: CGPoint(x: 57 - width, y: base))
            path.addCurve(
                to: CGPoint(x: 57 + lean, y: base - height),
                control1: CGPoint(x: 57 - width * 1.15, y: base - height * 0.45),
                control2: CGPoint(x: 57 - width * 0.3 + lean * 0.4, y: base - height * 0.7))
            path.addCurve(
                to: CGPoint(x: 57 + width, y: base),
                control1: CGPoint(x: 57 + width * 0.3 + lean * 0.4, y: base - height * 0.7),
                control2: CGPoint(x: 57 + width * 1.15, y: base - height * 0.45))
            path.addQuadCurve(to: CGPoint(x: 57 - width, y: base), control: CGPoint(x: 57, y: base + 3))
            path.closeSubpath()
            return path
        }
        let a = CGFloat(amount)
        let flicker = CGFloat(sin(time * 13) * 0.06 + sin(time * 7.3) * 0.05)
        let lean = CGFloat(sin(time * 5.1)) * 3
        let outer = tongue(width: 16 * a, height: 28 * a * (1 + flicker), lean: lean)
        let middle = tongue(width: 11 * a, height: 20 * a * (1 - flicker), lean: lean * 0.7)
        let core = tongue(width: 6 * a, height: 11 * a * (1 + flicker), lean: lean * 0.4)
        outlined(&layer, outer, fill: color(1.00, 0.36, 0.08), line: 2.6)
        layer.fill(middle, with: .color(color(1.00, 0.66, 0.10)))
        layer.fill(core, with: .color(color(1.00, 0.95, 0.55)))
        // Embers drifting up.
        for index in 0..<3 {
            let t = (time * 0.8 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(
                x: 57 + CGFloat(sin(t * 7 + Double(index) * 2)) * 10,
                y: 20 - CGFloat(t) * 22 * a)
            layer.fill(circle(point, 1.4 * a * CGFloat(1 - t)), with: .color(color(1.00, 0.60, 0.10)))
        }
    }

    private static func drawCrescent(
        _ layer: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double, flip: Double = 0
    ) {
        var moon = layer
        moon.translateBy(x: center.x, y: center.y)
        moon.rotate(by: .degrees(sin(time * 1.8) * 6 - 10 + flip * 360))
        let bite = circle(CGPoint(x: radius * 0.55, y: -radius * 0.25), radius * 0.85)
        moon.clip(to: bite, options: .inverse)
        moon.fill(circle(.zero, radius + 1.6), with: .color(ink))
        moon.fill(circle(.zero, radius), with: .color(color(1.00, 0.95, 0.62)))
        moon.fill(circle(CGPoint(x: -radius * 0.45, y: radius * 0.2), 1.6), with: .color(color(0.92, 0.82, 0.45)))
        moon.fill(circle(CGPoint(x: -radius * 0.2, y: radius * 0.6), 1.1), with: .color(color(0.92, 0.82, 0.45)))
        // Re-draw the ink along the bite so the inner curve is outlined too.
        var edge = layer
        edge.translateBy(x: center.x, y: center.y)
        edge.rotate(by: .degrees(sin(time * 1.8) * 6 - 10 + flip * 360))
        edge.clip(to: circle(.zero, radius))
        edge.stroke(bite, with: .color(ink), lineWidth: 3.2)
    }

    private static func drawHorn(_ layer: inout GraphicsContext, time: Double) {
        var horn = layer
        horn.translateBy(x: 69, y: 22)
        horn.rotate(by: .degrees(24 + sin(time * 2.2) * 3))
        var cone = Path()
        cone.move(to: CGPoint(x: -5, y: 0))
        cone.addLine(to: CGPoint(x: 0, y: -26))
        cone.addLine(to: CGPoint(x: 5, y: 0))
        cone.addQuadCurve(to: CGPoint(x: -5, y: 0), control: CGPoint(x: 0, y: 2))
        cone.closeSubpath()
        horn.fill(cone, with: .linearGradient(
            Gradient(colors: [color(1.00, 0.95, 0.70), color(1.00, 0.80, 0.40)]),
            startPoint: CGPoint(x: -5, y: 0), endPoint: CGPoint(x: 5, y: -10)))
        var spiral = Path()
        for index in 0..<4 {
            let y = -3 - CGFloat(index) * 5.6
            let half = 5 * (1 + y / 26)
            spiral.move(to: CGPoint(x: -half, y: y + 1.6))
            spiral.addLine(to: CGPoint(x: half, y: y - 1.6))
        }
        horn.stroke(spiral, with: .color(color(0.86, 0.60, 0.25)), lineWidth: 1.2)
        horn.stroke(cone, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))

        for (index, spot) in [CGPoint(x: 84, y: 2), CGPoint(x: 90, y: 14), CGPoint(x: 77, y: -4)].enumerated() {
            let size = 3.4 * (0.25 + 0.75 * twinkle(time, Double(index), speed: 4.5))
            outlined(&layer, star4(spot, size), fill: [color(1.00, 0.70, 0.85), color(0.75, 0.70, 1.00), color(1.00, 0.92, 0.55)][index], line: 1)
        }
    }

    // MARK: Enchantments

    /// The coloured glow each fantasy drink gives off.
    private static func aura(_ drink: Drink) -> Color? {
        switch drink {
        case .dragonsBlood: color(1.00, 0.18, 0.18)
        case .fairyDustElixir: color(0.92, 0.50, 1.00)
        case .mermaidsTears: color(0.20, 0.88, 1.00)
        case .witchsBrew: color(0.50, 1.00, 0.18)
        case .phoenixFlame: color(1.00, 0.58, 0.08)
        case .moonlightNectar: color(0.70, 0.82, 1.00)
        case .goblinGrog: color(0.58, 0.78, 0.18)
        case .unicornTears: color(1.00, 0.58, 0.90)
        case .voidEssence: color(0.62, 0.18, 1.00)
        case .frozenFrostbite: color(0.45, 0.90, 1.00)
        default: nil
        }
    }

    /// Drawn before the glass: the aura, and anything that sits behind it.
    private static func drawMagicBehind(
        _ layer: inout GraphicsContext, drink: Drink, glass: Glass, drain: Double, time: Double, event: Double?
    ) {
        guard let glow = aura(drink) else { return }
        let pulse = 0.75 + 0.25 * sin(time * 3.2)
        var haze = layer
        haze.addFilter(.blur(radius: 7))
        haze.stroke(glass.bowl, with: .color(glow.opacity(0.75 * pulse * (1 - drain * 0.5))), lineWidth: 14)
        haze.fill(glass.bowl, with: .color(glow.opacity(0.5 * pulse)))

        switch drink {
        case .fairyDustElixir:
            drawFairyWings(&layer, time: time)
        case .phoenixFlame:
            drawPhoenixWings(&layer, time: time, amount: max(0.35, 1 - drain), boost: event.map(bump) ?? 0)
        case .unicornTears:
            drawRainbow(&layer, time: time, flashing: event != nil)
        case .voidEssence:
            drawVoidRing(&layer, time: time, half: .back)
        default:
            break
        }
    }

    /// Extra life inside the glass, over the liquid.
    private static func drawEnchantInside(
        _ inner: inout GraphicsContext, drink: Drink, glass: Glass, liquid: Path, surface: CGFloat, time: Double
    ) {
        switch drink {
        case .dragonsBlood:
            // A dragon's eye watching from the depths, blinking now and then.
            var eye = inner
            eye.clip(to: liquid)
            let center = CGPoint(x: 57, y: 53)
            let cycle = time.truncatingRemainder(dividingBy: 3.1)
            let open = CGFloat(cycle < 0.18 ? abs(cycle - 0.09) / 0.09 : 1)
            eye.translateBy(x: center.x, y: center.y)
            eye.scaleBy(x: 1, y: max(0.08, open))
            let ball = Path(ellipseIn: CGRect(x: -9, y: -6, width: 18, height: 12))
            eye.fill(ball, with: .radialGradient(
                Gradient(colors: [color(1.00, 0.95, 0.45), color(1.00, 0.62, 0.10), color(0.85, 0.20, 0.05)]),
                center: .zero, startRadius: 0, endRadius: 9))
            eye.stroke(ball, with: .color(ink), lineWidth: 1.6)
            let look = CGFloat(sin(time * 0.9)) * 2.5
            var slit = Path()
            slit.move(to: CGPoint(x: look, y: -5.4))
            slit.addQuadCurve(to: CGPoint(x: look, y: 5.4), control: CGPoint(x: look + 2.6, y: 0))
            slit.addQuadCurve(to: CGPoint(x: look, y: -5.4), control: CGPoint(x: look - 2.6, y: 0))
            eye.fill(slit, with: .color(ink))
            eye.fill(circle(CGPoint(x: -4, y: -2.4), 1.3), with: .color(.white.opacity(0.9)))

        case .fairyDustElixir:
            // A whirl of dust spinning in the bottle.
            for index in 0..<14 {
                let t = Double(index) / 14
                let angle = time * 2.2 + t * 4 * .pi
                let radius = 4 + CGFloat(t) * 15
                let point = CGPoint(x: 57 + radius * CGFloat(cos(angle)), y: 70 + radius * 0.55 * CGFloat(sin(angle)))
                guard point.y > surface + 2 else { continue }
                inner.fill(circle(point, 0.7 + CGFloat(1 - t) * 0.9),
                           with: .color(index % 3 == 0 ? color(1.00, 0.92, 0.50) : .white.opacity(0.9)))
            }

        case .mermaidsTears:
            // A little mermaid's tail swimming laps of the bottle.
            let angle = time * 1.3
            let center = CGPoint(x: 57 + 11 * CGFloat(cos(angle)), y: 72 + 6 * CGFloat(sin(angle * 2)))
            guard center.y > surface + 6 else { break }
            var tail = inner
            tail.translateBy(x: center.x, y: center.y)
            let heading = -sin(angle) >= 0 ? 1.0 : -1.0
            tail.scaleBy(x: CGFloat(heading), y: 1)
            tail.rotate(by: .degrees(sin(time * 8) * 12))
            var body = Path()
            body.move(to: CGPoint(x: 6, y: -2.6))
            body.addQuadCurve(to: CGPoint(x: -5, y: 0), control: CGPoint(x: 0, y: -3.4))
            body.addQuadCurve(to: CGPoint(x: 6, y: 2.6), control: CGPoint(x: 0, y: 3.4))
            body.closeSubpath()
            var fin = Path()
            fin.move(to: CGPoint(x: -4, y: 0))
            fin.addQuadCurve(to: CGPoint(x: -10, y: -5.5), control: CGPoint(x: -6, y: -4))
            fin.addQuadCurve(to: CGPoint(x: -8, y: 0), control: CGPoint(x: -8, y: -2))
            fin.addQuadCurve(to: CGPoint(x: -10, y: 5.5), control: CGPoint(x: -8, y: 2))
            fin.addQuadCurve(to: CGPoint(x: -4, y: 0), control: CGPoint(x: -6, y: 4))
            fin.closeSubpath()
            outlined(&tail, fin, fill: color(0.70, 0.40, 0.95), line: 1.3)
            outlined(&tail, body, fill: color(0.10, 0.80, 0.70), line: 1.3)
            var scales = Path()
            for x in [-1.0, 2.0] {
                scales.move(to: CGPoint(x: x, y: -2))
                scales.addQuadCurve(to: CGPoint(x: x, y: 2), control: CGPoint(x: x - 1.6, y: 0))
            }
            tail.stroke(scales, with: .color(color(0.02, 0.50, 0.45)), lineWidth: 0.8)

        case .voidEssence:
            // Spiral arms wheeling round the glowing heart, like a tiny galaxy.
            var arms = inner
            arms.clip(to: liquid)
            for arm in 0..<3 {
                var spiral = Path()
                for step in 0...16 {
                    let t = Double(step) / 16
                    let angle = -time * 1.8 + Double(arm) / 3 * 2 * .pi + t * 2.6
                    let radius = 3 + CGFloat(t) * 17
                    let point = CGPoint(x: 57 + radius * CGFloat(cos(angle)), y: 72 + radius * 0.75 * CGFloat(sin(angle)))
                    if step == 0 { spiral.move(to: point) } else { spiral.addLine(to: point) }
                }
                arms.stroke(spiral, with: .color(color(0.86, 0.60, 1.00, 0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }

        default:
            break
        }
    }

    /// Creatures and spells around the glass.
    private static func drawEnchantOutside(
        _ layer: inout GraphicsContext, drink: Drink, glass: Glass, surface: CGFloat, drain: Double, time: Double
    ) {
        let left = 1 - drain
        switch drink {
        case .dragonsBlood:
            drawRisingSparks(&layer, xs: [42, 52, 62, 72], baseY: 30, height: 34, time: time, fade: left,
                             colors: [color(1.00, 0.55, 0.10), color(1.00, 0.85, 0.30)])

        case .fairyDustElixir:
            // A trail of sparkles spiralling round the bottle.
            for index in 0..<7 {
                let t = (time * 0.35 + Double(index) / 7).truncatingRemainder(dividingBy: 1)
                let angle = t * 4 * .pi
                let point = CGPoint(x: 57 + 30 * CGFloat(cos(angle)), y: 90 - CGFloat(t) * 84)
                let size = (1.6 + 2.4 * CGFloat(sin(t * .pi))) * (sin(angle) > 0 ? 1 : 0.6)
                outlined(&layer, star4(point, size + 0.6), fill: index % 2 == 0 ? color(1.00, 0.90, 0.45) : color(1.00, 0.75, 0.95), line: 0.9)
            }

        case .mermaidsTears:
            // Bubbles drifting up around the bottle.
            for index in 0..<4 {
                let t = (time * 0.4 + Double(index) / 4).truncatingRemainder(dividingBy: 1)
                let x = (index % 2 == 0 ? 30.0 : 84.0) + sin(t * 9 + Double(index)) * 3
                let point = CGPoint(x: x, y: 86 - CGFloat(t) * 70)
                let radius = 1.6 + CGFloat(index % 3) * 0.7
                layer.stroke(circle(point, radius), with: .color(color(0.20, 0.60, 0.90, 0.9 * (1 - t))), lineWidth: 1.2)
                layer.fill(circle(CGPoint(x: point.x - radius * 0.35, y: point.y - radius * 0.35), radius * 0.3), with: .color(.white))
            }

        case .witchsBrew:
            drawWisps(&layer, from: [54, 60], baseY: 18, height: 20, time: time, fade: left,
                      color: color(0.45, 0.90, 0.15), width: 3, blur: 1.2)
            drawBat(&layer, time: time)

        case .phoenixFlame:
            // Feathers of fire floating up.
            for index in 0..<3 {
                let t = (time * 0.45 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let point = CGPoint(x: 57 + CGFloat(sin(t * 6 + Double(index) * 2.2)) * 18, y: 18 - CGFloat(t) * 26)
                var feather = layer
                feather.translateBy(x: point.x, y: point.y)
                feather.rotate(by: .degrees(sin(t * 8) * 40))
                feather.opacity = (1 - t) * left
                outlined(&feather, leaf(CGPoint(x: 0, y: 4), CGPoint(x: 0, y: -4), width: 2.4), fill: color(1.00, 0.70, 0.12), line: 1)
            }

        case .moonlightNectar:
            // Fireflies of starlight drifting up, and a shooting star now and then.
            for index in 0..<5 {
                let t = (time * 0.3 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                let x = 22 + Double(index) * 17 + sin(t * 7 + Double(index)) * 4
                let point = CGPoint(x: x, y: 34 - CGFloat(t) * 36)
                let size = 2.8 * CGFloat(sin(t * .pi)) * (0.5 + 0.5 * twinkle(time, Double(index), speed: 6))
                guard size > 0.3 else { continue }
                var glow = layer
                glow.addFilter(.blur(radius: 2))
                glow.fill(circle(point, size * 1.4), with: .color(color(1.00, 0.97, 0.70)))
                layer.fill(star4(point, size * 1.3), with: .color(color(1.00, 0.98, 0.80)))
            }
            let shot = time.truncatingRemainder(dividingBy: 2.6) / 0.6
            if shot < 1 {
                let head = CGPoint(x: 8 + CGFloat(shot) * 70, y: -2 + CGFloat(shot) * 12)
                var streak = Path()
                streak.move(to: CGPoint(x: head.x - 16, y: head.y - 2.8))
                streak.addLine(to: head)
                layer.stroke(streak, with: .linearGradient(
                    Gradient(colors: [color(1, 1, 1, 0), color(1.00, 0.95, 0.70)]),
                    startPoint: CGPoint(x: head.x - 16, y: head.y), endPoint: head),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
                outlined(&layer, star4(head, 3.4), fill: color(1.00, 0.97, 0.75), line: 0.9)
            }

        case .goblinGrog:
            drawWisps(&layer, from: [46, 66], baseY: 30, height: 16, time: time, fade: left,
                      color: color(0.50, 0.62, 0.15), width: 2.2, blur: 0.5)
            drawMushroom(&layer, at: CGPoint(x: 41, y: 33), time: time)
            drawFly(&layer, time: time)

        case .voidEssence:
            drawVoidRing(&layer, time: time, half: .front)

        case .frozenFrostbite:
            for index in 0..<5 {
                let t = (time * 0.22 + Double(index) / 5).truncatingRemainder(dividingBy: 1)
                let x = [20.0, 94, 30, 86, 57][index] + sin(t * 6 + Double(index)) * 4
                let point = CGPoint(x: x, y: -4 + CGFloat(t) * 80)
                let fade = min(1, (1 - t) * 4, t * 6)
                drawSnowflake(&layer, at: point, radius: 3.6 + CGFloat(index % 2), spin: time * 0.8 + Double(index), alpha: fade)
            }

        default:
            break
        }
    }

    private static func drawRisingSparks(
        _ layer: inout GraphicsContext, xs: [Double], baseY: Double, height: Double, time: Double, fade: Double, colors: [Color]
    ) {
        guard fade > 0.05 else { return }
        for (index, x) in xs.enumerated() {
            let t = (time * 0.7 + Double(index) * 0.29).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: x + sin(t * 8 + Double(index)) * 4, y: baseY - t * height)
            let radius = 1.6 * CGFloat(1 - t) * CGFloat(fade)
            layer.fill(circle(point, radius + 0.7), with: .color(ink.opacity(0.6 * (1 - t))))
            layer.fill(circle(point, radius), with: .color(colors[index % colors.count]))
        }
    }

    private static func drawFairyWings(_ layer: inout GraphicsContext, time: Double) {
        let flap = 0.45 + 0.55 * CGFloat(abs(sin(time * 11)))
        for side in [-1.0, 1.0] {
            var wing = layer
            wing.translateBy(x: 57 + CGFloat(side) * 19, y: 54)
            wing.scaleBy(x: CGFloat(side) * flap, y: 1)
            let upper = Path(ellipseIn: CGRect(x: 0, y: -20, width: 20, height: 15))
            let lower = Path(ellipseIn: CGRect(x: 0, y: -6, width: 14, height: 11))
            var wingTilt = wing
            wingTilt.rotate(by: .degrees(-12))
            for part in [lower, upper] {
                wingTilt.fill(part, with: .linearGradient(
                    Gradient(colors: [color(0.80, 0.95, 1.00, 0.85), color(1.00, 0.80, 0.98, 0.85)]),
                    startPoint: .zero, endPoint: CGPoint(x: 20, y: -18)))
                wingTilt.stroke(part, with: .color(ink), lineWidth: 1.6)
            }
            var vein = Path()
            vein.move(to: CGPoint(x: 1, y: -2))
            vein.addLine(to: CGPoint(x: 15, y: -15))
            vein.move(to: CGPoint(x: 1, y: -1))
            vein.addLine(to: CGPoint(x: 10, y: 2))
            wingTilt.stroke(vein, with: .color(color(0.60, 0.50, 0.90, 0.6)), lineWidth: 0.8)
        }
    }

    private static func drawPhoenixWings(_ layer: inout GraphicsContext, time: Double, amount: Double, boost: Double) {
        // Beats faster and wider while the flame surges.
        let beat = sin(time * (6 + 6 * boost)) * (1 + 0.9 * boost)
        for side in [-1.0, 1.0] {
            var wing = layer
            wing.translateBy(x: 57 + CGFloat(side) * 16, y: 40)
            wing.scaleBy(x: CGFloat(side) * CGFloat(amount), y: CGFloat(amount))
            wing.rotate(by: .degrees(-beat * 16))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 6))
            path.addCurve(to: CGPoint(x: 36, y: -26), control1: CGPoint(x: 10, y: -12), control2: CGPoint(x: 24, y: -24))
            // Three flame-tipped feathers along the trailing edge.
            path.addQuadCurve(to: CGPoint(x: 26, y: -12), control: CGPoint(x: 34, y: -14))
            path.addQuadCurve(to: CGPoint(x: 31, y: -6), control: CGPoint(x: 27, y: -8))
            path.addQuadCurve(to: CGPoint(x: 18, y: -2), control: CGPoint(x: 24, y: -2))
            path.addQuadCurve(to: CGPoint(x: 20, y: 6), control: CGPoint(x: 17, y: 2))
            path.addQuadCurve(to: CGPoint(x: 0, y: 6), control: CGPoint(x: 10, y: 8))
            path.closeSubpath()
            wing.fill(path, with: .linearGradient(
                Gradient(colors: [color(0.95, 0.22, 0.05), color(1.00, 0.60, 0.08), color(1.00, 0.90, 0.30)]),
                startPoint: CGPoint(x: 0, y: 4), endPoint: CGPoint(x: 34, y: -24)))
            wing.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }
    }

    private static func drawRainbow(_ layer: inout GraphicsContext, time: Double, flashing: Bool) {
        let bands: [Color] = [
            color(1.00, 0.36, 0.40), color(1.00, 0.66, 0.25), color(1.00, 0.92, 0.35),
            color(0.45, 0.88, 0.45), color(0.35, 0.68, 1.00), color(0.66, 0.45, 1.00),
        ]
        let center = CGPoint(x: 57, y: 30)
        let shimmer = 0.85 + 0.15 * sin(time * 3)
        let outer = Path { path in
            path.addArc(center: center, radius: 37.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }
        layer.stroke(outer, with: .color(ink), lineWidth: 2.4)
        for (index, band) in bands.enumerated() {
            let radius = 36 - CGFloat(index) * 2.6
            let arc = Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            }
            // While the horn fires, the colours chase round the bands.
            let shown = flashing ? bands[(index + Int(time * 14)) % bands.count] : band
            layer.stroke(arc, with: .color(shown.opacity(shimmer)), lineWidth: 2.8)
        }
        let inner = Path { path in
            path.addArc(center: center, radius: 21.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }
        layer.stroke(inner, with: .color(ink), lineWidth: 2)
        // Puffy clouds where it touches down.
        for x in [27.0, 87.0] {
            let puffs = [circle(CGPoint(x: x - 5, y: 31), 4.5), circle(CGPoint(x: x + 1, y: 28), 5.5), circle(CGPoint(x: x + 6, y: 32), 4)]
            for puff in puffs { layer.stroke(puff, with: .color(ink), lineWidth: 4.4) }
            for puff in puffs { layer.fill(puff, with: .color(.white)) }
        }
    }

    private enum RingHalf { case back, front }

    /// A tilted ring orbiting the void flask; its back half is drawn behind the glass.
    private static func drawVoidRing(_ layer: inout GraphicsContext, time: Double, half: RingHalf) {
        var ring = layer
        ring.translateBy(x: 57, y: 71)
        ring.rotate(by: .degrees(-14))
        let oval = Path(ellipseIn: CGRect(x: -33, y: -8, width: 66, height: 16))
        ring.clip(to: Path(CGRect(x: -50, y: half == .back ? -30 : 0, width: 100, height: 30)))
        ring.stroke(oval, with: .color(ink), lineWidth: 5.4)
        ring.stroke(oval, with: .linearGradient(
            Gradient(colors: [color(0.55, 0.20, 1.00), color(0.95, 0.70, 1.00), color(0.55, 0.20, 1.00)]),
            startPoint: CGPoint(x: -33, y: 0), endPoint: CGPoint(x: 33, y: 0)), lineWidth: 2.4)
        // A little moon riding the ring.
        let angle = time * 1.4
        let moon = CGPoint(x: 33 * CGFloat(cos(angle)), y: 8 * CGFloat(sin(angle)))
        if (moon.y >= 0) == (half == .front) {
            outlined(&ring, circle(moon, 2.8), fill: color(0.95, 0.85, 1.00), line: 1.4)
        }
    }

    private static func drawBat(_ layer: inout GraphicsContext, time: Double) {
        let angle = time * 1.5
        let point = CGPoint(x: 57 + 30 * CGFloat(cos(angle)), y: 30 + 9 * CGFloat(sin(angle * 2)))
        var bat = layer
        bat.translateBy(x: point.x, y: point.y)
        bat.scaleBy(x: sin(angle) > 0 ? -1 : 1, y: 1)
        let flap = CGFloat(sin(time * 16)) * 4
        var wings = Path()
        wings.move(to: CGPoint(x: 0, y: 0))
        wings.addQuadCurve(to: CGPoint(x: -11, y: -3 - flap), control: CGPoint(x: -5, y: -6 - flap))
        wings.addQuadCurve(to: CGPoint(x: -7, y: 2), control: CGPoint(x: -10, y: 1))
        wings.addQuadCurve(to: CGPoint(x: -3, y: 2), control: CGPoint(x: -5, y: 0))
        wings.addLine(to: CGPoint(x: 3, y: 2))
        wings.addQuadCurve(to: CGPoint(x: 7, y: 2), control: CGPoint(x: 5, y: 0))
        wings.addQuadCurve(to: CGPoint(x: 11, y: -3 - flap), control: CGPoint(x: 10, y: 1))
        wings.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 5, y: -6 - flap))
        wings.closeSubpath()
        bat.fill(wings, with: .color(color(0.24, 0.12, 0.32)))
        bat.stroke(wings, with: .color(ink), lineWidth: 1.2)
        bat.fill(circle(CGPoint(x: 0, y: 0.5), 3), with: .color(color(0.24, 0.12, 0.32)))
        var ears = Path()
        ears.addLines([CGPoint(x: -2.4, y: -1.5), CGPoint(x: -1.8, y: -4.2), CGPoint(x: -0.6, y: -2.2)])
        ears.addLines([CGPoint(x: 0.6, y: -2.2), CGPoint(x: 1.8, y: -4.2), CGPoint(x: 2.4, y: -1.5)])
        bat.fill(ears, with: .color(color(0.24, 0.12, 0.32)))
        bat.fill(circle(CGPoint(x: -1, y: 0), 0.7), with: .color(color(1.00, 0.85, 0.20)))
        bat.fill(circle(CGPoint(x: 1, y: 0), 0.7), with: .color(color(1.00, 0.85, 0.20)))
    }

    private static func drawMushroom(_ layer: inout GraphicsContext, at point: CGPoint, time: Double) {
        var shroom = layer
        shroom.translateBy(x: point.x, y: point.y)
        shroom.rotate(by: .degrees(-12 + sin(time * 2.5) * 4))
        outlined(&shroom, Path(roundedRect: CGRect(x: -2, y: -7, width: 4, height: 8), cornerRadius: 1.5), fill: color(0.96, 0.92, 0.80), line: 1.4)
        var cap = Path()
        cap.move(to: CGPoint(x: -7.5, y: -6))
        cap.addQuadCurve(to: CGPoint(x: 7.5, y: -6), control: CGPoint(x: 0, y: -18))
        cap.addQuadCurve(to: CGPoint(x: -7.5, y: -6), control: CGPoint(x: 0, y: -4.5))
        cap.closeSubpath()
        outlined(&shroom, cap, fill: color(0.86, 0.16, 0.18), line: 1.6)
        for spot in [CGPoint(x: -3.5, y: -9), CGPoint(x: 1.5, y: -11.5), CGPoint(x: 4, y: -8)] {
            shroom.fill(circle(spot, 1.1), with: .color(.white))
        }
    }

    private static func drawFly(_ layer: inout GraphicsContext, time: Double) {
        let t = time * 2.2
        let point = CGPoint(x: 76 + 9 * CGFloat(sin(t)), y: 16 + 5 * CGFloat(sin(t * 2)))
        var path = Path()
        for step in 0...10 {
            let s = t - Double(step) * 0.08
            let trail = CGPoint(x: 76 + 9 * CGFloat(sin(s)), y: 16 + 5 * CGFloat(sin(s * 2)))
            if step == 0 { path.move(to: trail) } else { path.addLine(to: trail) }
        }
        layer.stroke(path, with: .color(ink.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1.5, 1.5]))
        let buzz = CGFloat(abs(sin(time * 40))) * 1.2
        layer.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 4 - buzz, width: 3, height: 3.6)), with: .color(.white.opacity(0.85)))
        layer.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y - 4 - buzz, width: 3, height: 3.6)), with: .color(.white.opacity(0.85)))
        layer.fill(circle(point, 1.8), with: .color(ink))
    }

    private static func drawSnowflake(_ layer: inout GraphicsContext, at point: CGPoint, radius: CGFloat, spin: Double, alpha: Double) {
        guard alpha > 0.05 else { return }
        var flake = layer
        flake.translateBy(x: point.x, y: point.y)
        flake.rotate(by: .radians(spin))
        flake.opacity = alpha
        var arms = Path()
        for index in 0..<6 {
            let angle = Double(index) / 6 * 2 * .pi
            let tip = CGPoint(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            arms.move(to: .zero)
            arms.addLine(to: tip)
            let mid = CGPoint(x: tip.x * 0.6, y: tip.y * 0.6)
            for side in [-0.6, 0.6] {
                arms.move(to: mid)
                arms.addLine(to: CGPoint(
                    x: mid.x + radius * 0.35 * CGFloat(cos(angle + side)),
                    y: mid.y + radius * 0.35 * CGFloat(sin(angle + side))))
            }
        }
        flake.stroke(arms, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        flake.stroke(arms, with: .color(color(0.85, 0.97, 1.00)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }

    // MARK: Special moves

    /// Every few seconds of dancing a fantasy drink shows off. Returns how far
    /// through the current move it is (0...1), or nil between moves.
    private static func specialMove(time: Double, listening: Bool) -> Double? {
        guard listening, time > 1.6 else { return nil }
        let progress = (time - 1.6).truncatingRemainder(dividingBy: 4.2) / 1.3
        return progress < 1 ? progress : nil
    }

    /// 0 → 1 → 0 over a move.
    private static func bump(_ progress: Double) -> Double {
        sin(.pi * min(1, max(0, progress)))
    }

    private static func easeInOut(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private static func drawSpecialMove(
        _ layer: inout GraphicsContext, drink: Drink, glass: Glass, surface: CGFloat, move e: Double, time: Double
    ) {
        switch drink {
        case .dragonsBlood:
            // Breathes a gout of fire up and out of the goblet.
            let origin = CGPoint(x: 74, y: 30)
            let direction = CGPoint(x: 0.57, y: -0.82)
            let reach = min(1, e * 2.2)
            var fire = layer
            fire.opacity = e < 0.7 ? 1 : (1 - e) / 0.3
            // Overlapping puffs merged under one outline, like the foam: red
            // outside, orange, then a yellow-white core.
            var puffs: [(CGPoint, CGFloat)] = []
            for index in 0...9 {
                let f = Double(index) / 9
                guard f <= reach else { continue }
                let distance = 3 + CGFloat(f) * 36
                let jitter = CGFloat(sin(time * 22 + Double(index) * 1.3)) * 2 * CGFloat(f)
                let center = CGPoint(
                    x: origin.x + direction.x * distance - direction.y * jitter,
                    y: origin.y + direction.y * distance + direction.x * jitter)
                puffs.append((center, 3 + CGFloat(f) * 7))
            }
            var glow = fire
            glow.addFilter(.blur(radius: 4))
            for puff in puffs { glow.fill(circle(puff.0, puff.1 * 1.3), with: .color(color(1.00, 0.45, 0.10, 0.7))) }
            for puff in puffs { fire.stroke(circle(puff.0, puff.1), with: .color(ink), lineWidth: 3.2) }
            for puff in puffs { fire.fill(circle(puff.0, puff.1), with: .color(color(0.94, 0.24, 0.08))) }
            for puff in puffs { fire.fill(circle(puff.0, puff.1 * 0.68), with: .color(color(1.00, 0.60, 0.10))) }
            for puff in puffs { fire.fill(circle(puff.0, puff.1 * 0.36), with: .color(color(1.00, 0.95, 0.55))) }

        case .fairyDustElixir:
            // The cork pops (see drawBottleTop) and glitter fountains out.
            var glitter = layer
            glitter.opacity = 1 - e
            let colors = [color(1.00, 0.90, 0.40), color(1.00, 0.70, 0.95), color(0.60, 0.95, 1.00)]
            for index in 0..<12 {
                let t = CGFloat(e * 1.2)
                let vx = (CGFloat(index) / 11 - 0.5) * 46
                let vy = -48 - CGFloat(index % 3) * 9
                let point = CGPoint(x: 57 + vx * t, y: 20 + vy * t + 62 * t * t)
                outlined(&glitter, star4(point, 2.6 + CGFloat(index % 2)), fill: colors[index % 3], line: 0.9)
            }

        case .mermaidsTears:
            // A little fish leaps right over the bottle.
            let s = CGFloat(e)
            let point = CGPoint(x: 24 + 66 * s, y: 74 - 270 * s * (1 - s))
            let heading = atan2(Double(-270 * (1 - 2 * s)), 66)
            var fish = layer
            fish.translateBy(x: point.x, y: point.y)
            fish.rotate(by: .radians(heading))
            var tail = Path()
            tail.move(to: CGPoint(x: -4, y: 0))
            tail.addLine(to: CGPoint(x: -9, y: -4 + CGFloat(sin(time * 30))))
            tail.addLine(to: CGPoint(x: -9, y: 4 + CGFloat(sin(time * 30))))
            tail.closeSubpath()
            outlined(&fish, tail, fill: color(1.00, 0.62, 0.30), line: 1.3)
            outlined(&fish, Path(ellipseIn: CGRect(x: -5.5, y: -3.4, width: 11, height: 6.8)), fill: color(1.00, 0.48, 0.36), line: 1.4)
            fish.fill(circle(CGPoint(x: 2.6, y: -0.8), 0.9), with: .color(ink))
            // Splashes where it leaves and where it lands.
            for (start, x) in [(0.0, 24.0), (0.72, 90.0)] {
                let t = (e - start) / 0.28
                guard t > 0, t < 1 else { continue }
                for k in 0..<4 {
                    let vx = (Double(k) - 1.5) * 9
                    let drop = CGPoint(x: x + vx * t, y: 74 - 22 * t + 30 * t * t)
                    layer.fill(circle(drop, 1.6 * CGFloat(1 - t * 0.5)), with: .color(color(0.25, 0.70, 1.00, 1 - t)))
                }
            }

        case .witchsBrew:
            // It bubbles over, and a skull of green smoke floats up.
            var drips = Path()
            let length = 20 * CGFloat(min(1, e * 1.6))
            drips.move(to: CGPoint(x: 49, y: 27))
            drips.addLine(to: CGPoint(x: 48.5, y: 27 + length))
            drips.move(to: CGPoint(x: 65, y: 27))
            drips.addLine(to: CGPoint(x: 65.5, y: 27 + length * 0.7))
            var ooze = layer
            ooze.opacity = e < 0.8 ? 1 : (1 - e) / 0.2
            ooze.stroke(drips, with: .color(ink), style: StrokeStyle(lineWidth: 5.6, lineCap: .round))
            ooze.stroke(drips, with: .color(color(0.62, 1.00, 0.22)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            var skull = layer
            skull.translateBy(x: 57 + CGFloat(sin(time * 3)) * 2, y: 14 - CGFloat(e) * 24)
            let size = 0.5 + 0.6 * CGFloat(min(1, e * 2))
            skull.scaleBy(x: size, y: size)
            skull.opacity = e < 0.6 ? 0.95 : 0.95 * (1 - e) / 0.4
            let head = circle(.zero, 8)
            let jaw = Path(roundedRect: CGRect(x: -4.5, y: 4, width: 9, height: 5.5), cornerRadius: 2)
            for part in [jaw, head] { skull.stroke(part, with: .color(ink), lineWidth: 3.4) }
            for part in [jaw, head] { skull.fill(part, with: .color(color(0.62, 0.98, 0.32))) }
            skull.fill(circle(CGPoint(x: -3.2, y: 0), 2.3), with: .color(ink))
            skull.fill(circle(CGPoint(x: 3.2, y: 0), 2.3), with: .color(ink))
            var teeth = Path()
            for x in [-1.5, 1.5] {
                teeth.move(to: CGPoint(x: x, y: 6))
                teeth.addLine(to: CGPoint(x: x, y: 9.5))
            }
            skull.stroke(teeth, with: .color(ink), lineWidth: 1.1)

        case .phoenixFlame:
            // A ring of fire bursts out as the flame surges (see drawFlame).
            for index in 0..<10 {
                let angle = Double(index) / 10 * 2 * .pi + time
                let radius = 6 + CGFloat(e) * 40
                let point = CGPoint(x: 57 + radius * CGFloat(cos(angle)), y: 24 + radius * 0.35 * CGFloat(sin(angle)))
                var ember = layer
                ember.opacity = 1 - e
                outlined(&ember, leaf(CGPoint(x: point.x, y: point.y + 3), CGPoint(x: point.x, y: point.y - 4), width: 2.6),
                         fill: index % 2 == 0 ? color(1.00, 0.80, 0.20) : color(1.00, 0.45, 0.08), line: 1)
            }

        case .moonlightNectar:
            // The moon turns a somersault (see drawCrescent) and scatters stars.
            for index in 0..<8 {
                let angle = Double(index) / 8 * 2 * .pi
                let radius = 6 + CGFloat(e) * 26
                let point = CGPoint(x: 88 + radius * CGFloat(cos(angle)), y: 30 + radius * CGFloat(sin(angle)))
                let size = 3 * CGFloat(1 - e)
                guard size > 0.3 else { continue }
                outlined(&layer, star4(point, size + 0.6), fill: color(1.00, 0.96, 0.70), line: 0.9)
            }

        case .goblinGrog:
            // A big burp bubble swells up out of the grog, then pops.
            if e < 0.75 {
                let t = CGFloat(e / 0.75)
                let radius = 2 + 8 * t
                let center = CGPoint(x: 62 + CGFloat(sin(time * 5)) * 2, y: surface - radius - t * 22)
                outlined(&layer, circle(center, radius), fill: color(0.62, 0.72, 0.25, 0.85), line: 1.8)
                layer.fill(circle(CGPoint(x: center.x - radius * 0.4, y: center.y - radius * 0.4), radius * 0.25), with: .color(.white.opacity(0.8)))
            } else {
                let t = CGFloat((e - 0.75) / 0.25)
                let center = CGPoint(x: 62, y: surface - 32)
                var pop = Path()
                for k in 0..<8 {
                    let angle = Double(k) / 8 * 2 * .pi
                    pop.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * (6 + t * 6), y: center.y + CGFloat(sin(angle)) * (6 + t * 6)))
                    pop.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * (10 + t * 9), y: center.y + CGFloat(sin(angle)) * (10 + t * 9)))
                }
                layer.stroke(pop, with: .color(color(0.40, 0.55, 0.10, 1 - Double(t))), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

        case .unicornTears:
            // The horn flashes and fires a stream of rainbow stars.
            let tip = CGPoint(x: 79.6, y: -1.8)
            var flash = layer
            flash.addFilter(.blur(radius: 3))
            flash.fill(circle(tip, 7 * CGFloat(bump(e * 1.5))), with: .color(.white))
            let rainbow = [
                color(1.00, 0.36, 0.40), color(1.00, 0.66, 0.25), color(1.00, 0.92, 0.35),
                color(0.45, 0.88, 0.45), color(0.35, 0.68, 1.00), color(0.66, 0.45, 1.00),
            ]
            for k in 0..<6 {
                let t = e * 1.6 - Double(k) * 0.12
                guard t > 0, t < 1 else { continue }
                let point = CGPoint(x: tip.x + CGFloat(t) * (26 + CGFloat(k) * 2), y: tip.y - 26 * CGFloat(t) + 52 * CGFloat(t * t))
                outlined(&layer, star4(point, 3.4 * CGFloat(1 - t * 0.5)), fill: rainbow[k], line: 0.9)
            }

        case .voidEssence:
            // Everything nearby gets sucked into the void, then it flashes.
            let pull = easeInOut(min(1, e / 0.8))
            for index in 0..<12 {
                let start = Double(index) / 12 * 2 * .pi
                let radius = 48 * CGFloat(1 - pull) + 2
                let angle = start + pull * 4
                let point = CGPoint(x: 57 + radius * CGFloat(cos(angle)), y: 71 + radius * 0.8 * CGFloat(sin(angle)))
                layer.fill(circle(point, 1.8), with: .color(index % 2 == 0 ? color(0.85, 0.60, 1.00) : .white))
            }
            if e > 0.8 {
                let t = (e - 0.8) / 0.2
                layer.stroke(circle(CGPoint(x: 57, y: 71), 22 + CGFloat(t) * 18),
                             with: .color(color(0.80, 0.50, 1.00, 1 - t)), lineWidth: 3 * CGFloat(1 - t) + 0.5)
            }

        case .frozenFrostbite:
            // A blast of cold: the glass flashes white and ice shards fly out.
            layer.fill(glass.bowl, with: .color(.white.opacity(0.4 * bump(e))))
            for index in 0..<8 {
                let angle = -.pi + Double(index) / 7 * .pi
                let distance = 10 + CGFloat(e) * 36
                let point = CGPoint(x: 57 + distance * CGFloat(cos(angle)), y: 40 + distance * 0.8 * CGFloat(sin(angle)))
                var shard = layer
                shard.translateBy(x: point.x, y: point.y)
                shard.rotate(by: .radians(angle + .pi / 2))
                shard.opacity = 1 - e
                var diamond = Path()
                diamond.addLines([CGPoint(x: 0, y: -5), CGPoint(x: 2.2, y: 0), CGPoint(x: 0, y: 4), CGPoint(x: -2.2, y: 0)])
                diamond.closeSubpath()
                outlined(&shard, diamond, fill: color(0.84, 0.98, 1.00), line: 1.2)
            }
            drawSnowflake(&layer, at: CGPoint(x: 57, y: 12 - CGFloat(e) * 10), radius: 4 + 6 * CGFloat(bump(e)),
                          spin: time * 3, alpha: bump(e))

        default:
            break
        }
    }

    // MARK: Around the drink

    /// Effects that stay put while the drink hops and shrinks: a magic poof as
    /// it appears and disappears, and sparkles kicked up each time it lands.
    /// Drawn in the design square, not in the drink's moving frame.
    static func drawAround(
        _ ctx: inout GraphicsContext, drink: Drink, time: Double, phase: MugPhase, phaseTime: Double,
        energy: Double, beat: Double
    ) {
        guard let glow = aura(drink) else { return }
        if time < 0.5 {
            poof(&ctx, color: glow, progress: time / 0.5, from: 8, to: 52)
        }
        if phase == .leaving {
            poof(&ctx, color: glow, progress: min(1, phaseTime / 0.22), from: 6, to: 40)
        }
        if phase == .listening, time > 0.5 {
            let age = time.truncatingRemainder(dividingBy: beat) / 0.24
            guard age < 1 else { return }
            for side in [-1.0, 1.0] {
                for k in 0..<2 {
                    let reach = CGFloat(age) * (14 + CGFloat(k) * 8)
                    let point = CGPoint(
                        x: 57 + CGFloat(side) * (18 + reach),
                        y: 92 - CGFloat(sin(age * .pi)) * (5 + CGFloat(k) * 4))
                    let size = CGFloat(1 - age) * CGFloat(1.4 + 1.6 * energy)
                    guard size > 0.4 else { continue }
                    outlined(&ctx, star4(point, size + 0.5), fill: k == 0 ? glow : .white, line: 0.8)
                }
            }
        }
    }

    private static func poof(_ ctx: inout GraphicsContext, color glow: Color, progress: Double, from: CGFloat, to: CGFloat) {
        let t = CGFloat(progress)
        let radius = from + (to - from) * CGFloat(easeOutCubic(progress))
        let center = CGPoint(x: 57, y: 60)
        var puff = ctx
        puff.opacity = Double(1 - t)
        for index in 0..<10 {
            let angle = Double(index) / 10 * 2 * .pi + 0.3
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * 0.85 * CGFloat(sin(angle)))
            if index % 2 == 0 {
                outlined(&puff, star4(point, 4.5 * (1 - t * 0.5)), fill: glow, line: 1)
            } else {
                outlined(&puff, circle(point, 3.6 * (1 - t * 0.6)), fill: .white, line: 1.2)
            }
        }
    }

    private static func easeOutCubic(_ x: Double) -> Double {
        1 - pow(1 - min(1, max(0, x)), 3)
    }
}
