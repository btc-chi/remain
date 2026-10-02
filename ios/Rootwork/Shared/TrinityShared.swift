import SwiftUI

/// Shared by the app and the widgets: the three persons, their colors, and the rings.
enum Trinity: Int, CaseIterable, Identifiable {
    case father, son, spirit
    var id: Int { rawValue }

    var color: Color {
        switch self {
        case .father: Color(light: 0xE2A72E, dark: 0xF0B840)   // gold: the halo
        case .son:    Color(light: 0xD7263D, dark: 0xFF4058)   // crimson: his robe
        case .spirit: Color(light: 0x3FA7E0, dark: 0x5AC8FA)   // sky: the dove
        }
    }
    var act: String { ["Pray", "Read", "Write"][rawValue] }
    var person: String { ["the Father", "the Son", "the Spirit"][rawValue] }
    /// How many of the six Rootwork steps fill this ring.
    var goal: Int { [2, 1, 3][rawValue] }
}

/// Three rings set on the points of a triangle, filling like Activity rings.
/// Father (Pray) on top, Son (Read) bottom-left, Spirit (Write) bottom-right.
/// When all three close, the triangle that joins them appears.
struct TrinityRings: View {
    var progress: [Int]
    var lineWidth: CGFloat = 13
    var showsTriangle = true

    private var complete: Bool { Trinity.allCases.allSatisfy { (progress[safe: $0.rawValue] ?? 0) >= $0.goal } }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s * 0.267
            let centers = [CGPoint(x: s * 0.5, y: s * 0.32),
                           CGPoint(x: s * 0.333, y: s * 0.62),
                           CGPoint(x: s * 0.667, y: s * 0.62)]
            ZStack {
                if showsTriangle {
                    Path { p in p.addLines(centers); p.closeSubpath() }
                        .stroke(Color.primary.opacity(complete ? 0.55 : 0), style: StrokeStyle(lineWidth: lineWidth * 0.18, lineJoin: .round))
                        .animation(.easeInOut(duration: 1).delay(0.6), value: complete)
                }
                ForEach(Trinity.allCases) { p in
                    let fraction = min(1, Double(progress[safe: p.rawValue] ?? 0) / Double(p.goal))
                    ZStack {
                        Circle().stroke(p.color.opacity(0.2), lineWidth: lineWidth)
                        Circle()
                            .trim(from: 0, to: fraction)
                            .stroke(p.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.9, bounce: 0.15), value: fraction)
                    }
                    .frame(width: r * 2, height: r * 2)
                    .position(centers[p.rawValue])
                }
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Pray \(progress[safe: 0] ?? 0) of 2, Read \(progress[safe: 1] ?? 0) of 1, Write \(progress[safe: 2] ?? 0) of 3")
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
