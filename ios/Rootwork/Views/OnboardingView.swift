import SwiftUI
import FamilyControls

/// First launch: the promise, the rings, app rest, and reminders. Four pages, all skippable.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GateService.self) private var gate
    @Environment(Library.self) private var library
    @AppStorage("onboarded") private var onboarded = false
    @State private var page = 0
    @State private var demo = [0, 0, 0]
    @State private var showPicker = false

    var body: some View {
        TabView(selection: $page) {
            welcome.tag(0)
            rings.tag(1)
            rest.tag(2)
            ready.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(page == 0 ? Color.black : Color(.systemGroupedBackground))
        .ignoresSafeArea()
        .familyActivityPicker(isPresented: $showPicker, selection: Bindable(gate).selection)
    }

    private var welcome: some View {
        ZStack(alignment: .bottom) {
            ArtBackground(art: "spirit").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("“Remain in me, and I in you.”").font(Fonts.word(38, weight: .semibold))
                Text("John 15:4").font(.headline).opacity(0.85)
                Text("A daily place to pray, read, write, and remember. Twenty minutes with the Father before the rest of your phone.")
                    .font(.body).opacity(0.9)
                nextButton("Begin", tint: .white.opacity(0.25))
            }
            .foregroundStyle(.white)
            .padding(28).padding(.bottom, 40)
        }
    }

    private var rings: some View {
        onboardingPage(title: "Close three rings.",
             text: "Pray to the Father. Read the Son, the Word made flesh. Write what the Spirit shows you. Six small steps, about twenty minutes.") {
            TrinityRings(progress: demo, lineWidth: 18).frame(width: 220)
                .task(id: page) {
                    guard page == 1 else { return }
                    demo = [0, 0, 0]
                    for step in [[1, 0, 0], [1, 1, 0], [1, 1, 3], [2, 1, 3]] {
                        try? await Task.sleep(for: .milliseconds(700))
                        demo = step
                    }
                }
        } extra: { EmptyView() }
    }

    private var rest: some View {
        onboardingPage(title: "Let your apps rest.",
             text: "Pick the games and social apps that pull you away. They wait each morning until your rings close. You get three emergency opens a week.") {
            Image(systemName: "lock.app.dashed").font(.system(size: 90)).foregroundStyle(Trinity.son.color)
        } extra: {
            Button(gate.isAuthorized ? "Choose apps (\(gate.restingCount))" : "Choose apps") {
                Task { if !gate.isAuthorized { await gate.authorize() }; showPicker = true }
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }

    private var ready: some View {
        onboardingPage(title: "Every morning, a verse.",
             text: "We'll send one at 6:00, nudge you in the evening if your rings are open, and remind you of Night watch at 9:30. Change the times anytime in You.") {
            Image(systemName: "bell.badge").font(.system(size: 80)).foregroundStyle(Trinity.father.color)
        } extra: { EmptyView() }
    }

    private func onboardingPage<Hero: View, Extra: View>(title: String, text: String, @ViewBuilder hero: () -> Hero,
                                               @ViewBuilder extra: () -> Extra) -> some View {
        VStack(spacing: 22) {
            Spacer()
            hero()
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.largeTitle.bold())
                Text(text).font(.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            extra()
            nextButton(page == 3 ? "Start" : "Continue", tint: Color(.label))
        }
        .padding(28).padding(.bottom, 40)
    }

    private func nextButton(_ title: String, tint: Color) -> some View {
        Button {
            if page < 3 { withAnimation { page += 1 } } else {
                Reminders.reschedule(library: library)
                onboarded = true
                dismiss()
            }
        } label: { Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8) }
        .buttonStyle(.glassProminent).tint(tint)
    }
}
