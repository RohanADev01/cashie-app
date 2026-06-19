import SwiftUI

/// The rank screen, presented as a dark stage themed to the user's current
/// tier. Instead of a vertical ladder, ranks live in a horizontal snapping
/// carousel: the current rank sits centered and full, its neighbours peek in
/// from the sides, and you can swipe between them. Each rank carries a 3D
/// title in its own colour, and ranks you haven't reached yet are faded.
struct RanksLadderSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var showBadges = false
    @State private var centeredIndex: Int = 0

    private var progress: RankProgress { container.rankProgress }
    private var rank: Rank { progress.current }
    private var centeredRank: Rank { Rank(rawValue: centeredIndex) ?? rank }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    closeBar
                    header
                    RankCarousel(currentRank: rank) { centeredIndex = $0 }
                    centeredInfo
                    badgesEntry
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showBadges) {
            BadgesSheet()
        }
    }

    // MARK: - Close

    private var closeBar: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plainTappable)
        }
    }

    // MARK: - Background (themed to the current rank)

    private var background: some View {
        ZStack {
            Color(hex: 0x08090B)
            RadialGradient(
                colors: [rank.glow.opacity(0.42), .clear],
                center: .top, startRadius: 10, endRadius: 480
            )
            RadialGradient(
                colors: [rank.midtone.opacity(0.10), .clear],
                center: .bottom, startRadius: 10, endRadius: 340
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(AppFont.text(11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.5))
            EmphasizedHeadline(
                raw: "Your <em>rank.</em>",
                font: AppFont.display(36, weight: .bold),
                emColor: rank.midtone
            )
            .foregroundColor(.white)
            Text("Swipe through the ranks. Earn XP every time you log to climb.")
                .font(AppFont.text(13))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 2)
        }
    }

    // MARK: - Info for the rank currently centered in the carousel

    private var centeredInfo: some View {
        VStack(spacing: 12) {
            Text(centeredRank.tagline)
                .font(AppFont.text(13, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
            centeredStatus
                .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: centeredIndex)
    }

    // Every state uses the same thick interval bar, coloured to the selected
    // rank, so the screen stays on-theme: the current rank fills toward the
    // next, ranks already earned show a fully completed bar, and ranks not yet
    // reached show an empty one.
    @ViewBuilder
    private var centeredStatus: some View {
        if centeredRank == rank {
            statusBar(
                tier: rank,
                fraction: progress.fraction,
                leading: "\(formatted(progress.xp)) XP",
                trailing: progress.isMaxed
                    ? "Top rank reached"
                    : "\(formatted(progress.xpToNext)) XP to \(progress.next?.title ?? "")",
                trailingColor: progress.isMaxed ? rank.highlight : .white.opacity(0.85)
            )
        } else if centeredRank < rank {
            statusBar(
                tier: centeredRank,
                fraction: 1.0,
                leading: "\(formatted(centeredRank.threshold)) XP",
                trailing: "Achieved",
                trailingColor: centeredRank.midtone
            )
        } else {
            statusBar(
                tier: centeredRank,
                fraction: 0,
                leading: "Locked",
                trailing: "\(formatted(max(0, centeredRank.threshold - container.rankXP))) XP to reach",
                trailingColor: .white.opacity(0.7)
            )
        }
    }

    private func statusBar(tier: Rank, fraction: Double,
                           leading: String, trailing: String,
                           trailingColor: Color) -> some View {
        VStack(spacing: 10) {
            RankProgressBar(rank: tier, fraction: fraction)
            HStack {
                Text(leading)
                    .font(AppFont.text(12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(trailing)
                    .font(AppFont.text(12, weight: .semibold))
                    .foregroundColor(trailingColor)
            }
        }
    }

    // MARK: - Badges entry

    private var badgesEntry: some View {
        Button { showBadges = true } label: {
            HStack(spacing: 14) {
                badgeCluster
                VStack(alignment: .leading, spacing: 3) {
                    Text("Badges")
                        .font(AppFont.text(16, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(container.earnedBadgeCount) of \(Badge.all.count) earned · tap to chase more XP")
                        .font(AppFont.text(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
    }

    private var badgeCluster: some View {
        let preview = Array(Badge.all.prefix(4))
        return ZStack {
            ForEach(Array(preview.enumerated()), id: \.element.id) { idx, badge in
                BadgeView(badge: badge, unlocked: container.isBadgeUnlocked(badge), size: 34)
                    .offset(x: CGFloat(idx) * 18)
            }
        }
        .frame(width: 34 + 18 * 3, alignment: .leading)
    }

    private var footer: some View {
        Text("Ranks are earned, never lost. Keep logging and the climb takes care of itself.")
            .font(AppFont.text(12))
            .foregroundColor(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func formatted(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Horizontal snapping rank carousel

private struct RankCarousel: View {
    let currentRank: Rank
    var onCenterChange: (Int) -> Void

    @State private var index: Int
    @State private var drag: CGFloat = 0

    private let ranks = Rank.allCases

    init(currentRank: Rank, onCenterChange: @escaping (Int) -> Void) {
        self.currentRank = currentRank
        self.onCenterChange = onCenterChange
        _index = State(initialValue: currentRank.rawValue)
    }

    var body: some View {
        GeometryReader { geo in
            let itemWidth = geo.size.width * 0.56
            let spacing: CGFloat = 12
            let step = itemWidth + spacing
            let centerOffset = (geo.size.width - itemWidth) / 2
            // Fractional position so items scale/fade smoothly while dragging.
            let position = CGFloat(index) - (drag / step)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(ranks) { rank in
                    item(rank, position: position)
                        .frame(width: itemWidth)
                }
            }
            .frame(height: geo.size.height)
            .offset(x: -CGFloat(index) * step + drag + centerOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { drag = $0.translation.width }
                    .onEnded { value in
                        // Snap to the nearest rank, biased by fling velocity.
                        let predicted = value.predictedEndTranslation.width
                        let move = Int((-predicted / step).rounded())
                        let newIndex = min(max(0, index + move), ranks.count - 1)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            index = newIndex
                            drag = 0
                        }
                    }
            )
        }
        .frame(height: 292)
        .onAppear { onCenterChange(index) }
        .onChange(of: index) { onCenterChange($0) }
    }

    @ViewBuilder
    private func item(_ rank: Rank, position: CGFloat) -> some View {
        let distance = abs(CGFloat(rank.rawValue) - position)
        let isCurrentRank = (rank == currentRank)
        // Distance gives the centred item focus; the user's *current* rank gets
        // a persistent size boost on top, so it stays the biggest badge and is
        // easy to pick out even after swiping away from it.
        let scale = max(0.56, 1.10 - distance * 0.44) * (isCurrentRank ? 1.16 : 1.0)
        let achieved = rank <= currentRank
        // All rank badges render at full strength (only a gentle distance fade
        // for the peeking neighbours); locked ranks are no longer dimmed.
        let opacity = 1 - min(0.5, distance * 0.34)
        // Only the settled centre badge animates, and only once it's been
        // achieved; locked ranks stay completely static even when centred.
        let liveBadge = (rank.rawValue == index) && achieved

        VStack(spacing: 6) {
            RankBadgeView(rank: rank, size: 104,
                          animated: liveBadge, showsAura: liveBadge)
                .frame(height: 178)
            Rank3DText(rank: rank, size: 30)
        }
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

// MARK: - Thick, interval-ticked XP bar in the current rank's colour

private struct RankProgressBar: View {
    let rank: Rank
    let fraction: Double
    var height: CGFloat = 18
    var segments: Int = 10

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let clamped = min(1, max(0, fraction))
            // No colour nub at 0; otherwise floor the fill so it reads cleanly.
            let fillWidth = clamped <= 0.001 ? 0 : max(height, w * CGFloat(clamped))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [rank.highlight, rank.midtone],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .shadow(color: rank.glow.opacity(0.6), radius: 5)

                // Evenly spaced interval notches across the whole bar.
                HStack(spacing: 0) {
                    ForEach(1..<segments, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color(hex: 0x08090B).opacity(0.55))
                            .frame(width: 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, height / 2)
            }
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(height: height)
    }
}

// MARK: - 3D extruded rank title, coloured to the rank

private struct Rank3DText: View {
    let rank: Rank
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            // Stacked darker copies form the extruded "side" of the letters.
            ForEach(Array(stride(from: 3, through: 1, by: -1)), id: \.self) { d in
                Text(rank.title)
                    .font(AppFont.display(size, weight: .heavy))
                    .foregroundColor(rank.shadow)
                    .offset(y: CGFloat(d))
            }
            // Bright front face in the rank's own gradient.
            Text(rank.title)
                .font(AppFont.display(size, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rank.highlight, rank.midtone],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 4)
        .fixedSize()
    }
}
