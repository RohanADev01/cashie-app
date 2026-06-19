import SwiftUI

/// A short, friendly chat with Cashie that replaces the old tap-the-chips
/// screen. Cashie keeps it conversational, brief, and all-lowercase; the user
/// answers with upbeat, expressive replies, and Cashie acknowledges each one.
/// The arc surfaces the money insight, teases the rank progression (bronze →
/// legendary, with real rank emblems), then hands off to the quiz. Picked
/// replies are still stored in `relatabilityChips`.
///
/// UI is a modern messenger: a green app bar matching the reply pills, a
/// "welcome to cashie" system notice, grouped bubbles with a tail on the last
/// of a run, the avatar only on the last incoming bubble, a live "typing…"
/// status, and reply options + CTA inside the scroll so they flow with the chat.
struct RelatabilityScreen: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var state: OnboardingState

    @State private var messages: [ChatLine] = []
    @State private var choices: [Reply] = []
    @State private var choiceIndex = 0
    @State private var isTyping = false
    @State private var finished = false
    @State private var started = false
    @State private var auto = false
    /// Header style: 1 = white/clean, 2 = green bar (matches the pills, default).
    /// DEBUG-overridable via `-chatStyle N` for design comparisons.
    @State private var styleID = 2

    private struct Reply {
        let text: String
        let ack: String   // "" = none
    }

    private enum Beat {
        case bot(String)
        case rankRail        // the bronze → legendary emblem showcase
        case choice([Reply])
        case finish(String)
    }

    private let script: [Beat] = [
        .bot("hey! i'm cashie 👋"),
        .bot("quick chat before your quiz?"),
        .choice([
            Reply(text: "sure!", ack: ""),
            Reply(text: "go for it!", ack: ""),
        ]),
        .bot("when you check your bank balance, how do you feel?"),
        .choice([
            Reply(text: "a bit stressed 😬", ack: "totally normal, and very fixable."),
            Reply(text: "i try not to look 🙈", ack: "you're not alone there 😅"),
            Reply(text: "pretty good 😌", ack: "love that. let's keep it that way."),
        ]),
        .bot("did you know most people lose around $2,000 a year to spending they don't even notice?"),
        .choice([
            Reply(text: "no idea 😳", ack: "yeah, it sneaks up on everyone."),
            Reply(text: "kind of figured 😅", ack: "right? it adds up fast."),
            Reply(text: "that's scary 😩", ack: "good news is it's easy to catch."),
        ]),
        .bot("how's saving going for you?"),
        .choice([
            Reply(text: "haven't started 😅", ack: "no stress, starting is the hardest part."),
            Reply(text: "it never lasts 😩", ack: "that's usually the plan, not you."),
            Reply(text: "could be better 🤷", ack: "honestly, same as most people."),
        ]),
        .bot("the real fix isn't willpower, it's seeing where it goes 👀"),
        .bot("so, what would help you the most right now?"),
        .choice([
            Reply(text: "knowing what's safe to spend", ack: "perfect, that's exactly what cashie shows you."),
            Reply(text: "saving more easily", ack: "love it, cashie makes saving feel simple."),
            Reply(text: "seeing where it goes", ack: "easy, cashie shows you exactly where it goes."),
        ]),
        .bot("oh, and it actually gets pretty fun 👀"),
        .bot("as you log your spends, you climb through ranks 🏆"),
        .choice([
            Reply(text: "ranks?", ack: ""),
            Reply(text: "tell me more!", ack: ""),
        ]),
        .rankRail,
        .bot("everyone starts at bronze. stick with it and you'll reach legendary 👑"),
        .finish("you'll basically be a money expert by then. ready? 👀"),
    ]

    /// Sent bubbles match the reply pills (brand green); received are light grey.
    private let outgoingFill = Theme.Palette.gold
    private let incomingFill = Color(hex: 0xF0F0F3)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            systemNotice(currentDateLabel)
                                .padding(.bottom, 12)
                            ForEach(Array(messages.enumerated()), id: \.element.id) { idx, line in
                                messageRow(idx, line)
                                    .padding(.top, isRunStart(idx) ? 8 : 0)
                            }
                            if isTyping {
                                typingRow.padding(.top, (messages.last?.bot == false) ? 8 : 0)
                            }
                            if !choices.isEmpty {
                                choicesView.padding(.top, 12)
                            }
                            if finished {
                                ctaView.padding(.top, 14)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: messages.count) { _ in scrollDown(proxy) }
                    .onChange(of: isTyping) { _ in scrollDown(proxy) }
                    .onChange(of: choices.count) { _ in scrollDown(proxy) }
                    .onChange(of: finished) { _ in scrollDown(proxy) }
                }
            }
        }
        .onAppear(perform: start)
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(Theme.Motion.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
        // Second pass after layout settles (reply pills clearing, a bubble
        // animating in) so a tapped reply always lands us at the true bottom.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    /// Today's date, shown as a chat date-separator (e.g. "10 June 2026").
    private var currentDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: Date())
    }

    /// Centered grey "system" line like WhatsApp/Instagram date separators.
    private func systemNotice(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(AppFont.text(11, weight: .medium))
                .foregroundColor(Theme.Palette.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.05)))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var header: some View {
        let green = styleID == 2
        let barColor: Color = green ? Theme.Palette.gold : .clear
        let titleColor: Color = green ? .white : Theme.Palette.ink
        let statusColor: Color = green ? Color.white.opacity(0.9) : Theme.Palette.inkSoft
        let typingColor: Color = green ? .white : Theme.Palette.gold
        let skipColor: Color = green ? Color.white.opacity(0.85) : Theme.Palette.inkMute
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    avatar(48, bg: green ? .white : Theme.Palette.goldPastel)
                    Circle().fill(green ? Color.white : Color(hex: 0x2ED477))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(green ? Theme.Palette.gold : Color.white, lineWidth: 2.5))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cashie")
                        .font(AppFont.text(20, weight: .bold))
                        .foregroundColor(titleColor)
                    Text(isTyping ? "typing…" : "active now")
                        .font(AppFont.text(13, weight: .medium))
                        .foregroundColor(isTyping ? typingColor : statusColor)
                        .animation(.easeInOut(duration: 0.2), value: isTyping)
                }
                Spacer()
                Button(action: handOff) {
                    Text("skip")
                        .font(AppFont.text(14, weight: .semibold))
                        .foregroundColor(skipColor)
                }
                .buttonStyle(.plainTappable)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .background(barColor.ignoresSafeArea(edges: .top))

            if green {
                Color.black.opacity(0.06).frame(height: 1)
            } else {
                Rectangle().fill(Theme.Palette.line).frame(height: 1)
            }
        }
    }

    // MARK: - Reply options + CTA (inside the scroll)

    private var choicesView: some View {
        VStack(spacing: 8) {
            ForEach(choices, id: \.text) { reply in
                HStack {
                    Spacer(minLength: 44)
                    Button { pick(reply) } label: {
                        Text(reply.text)
                            .font(AppFont.text(15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .multilineTextAlignment(.trailing)
                            .background(Capsule().fill(Theme.Palette.gold))
                            .shadow(color: Theme.Palette.gold.opacity(0.25), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plainTappable)
                }
            }
        }
        .padding(.horizontal, 16)
        .transition(.opacity)
    }

    private var ctaView: some View {
        HStack {
            Spacer(minLength: 44)
            Button { handOff() } label: {
                HStack(spacing: 7) {
                    Text("let's do this").font(AppFont.text(15, weight: .bold))
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.Palette.gold))
                .shadow(color: Theme.Palette.gold.opacity(0.30), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.horizontal, 16)
        .transition(.opacity)
    }

    // MARK: - Rows

    @ViewBuilder
    private func messageRow(_ idx: Int, _ line: ChatLine) -> some View {
        switch line.kind {
        case .text(let t):
            textRow(idx, t, bot: line.bot)
        case .rankRail:
            rankRailRow(idx)
                .padding(.horizontal, 16)
        }
    }

    private func textRow(_ idx: Int, _ text: String, bot: Bool) -> some View {
        Group {
            if bot {
                HStack(alignment: .bottom, spacing: 8) {
                    if showAvatar(idx) { avatar(32) }
                    else { Color.clear.frame(width: 32, height: 32) }
                    bubble(text, incoming: true, tail: isRunEnd(idx))
                    Spacer(minLength: 44)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                HStack {
                    Spacer(minLength: 44)
                    bubble(text, incoming: false, tail: isRunEnd(idx))
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
    }

    /// The rank showcase: a horizontal rail of the real rank emblems
    /// (bronze → legendary), animated, so the climb feels tangible.
    private func rankRailRow(_ idx: Int) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if showAvatar(idx) { avatar(32) }
            else { Color.clear.frame(width: 32, height: 32) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Rank.allCases) { rank in
                        VStack(spacing: 0) {
                            RankBadgeView(rank: rank, size: 34, animated: true, showsAura: false)
                                .frame(width: 52, height: 52)
                            Text(rank.title.lowercased())
                                .font(AppFont.text(9, weight: .semibold))
                                .foregroundColor(Theme.Palette.inkSoft)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(incomingFill))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
            Spacer(minLength: 8)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var typingRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            avatar(32)
            TypingDots()
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(bubbleShape(incoming: true, tail: true).fill(incomingFill))
                .overlay(bubbleShape(incoming: true, tail: true).stroke(Color.black.opacity(0.05), lineWidth: 1))
            Spacer(minLength: 44)
        }
        .padding(.horizontal, 16)
        .transition(.opacity)
    }

    // MARK: - Bubble + avatar

    private func avatar(_ size: CGFloat, bg: Color = Theme.Palette.goldPastel) -> some View {
        Image("Mascot")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .background(Circle().fill(bg))
            .clipShape(Circle())
    }

    private func bubble(_ text: String, incoming: Bool, tail: Bool) -> some View {
        Text(text)
            .font(AppFont.text(15, weight: .medium))
            .foregroundColor(incoming ? Theme.Palette.ink : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleShape(incoming: incoming, tail: tail).fill(incoming ? incomingFill : outgoingFill))
            .overlay {
                if incoming {
                    bubbleShape(incoming: true, tail: tail).stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }

    private func bubbleShape(incoming: Bool, tail: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: incoming ? (tail ? 5 : 20) : 20,
            bottomTrailingRadius: incoming ? 20 : (tail ? 5 : 20),
            topTrailingRadius: 20,
            style: .continuous
        )
    }

    // MARK: - Grouping helpers

    private func isRunStart(_ idx: Int) -> Bool {
        idx > 0 && messages[idx].bot != messages[idx - 1].bot
    }

    private func isRunEnd(_ idx: Int) -> Bool {
        idx == messages.count - 1 || messages[idx + 1].bot != messages[idx].bot
    }

    private func showAvatar(_ idx: Int) -> Bool {
        guard messages[idx].bot, isRunEnd(idx) else { return false }
        if isTyping && idx == messages.count - 1 { return false }
        return true
    }

    // MARK: - Conversation driver

    private func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        auto = args.contains("-chatAuto")
        if let i = args.firstIndex(of: "-chatStyle"), i + 1 < args.count, let n = Int(args[i + 1]) {
            styleID = n
        }
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { play(0) }
    }

    private func play(_ i: Int) {
        guard i < script.count else { return }
        switch script[i] {
        case .bot(let t):
            typeThen(t) {
                appendBot(.text(t))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { play(i + 1) }
            }
        case .rankRail:
            withAnimation { isTyping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { isTyping = false }
                appendBot(.rankRail)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { play(i + 1) }
            }
        case .finish(let t):
            typeThen(t) {
                appendBot(.text(t))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(Theme.Motion.smooth) { finished = true }
                }
            }
        case .choice(let replies):
            choiceIndex = i
            withAnimation(Theme.Motion.snap) { choices = replies }
            #if DEBUG
            if auto, let first = replies.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    if !choices.isEmpty { pick(first) }
                }
            }
            #endif
        }
    }

    private func typeThen(_ text: String, _ done: @escaping () -> Void) {
        withAnimation { isTyping = true }
        let delay = min(1.8, 0.55 + Double(text.count) * 0.016)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { isTyping = false }
            done()
        }
    }

    private func appendBot(_ kind: LineKind) {
        withAnimation(Theme.Motion.snap) { messages.append(ChatLine(kind: kind, bot: true)) }
    }

    private func pick(_ reply: Reply) {
        withAnimation(Theme.Motion.snap) {
            messages.append(ChatLine(kind: .text(reply.text), bot: false))
            choices = []
        }
        state.relatabilityChips.insert(reply.text)
        let next = choiceIndex + 1
        if reply.ack.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { play(next) }
        } else {
            let ack = reply.ack
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                typeThen(ack) {
                    appendBot(.text(ack))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { play(next) }
                }
            }
        }
    }

    private func handOff() {
        container.advanceOnboarding(to: .intro)
    }
}

private enum LineKind: Equatable {
    case text(String)
    case rankRail
}

private struct ChatLine: Identifiable {
    let id = UUID()
    let kind: LineKind
    let bot: Bool
}

/// Three dots with a staggered bounce, the way WhatsApp / iMessage read "typing".
private struct TypingDots: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.Palette.inkSoft.opacity(0.55))
                    .frame(width: 7, height: 7)
                    .offset(y: bounce ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15),
                        value: bounce
                    )
            }
        }
        .onAppear { bounce = true }
    }
}

/// Tiny wrap layout, we don't pull in a 3rd-party FlexibleStack.
/// Shared by the QuickLog / AddGoal / AddTransaction sheets, so it lives here.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, totalH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxW {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        totalH = y + lineHeight
        return CGSize(width: maxW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + s.width > maxW {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}
