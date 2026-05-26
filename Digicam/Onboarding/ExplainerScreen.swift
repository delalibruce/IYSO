import SwiftUI

struct ExplainerConfig {
    let headline: String
    let body: String
    let illustrationSystemName: String
    let dotIndex: Int
    let dotTotal: Int
    let ctaLabel: String
}

extension ExplainerConfig {
    static let lens = ExplainerConfig(
        headline: "Clip it on.",
        body: "Your iyso lens attaches to the top of your phone.\nNo filters. No presets. Real glass, real light.",
        illustrationSystemName: "camera.aperture",
        dotIndex: 1, dotTotal: 4,
        ctaLabel: "Next"
    )
    static let iysoMode = ExplainerConfig(
        headline: "When the lens is on, you're shooting.",
        body: "Clip on the lens and your phone becomes a camera.\nNotifications off. Other apps put away. Just you and the shot.",
        illustrationSystemName: "camera.fill",
        dotIndex: 2, dotTotal: 4,
        ctaLabel: "Next"
    )
    static let memoryMode = ExplainerConfig(
        headline: "When you're done, the memories are waiting.",
        body: "Take off the lens, exit iyso, and your photos unlock.\nSorted by date. Already on your phone. Easy to share.",
        illustrationSystemName: "photo.stack.fill",
        dotIndex: 3, dotTotal: 4,
        ctaLabel: "Next"
    )
    static let noPeeking = ExplainerConfig(
        headline: "Shoot first. Look later.",
        body: "While you're in iyso mode, your photos are tucked away.\nNo checking. No deleting. Snap, move on, be there.",
        illustrationSystemName: "lock.fill",
        dotIndex: 4, dotTotal: 4,
        ctaLabel: "Got it"
    )
}

struct ExplainerScreen: View {
    let config: ExplainerConfig
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 48) {
                    illustration

                    VStack(alignment: .leading, spacing: 16) {
                        Text(config.headline)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(config.body)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(white: 0.55))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                }

                Spacer()

                VStack(spacing: 24) {
                    OnboardingProgressDots(total: config.dotTotal, current: config.dotIndex)

                    Button(action: onContinue) {
                        Text(config.ctaLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Color(white: 1, opacity: 0.05))
                .frame(width: 140, height: 140)

            Image(systemName: config.illustrationSystemName)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(Color(white: 0.7))
        }
    }
}
