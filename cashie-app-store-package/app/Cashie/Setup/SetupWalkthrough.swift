import SwiftUI

/// A swipeable, step-by-step walkthrough that shows users how to map the
/// imported Cashie Quick Log shortcut to a Back Tap / Triple Tap inside iOS
/// Settings.
///
/// The user swipes through the frames themselves (no auto-advance). Every frame
/// is drawn natively in SwiftUI: crisp at any size, no bundled image assets.
/// Each frame is a stylised iOS "Settings" screen with the next row to tap
/// highlighted and a pulsing tap indicator over it.
struct SetupWalkthrough: View {
    struct Row: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let label: String
        var value: String? = nil
        var checked: Bool = false
        var highlighted: Bool = false
    }

    struct Frame: Identifiable {
        let id = UUID()
        let navTitle: String
        let rows: [Row]
        let caption: String
    }

    let frames: [Frame]

    @State private var index = 0
    @State private var pulse = false

    // iOS Settings system colours, so the mock reads as the real thing.
    private let groupedBG = Color(hex: 0xF2F2F7)
    private let separator = Color(hex: 0xE5E5EA)
    private let tintBlue  = Color(hex: 0x007AFF)
    private let secondary = Color(hex: 0x8E8E93)
    private let chevron   = Color(hex: 0xC4C4C6)

    var body: some View {
        VStack(spacing: 12) {
            // Manually swipeable pages, the user steps through at their own pace.
            TabView(selection: $index) {
                ForEach(Array(frames.enumerated()), id: \.element.id) { i, frame in
                    screenCard(frame)
                        .padding(.horizontal, 2)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 296)

            Text(frames[index].caption)
                .font(AppFont.text(13, weight: .semibold))
                .foregroundColor(Theme.Palette.ink)
                .id(frames[index].id)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: index)

            // Tappable progress dots, also serve as a position indicator.
            HStack(spacing: 7) {
                ForEach(frames.indices, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Theme.Palette.gold : Theme.Palette.line)
                        .frame(width: 7, height: 7)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) { index = i }
                        }
                }
            }

            Text("Swipe to step through")
                .font(AppFont.text(11))
                .foregroundColor(Theme.Palette.inkMute)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Mock Settings screen

    private func screenCard(_ frame: Frame) -> some View {
        VStack(spacing: 0) {
            navBar(frame.navTitle)
            VStack(spacing: 0) {
                ForEach(Array(frame.rows.enumerated()), id: \.element.id) { idx, row in
                    rowView(row)
                    if idx != frame.rows.count - 1 {
                        Rectangle().fill(separator)
                            .frame(height: 1)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 14)
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 296)
        .background(groupedBG)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: 0xD9D9DE), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
    }

    private func navBar(_ title: String) -> some View {
        ZStack {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                Text("Back").font(.system(size: 15))
                Spacer()
            }
            .foregroundColor(tintBlue)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(row.tint)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: row.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )
            Text(row.label).font(.system(size: 15)).foregroundColor(.black)
            Spacer()
            if let v = row.value {
                Text(v).font(.system(size: 14)).foregroundColor(secondary)
            }
            if row.checked {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(tintBlue)
            } else {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(chevron)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(row.highlighted ? tintBlue.opacity(0.10) : Color.white)
        .overlay(alignment: .center) {
            if row.highlighted { tapIndicator }
        }
    }

    private var tapIndicator: some View {
        ZStack {
            Circle()
                .stroke(tintBlue.opacity(0.55), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(pulse ? 1.4 : 0.7)
                .opacity(pulse ? 0 : 0.9)
            Circle()
                .fill(tintBlue.opacity(0.9))
                .frame(width: 14, height: 14)
        }
        .allowsHitTesting(false)
    }
}

extension SetupWalkthrough {
    /// The five-step Back Tap / Triple Tap mapping flow.
    static var backTap: SetupWalkthrough {
        SetupWalkthrough(frames: [
            Frame(navTitle: "Settings", rows: [
                Row(icon: "airplane", tint: Color(hex: 0xFF9500), label: "Airplane Mode"),
                Row(icon: "wifi", tint: Color(hex: 0x007AFF), label: "Wi-Fi"),
                Row(icon: "figure.walk", tint: Color(hex: 0x007AFF), label: "Accessibility", highlighted: true),
                Row(icon: "gearshape.fill", tint: Color(hex: 0x8E8E93), label: "General"),
            ], caption: "1.  Settings → Accessibility"),
            Frame(navTitle: "Accessibility", rows: [
                Row(icon: "speaker.wave.2.fill", tint: Color(hex: 0x007AFF), label: "VoiceOver"),
                Row(icon: "textformat.size", tint: Color(hex: 0x007AFF), label: "Display & Text Size"),
                Row(icon: "hand.point.up.left.fill", tint: Color(hex: 0x34C759), label: "Touch", highlighted: true),
            ], caption: "2.  Tap Touch"),
            Frame(navTitle: "Touch", rows: [
                Row(icon: "hand.tap.fill", tint: Color(hex: 0x34C759), label: "AssistiveTouch"),
                Row(icon: "hand.draw.fill", tint: Color(hex: 0x34C759), label: "Haptic Touch"),
                Row(icon: "iphone", tint: Color(hex: 0x34C759), label: "Back Tap", highlighted: true),
            ], caption: "3.  Tap Back Tap"),
            Frame(navTitle: "Back Tap", rows: [
                Row(icon: "2.circle.fill", tint: Color(hex: 0x8E8E93), label: "Double Tap", value: "Off"),
                Row(icon: "3.circle.fill", tint: Color(hex: 0x007AFF), label: "Triple Tap", value: "Off", highlighted: true),
            ], caption: "4.  Choose Triple Tap"),
            Frame(navTitle: "Triple Tap", rows: [
                Row(icon: "bolt.fill", tint: Color(hex: 0xAF52DE), label: "Cashie Quick Log", checked: true, highlighted: true),
                Row(icon: "camera.fill", tint: Color(hex: 0x8E8E93), label: "Screenshot"),
            ], caption: "5.  Pick Cashie Quick Log"),
        ])
    }
}
