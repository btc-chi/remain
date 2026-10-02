import SwiftUI

/// The walking guide, as a small library inside the Bible tab.
struct GuideView: View {
    @Environment(Library.self) private var library

    var body: some View {
        List {
            Section {
                ZStack(alignment: .bottomLeading) {
                    ArtBackground(art: "spirit")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Root Work").font(Fonts.word(32, weight: .semibold))
                        Text("Stay connected. The vine does the work.").font(Fonts.word(17)).opacity(0.9)
                    }
                    .foregroundStyle(.white).padding(18)
                }
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(library.guide) { a in
                    NavigationLink { ArticleView(article: a) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.title).font(.headline)
                            if !a.note.isEmpty { Text(a.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Walking guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArticleView: View {
    let article: Article
    @Environment(AppNavigation.self) private var nav

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title).font(Fonts.word(34, weight: .semibold))
                if !article.note.isEmpty { Text(article.note).font(.title3).foregroundStyle(.secondary) }
                ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, b in block(b) }
            }
            .padding(.horizontal, 22).padding(.vertical, 12)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func block(_ b: Article.Block) -> some View {
        switch b.type {
        case "heading":
            Text(b.text ?? "").font(.title3.bold()).padding(.top, 10)
        case "scripture":
            Button {
                if let ref = b.ref, let p = BibleService.parse(ref) { nav.read(p.book, p.chapter) }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    if b.lead == true { Capsule().fill(Trinity.father.color).frame(width: 3) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(b.text ?? "").font(Fonts.word(b.lead == true ? 24 : 21)).foregroundStyle(.primary)
                        Text(b.caption ?? b.ref ?? "").font(.footnote.weight(.semibold)).foregroundStyle(Trinity.son.color)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        case "note":
            Text(b.text ?? "").font(.callout)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Trinity.spirit.color.opacity(0.12), in: .rect(cornerRadius: 16))
        case "list", "steps":
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array((b.items ?? []).enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(b.type == "steps" ? "\(i + 1)" : "•").font(.callout.weight(.semibold))
                            .foregroundStyle(Trinity.father.color).frame(width: 18)
                        Text(item).font(.body)
                    }
                }
            }
        case "rows":
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array((b.rows ?? []).enumerated()), id: \.offset) { i, r in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.label).font(.subheadline.weight(.semibold)).foregroundStyle(Trinity.father.color)
                        Text(r.text).font(.body)
                    }
                    .padding(.vertical, 10)
                    if i < (b.rows?.count ?? 0) - 1 { Divider() }
                }
            }
        case "map":
            ScrollView(.horizontal) {
                Text(b.text ?? "").font(.system(size: 12, design: .monospaced)).padding(14)
            }
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        default:
            Text(b.text ?? "").font(.body).foregroundStyle(b.dim == true ? .secondary : .primary)
        }
    }
}
