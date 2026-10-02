import SwiftUI

/// Native first: system backgrounds and label colors, SF Pro for UI, New York for Scripture.
/// The only brand colors are the three Trinity colors (see Shared/TrinityShared.swift).
enum Palette {
    static let done = Color(.systemGreen)
    static let wine = Trinity.son.color
    static let dawn = Trinity.father.color
    static let sky = Trinity.spirit.color
}

enum Fonts {
    /// New York, Apple's serif. Used only for Scripture and your own written words.
    static func word(_ size: CGFloat = 19, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// Solid content card on the grouped background. Glass is reserved for controls that float above content.
struct Card<Content: View>: View {
    var radius: CGFloat = 22
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: radius))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.bold())
            Spacer()
            if let trailing { Text(trailing).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 4).padding(.top, 18)
    }
}

/// A verse set in New York with its reference underneath.
struct ScriptureBlock: View {
    let ref: String
    let text: String
    var size: CGFloat = 19

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(Fonts.word(size)).fixedSize(horizontal: false, vertical: true)
            Text(ref).font(.footnote.weight(.semibold)).foregroundStyle(Trinity.son.color)
        }
    }
}

/// Full-bleed art with a darkening gradient, used behind verses and prayers.
struct ArtBackground: View {
    let art: String
    var body: some View {
        // Color.clear sizes to the container; the image fills it without pushing the layout wider.
        Color.clear
            .overlay { Image(art).resizable().scaledToFill() }
            .overlay(LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .black.opacity(0.65)],
                                    startPoint: .top, endPoint: .bottom))
            .clipped()
    }
}

extension View {
    func groupedBackground() -> some View {
        background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

extension String {
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
}
