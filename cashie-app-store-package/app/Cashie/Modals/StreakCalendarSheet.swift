import SwiftUI

/// Full-screen streak view reached by tapping the streak card on the You tab.
/// Light "paper" UI to match the rest of the app: a clean page background with
/// white floating cards. The one splash of colour is the orange gradient hero
/// (the streak count) and the warm fire-gradient on logged days. Logged days
/// catch fire, shielded days show a shield, missed days sit open. Tap a missed
/// day in a week you logged in (with shields left) to spend a shield and bridge
/// the gap; the streak chain crosses months. Page back to see earlier months.
///
/// Rendering is deliberately static: day cells are plain gradient/flat circles
/// with no per-day looping animation, so a full month of logged days stays
/// cheap to scroll and stable to tap (the old flickering-ember cells, one
/// `repeatForever` animation each, made the page lag and could crash on shield
/// taps).
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
    private let fireAccent = Color(hex: 0xFF7A2E)
    private let shield = [Color(hex: 0x5AB0FF), Color(hex: 0x2F86E8)]
    private let shieldDeep = Color(hex: 0x1E6FD9)

    /// Parses the `yyyy-MM-dd` shield keys back to dates for week grouping.
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.pageBackground.ignoresSafeArea()
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
            // Toast sits at the bottom so it never covers the streak number in
            // the hero. Always mounted; visibility is driven by opacity/offset.
            toast
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Your streak")
                .font(AppFont.display(28, weight: .bold))
                .foregroundColor(Theme.Palette.ink)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.Palette.bgCream))
            }
            .buttonStyle(.plainTappable)
        }
        .padding(.top, 16)
    }

    // MARK: - Hero (orange gradient, mirrors the You-tab streak card)

    private var hero: some View {
        ZStack {
            LinearGradient(colors: fire, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.32), .clear],
                           center: .topTrailing, startRadius: 4, endRadius: 240)
            RadialGradient(colors: [.black.opacity(0.10), .clear],
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // Soft neutral shadow so it floats like every other card (flat paper),
        // instead of the old heavy coloured glow.
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 9)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
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

    // MARK: - Calendar (white paper card)

    private var calendarCard: some View {
        // Precomputed once per render so each day cell is O(1): the cached
        // logged/shielded sets, the set of weeks that had a log, and shields
        // already spent per week. (The old code re-derived all of this from
        // scratch inside every one of the ~40 cells.)
        let ctx = monthContext
        return VStack(spacing: 14) {
            monthHeader
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(AppFont.text(10, weight: .bold))
                        .foregroundColor(Theme.Palette.inkMute)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 10
            ) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell {
                        dayCircle(date: date, ctx: ctx)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(18)
        .softCard(18)
    }

    private var monthHeader: some View {
        HStack {
            navButton("chevron.left", enabled: canGoBack) { step(-1) }
            Spacer()
            Text(monthTitle)
                .font(AppFont.text(14, weight: .bold))
                .tracking(0.5)
                .foregroundColor(Theme.Palette.ink)
            Spacer()
            navButton("chevron.right", enabled: canGoForward) { step(1) }
        }
    }

    private func navButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(enabled ? Theme.Palette.ink : Theme.Palette.inkFaint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.Palette.bgCream))
        }
        .buttonStyle(.plainTappable)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    @ViewBuilder
    private func dayCircle(date: Date, ctx: MonthContext) -> some View {
        let cal = Calendar.current
        let key = container.dayKey(date)
        let isLogged = ctx.logged.contains(key)
        let isShielded = ctx.shielded.contains(key)
        let isToday = cal.isDateInToday(date)
        let isFuture = cal.startOfDay(for: date) > cal.startOfDay(for: Date())
        let eligible = !isLogged && !isShielded && !isFuture && ctx.canShield(date, weekKey: weekKey(date))
        let dayNum = cal.component(.day, from: date)
        let popped = justShielded == key

        Button {
            tap(date: date)
        } label: {
            ZStack {
                fill(isLogged: isLogged, isShielded: isShielded, isFuture: isFuture,
                     eligible: eligible)
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
                    Circle().stroke(Theme.Palette.ink.opacity(0.85), lineWidth: 2).frame(width: 44, height: 44)
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
    private func fill(isLogged: Bool, isShielded: Bool, isFuture: Bool, eligible: Bool) -> some View {
        if isLogged {
            // Static fire-gradient coin: a warm gradient with a fixed inner
            // highlight and a thin rim. No looping animation, no blend mode.
            Circle()
                .fill(LinearGradient(colors: fire, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.45), .clear],
                                             center: .init(x: 0.35, y: 0.30),
                                             startRadius: 0, endRadius: 18))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                .shadow(color: fireAccent.opacity(0.30), radius: 3, y: 1)
        } else if isShielded {
            Circle()
                .fill(LinearGradient(colors: shield, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: shieldDeep.opacity(0.30), radius: 3, y: 1)
        } else if eligible {
            Circle()
                .fill(Theme.Palette.streakPastel)
                .overlay(Circle().strokeBorder(fireAccent.opacity(0.85),
                                               style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])))
        } else if isFuture {
            Circle().fill(Theme.Palette.lineSoft.opacity(0.5))
        } else {
            Circle()
                .fill(Theme.Palette.bgCream)
                .overlay(Circle().stroke(Theme.Palette.line, lineWidth: 1))
        }
    }

    private func numberColor(isLogged: Bool, isShielded: Bool, isFuture: Bool, eligible: Bool) -> Color {
        if isLogged || isShielded { return .white }
        if eligible { return Theme.Palette.ink }
        if isFuture { return Theme.Palette.inkFaint }
        return Theme.Palette.inkMute
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
                legendItem(color: Color(hex: 0x2F86E8), icon: "shield.fill", text: "Shielded")
                legendItem(color: Theme.Palette.inkMute, icon: "circle.dashed", text: "Open")
            }
            Text("Tap an open day to spend a shield.")
                .font(AppFont.text(12, weight: .medium))
                .foregroundColor(Theme.Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private func legendItem(color: Color, icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(color)
            Text(text).font(AppFont.text(11, weight: .semibold)).foregroundColor(Theme.Palette.inkSoft)
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
        .background(Capsule().fill(toastOK ? shieldDeep : Theme.Palette.ink))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(.bottom, 34)
        .opacity(showToast ? 1 : 0)
        .offset(y: showToast ? 0 : 18)
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

    // MARK: - Shield eligibility (precomputed per render)

    /// Cheap, O(1)-per-cell view of the data the calendar needs. Built once in
    /// `calendarCard` and handed to every cell, instead of each cell re-deriving
    /// the logged/shielded sets and week tallies from the raw arrays.
    struct MonthContext {
        let logged: Set<String>
        let shielded: Set<String>
        let loggedWeeks: Set<String>
        let shieldsByWeek: [String: Int]

        /// Mirror of `AppContainer.canShield`, using the precomputed tallies.
        /// The cell already knows the day isn't logged/shielded/future.
        func canShield(_ day: Date, weekKey: String) -> Bool {
            guard loggedWeeks.contains(weekKey) else { return false }
            return (shieldsByWeek[weekKey] ?? 0) < AppContainer.shieldsPerWeek
        }
    }

    private var monthContext: MonthContext {
        let logged = container.loggedDayKeys
        let shielded = container.shieldedDayKeys
        let loggedWeeks = Set(container.transactions.map { weekKey($0.date) })
        var shieldsByWeek: [String: Int] = [:]
        for k in shielded {
            if let d = Self.keyFormatter.date(from: k) {
                shieldsByWeek[weekKey(d), default: 0] += 1
            }
        }
        return MonthContext(logged: logged, shielded: shielded,
                            loggedWeeks: loggedWeeks, shieldsByWeek: shieldsByWeek)
    }

    private func weekKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
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
