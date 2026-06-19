import SwiftUI

/// Brief launch animation. Fades to onboarding after a short delay.
struct SplashView: View {
    @EnvironmentObject var container: AppContainer
    @State private var rotation: Double = -8
    @State private var fillProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.Palette.bg.ignoresSafeArea()
            GoldBlob(alignment: .topTrailing, size: 380, intensity: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                CoinMark(size: 110)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            rotation = 8
                        }
                    }
                Text("CASHIE")
                    .font(AppFont.display(40, weight: .heavy))
                    .tracking(4)
                    .foregroundColor(Theme.Palette.ink)
                Text("Money, but actually kind.")
                    .font(AppFont.text(13, weight: .medium, italic: true))
                    .foregroundColor(Theme.Palette.inkSoft)
                Spacer()
                LoadingBar(progress: fillProgress)
                    .frame(width: 160, height: 3)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { fillProgress = 1 }
            // Dev affordance: -skipSubGate skips the subscription gate and goes
            // straight to the main app (for QA/screenshots). Launch args can't
            // be set on a real App Store install, so this is simulator-only in
            // practice, same as the other -reset* / -startAt dev flags.
            if ProcessInfo.processInfo.arguments.contains("-skipSubGate") {
                container.goToMain(); return
            }
            Task {
                async let validated: Bool = (try? await container.subscriptions.refreshSubscriptionStatus()) ?? false
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                let subscribed = await validated
                await MainActor.run {
                    // Single source of truth for launch routing: Pro → main;
                    // otherwise resume onboarding or show the hard paywall.
                    container.routeOnLaunch(subscribed: subscribed)
                }
            }
        }
    }
}

/// Cashie mascot mark used in the splash + welcome + loading screens.
struct CoinMark: View {
    var size: CGFloat = 180

    var body: some View {
        Image("Mascot")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .shadow(color: Theme.Palette.gold.opacity(0.35), radius: 20, x: 0, y: 12)
    }
}

private struct LoadingBar: View {
    var progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.line)
                Capsule()
                    .fill(Theme.Palette.ink)
                    .frame(width: proxy.size.width * progress)
            }
        }
    }
}
