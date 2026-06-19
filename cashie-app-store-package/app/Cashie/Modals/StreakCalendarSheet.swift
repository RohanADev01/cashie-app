import SwiftUI

/// Full-screen streak view reached by tapping the streak card on the You tab.
/// Dark and gamified like the rank page: a living fiery gradient with drifting
/// embers behind a translucent month calendar. Logged days catch fire,
/// shielded days show a shield, missed days sit open. Tap a missed day in a
/// week you logged in (with shields left) to spend a shield and bridge the
/// gap; the streak chain crosses months. Page back to see earlier months.
struct StreakCalendarSheet: View {
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var monthOffset = Self.initialMonthOffset   // 0 = current, -1 = previous, ...

    /// Dev affordance: `-streakMonth -1` opens straight to a past month for screenshots.
    private static var initialMonthOffset: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-streakMonth"), i + 1 < args.count,
           let n = Int(args[i + 1]), n <= 0 {
            return n
        }
        return 0
    }
    @State private var justShielded: String?    // day key mid "redeemed" pop
    @State private var showToast = false
    @State private var toastText = ""
    @State private var toastOK = true
    @State private var toastToken = 0

    private let fire = [Color(hex: 0xFF5E3A), Color(hex: 0xFF823C), Color(hex: 0xFFB24D)]
    private let fireStroke = Color(hex: 0xFF5E3A)
    private let fireAccent = Color(hex: 0xFF7A2E)
    private let shield = [Color(hex: 0x5AB0FF), Color(hex: 0x2F86E8)]
    private let shieldDeep = Color(hex: 0x1E6FD9)

    var body: some View {
        ZStack(alignment: .top) {
            DarkFireBackground(accent: fireAccent, warm: fire[2])
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    hero
                    calendarCard
                    legend
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            // Always mounted; visibility is driven by opacity/offset so the
            // continuously-animating fire circles can't cut its transition short.
            toast
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Your streak")
                .font(AppFont.display(28, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.top, 16)
    }

    // MARK: - Hero (mirrors the You-tab streak card)

    private var hero: some View {
        ZStack {
            LinearGradient(colors: fire, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.32), .clear],
                           center: .topTrailing, startRadius: 4, endRadius: 240)
            RadialGradient(colors: [.black.opacity(0.12), .clear],
                           center: .bottomLeading, startRadius: 4, endRadius: 220)
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22)).frame(width: 60, height: 60)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                }
                VStack(alignment: .leading, spacing: 5) {
                    if container.loggedStreak == 0 {
                        Text("No streak yet")
                            .font(AppFont.display(28, weight: .heavy))
                            .foregroundColor(.white)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(container.loggedStreak)")
                                .font(AppFont.display(42, weight: .heavy))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.45, dampingFraction: 0.8),
                                           value: container.loggedStreak)
                            Text("day streak")
                                .font(AppFont.text(17, weight: .bold))
                                .foregroundColor(.white.opacity(0.92))
                        }
                    }
                    shieldsLine
                }
                Spacer()
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(fireStroke.opacity(0.5), lineWidth: 1))
        .shadow(color: fireStroke.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    private var shieldsLine: some View {
        let left = container.shieldsRemainingInWeek(of: Date())
        return HStack(spacing: 6) {
            Image(systemName: "shield.lefthalf.filled").font(.system(size: 11, weight: .bold))
            Text("\(left) of \(AppContainer.shieldsPerWeek) shields this week")
                .font(AppFont.text(12, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.92))
    }

    // MARK: - Calendar (translucent so the gradient shows through)

    private var calendarCard: some View {
        let logged = container.loggedDayKeys
        let shielded = container.shieldedDayKeys
        return VStack(spacing: 14) {
            monthHeader
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(AppFont.text(10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 10
            ) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell {
                        dayCircle(date: date, logged: logged, shielded: shielded)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var monthHeader: some View {
        HStack {
            navButton("chevron.left", enabled: canGoBack) { step(-1) }
            Spacer()
            Text(monthTitle)
                .font(AppFont.text(14, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.white)
            Spacer()
            navButton("chevron.right", enabled: canGoForward) { step(1) }
        }
    }

    private func navButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(enabled ? .white : .white.opacity(0.25))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plainTappable)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    @ViewBuilder
    private func dayCircle(date: Date, logged: Set<String>, shielded: Set<String>) -> some View {
        let cal = Calendar.current
        let key = container.dayKey(date)
        let isLogged = logged.contains(key)
        let isShielded = shielded.contains(key)
        let isToday = cal.isDateInToday(date)
        let isFuture = cal.startOfDay(for: date) > cal.startOfDay(for: Date())
        let eligible = !isLogged && !isShielded && !isFuture && container.canShield(date)
        let dayNum = cal.component(.day, from: date)
        let popped = justShielded == key

        Button {
            tap(date: date)
        } label: {
            ZStack {
                fill(isLogged: isLogged, isShielded: isShielded, isFuture: isFuture,
                     eligible: eligible, phase: Double(dayNum) * 0.08)
                    .frame(width: 38, height: 38)
                Text("\(dayNum)")
                    .font(AppFont.text(13, weight: isLogged || isShielded ? .bold : .medium))
                    .foregroundColor(numberColor(isLogged: isLogged, isShielded: isShielded,
                                                 isFuture: isFuture, eligible: eligible))
                    .monospacedDigit()
            }
            .frame(height: 42)
            .overlay(alignment: .topTrailing) {
                if isShielded {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(2.5)
                        .background(Circle().fill(shieldDeep))
                        .offset(x: 2, y: -1)
                }
            }
            .overlay {
                if isToday {
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 2).frame(width: 44, height: 44)
                }
                if popped {
                    Circle().stroke(shieldDeep, lineWidth: 2).frame(width: 46, height: 46).opacity(0.7)
                }
            }
            .scaleEffect(popped ? 1.15 : 1.0)
            .animation(.spring(response: 0.34, dampingFraction: 0.5), value: popped)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainTappable)
        .disabled(isFuture || isLogged)
    }

    @ViewBuilder
    private func fill(isLogged: Bool, isShielded: Bool, isFuture: Bool, eligible: Bool, phase: Double) -> some View {
        if isLogged {
            FireCircle(colors: fire, glow: fireAccent, phase: phase)
        } else if isShielded {
            Circle()
                .fill(LinearGradient(colors: shield, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: shieldDeep.opacity(0.6), radius: 6)
        } else if eligible {
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay(Circle().strokeBorder(fireAccent.opacity(0.8),
                                               style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])))
        } else if isFuture {
            Circle().fill(Color.white.opacity(0.03))
        } else {
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func numberColor(isLogged: Bool, isShielded: Bool, isFuture: Bool, eligible: Bool) -> Color {
        if isLogged || isShielded { return .white }
        if eligible { return .white.opacity(0.92) }
        if isFuture { return .white.opacity(0.28) }
        return .white.opacity(0.55)
    }

    private func tap(date: Date) {
        if container.isShielded(date) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                container.removeShield(date)
            }
            return
        }
        if container.canShield(date) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            container.redeemShield(date)
            justShielded = container.dayKey(date)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { justShielded = nil }
            flash(ok: true, "Shield used · streak saved")
            return
        }
        if let reason = container.shieldBlockReason(date) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            flash(ok: false, reason)
        }
    }

    private func flash(ok: Bool, _ text: String) {
        toastText = text
        toastOK = ok
        toastToken += 1
        let token = toastToken
        showToast = true   // the toast view animates itself via .animation(value:)
        // Hold ~2.8s. The token guard means a newer toast won't be dismissed
        // early by an older timer if shields are tapped in quick succession.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard token == toastToken else { return }
            showToast = false
        }
    }

    // MARK: - Legend (minimal)

    private var legend: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                legendItem(color: fireAccent, icon: "flame.fill", text: "Logged")
                legendItem(color: Color(hex: 0x5AB0FF), icon: "shield.fill", text: "Shielded")
                legendItem(color: .white.opacity(0.4), icon: "circle.dashed", text: "Open")
            }
            Text("Tap an open day to spend a shield.")
                .font(AppFont.text(12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private func legendItem(color: Color, icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(color)
            Text(text).font(AppFont.text(11, weight: .semibold)).foregroundColor(.white.opacity(0.7))
        }
    }

    private var toast: some View {
        HStack(spacing: 8) {
            Image(systemName: toastOK ? "shield.fill" : "info.circle.fill")
                .font(.system(size: 13, weight: .bold))
            Text(toastText).font(AppFont.text(13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(toastOK ? shieldDeep : Color(hex: 0x2A2A30)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .padding(.top, 70)
        .opacity(showToast ? 1 : 0)
        .offset(y: showToast ? 0 : -18)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showToast)
        .allowsHitTesting(false)
    }

    // MARK: - Month paging

    private func step(_ delta: Int) {
        let next = monthOffset + delta
        guard next <= 0, next >= earliestOffset else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { monthOffset = next }
    }

    private var canGoForward: Bool { monthOffset < 0 }
    private var canGoBack: Bool { monthOffset > earliestOffset }

    /// How far back the user has any logged history, as a negative month offset.
    private var earliestOffset: Int {
        let cal = Calendar.current
        guard let earliest = container.transactions.map(\.date).min() else { return 0 }
        let from = cal.dateInterval(of: .month, for: earliest)?.start ?? earliest
        let to = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return -(cal.dateComponents([.month], from: from, to: to).month ?? 0)
    }

    // MARK: - Calendar math

    private var displayedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let syms = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(syms[start...] + syms[..<start])
    }

    /// Displayed month's grid with leading/trailing `nil` placeholders so the
    /// days line up under their weekday columns.
    private var monthCells: [Date?] {
        let cal = Calendar.current
        let month = displayedMonth
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = interval.start
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let weekdayOfFirst = cal.component(.weekday, from: firstDay)
        let leading = (weekdayOfFirst - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<daysInMonth {
            cells.append(cal.date(byAdding: .day, value: d, to: firstDay))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

// MARK: - Background + fire circles

/// Static dark fiery gradient. Deep base plus two fixed fiery glows — no
/// motion, so the only animation on screen is the fire day-circles.
private struct DarkFireBackground: View {
    let accent: Color
    let warm: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A0B06), Color(hex: 0x06040A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.40), .clear],
                           center: .bottom, startRadius: 10, endRadius: 460)
                .blendMode(.screen)
            RadialGradient(colors: [warm.opacity(0.28), .clear],
                           center: .topTrailing, startRadius: 8, endRadius: 360)
                .blendMode(.screen)
        }
    }
}

/// A logged day: a fire-gradient circle with a flickering inner ember glow,
/// staggered per day so the calendar shimmers. Only the small inner highlight
/// animates (scale + opacity) — the outer glow is a fixed shadow. Animating a
/// shadow's radius (the old approach) re-blurs every frame across every logged
/// day, which is what made the page heavy.
private struct FireCircle: View {
    let colors: [Color]
    let glow: Color
    var phase: Double = 0

    @State private var flick = false

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.6), .clear],
                                         center: .init(x: 0.35, y: 0.30), startRadius: 0, endRadius: 20))
                    .scaleEffect(flick ? 1.0 : 0.6)
                    .opacity(flick ? 0.95 : 0.4)
                    .blendMode(.screen)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: glow.opacity(0.55), radius: 5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true).delay(phase)) {
                    flick = true
                }
            }
    }
}
