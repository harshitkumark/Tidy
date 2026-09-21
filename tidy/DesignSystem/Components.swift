import SwiftUI

// MARK: - Card

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.cardBackground, Theme.Colors.cardBackground.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.Colors.ink.opacity(0.04), radius: 12, x: 0, y: 6)
            // Subtle inner stroke for glass effect
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .blendMode(.overlay)
            )
    }
}

// MARK: - ScaleButtonStyle

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(Theme.Typography.headline())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.mint)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SecondaryButton

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(Theme.Typography.headline())
            }
            .foregroundStyle(Theme.Colors.mint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.mint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ProgressRing

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    let gradientColors: [Color]

    init(progress: Double, lineWidth: CGFloat = 12, size: CGFloat = 160, gradientColors: [Color] = [Theme.Colors.mint, Theme.Colors.mint.opacity(0.6)]) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.gradientColors = gradientColors
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Theme.Colors.cloud, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SkeletonView

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.25),
                        Color.gray.opacity(0.15)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.inkSecondary)

            Text(title)
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            if let actionTitle, let action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - SelectionBar

struct SelectionBar: View {
    let count: Int
    let totalSize: Int64? // nil for contacts (show count only)
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        if count > 0 {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) selected")
                        .font(Theme.Typography.headline())
                        .foregroundStyle(Theme.Colors.ink)
                    if let totalSize {
                        Text(ByteFormatter.format(totalSize))
                            .font(Theme.Typography.caption())
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }

                Spacer()

                Button(action: action) {
                    Text(actionTitle)
                        .font(Theme.Typography.headline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.mint)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: count)
        }
    }
}

// MARK: - PermissionBanner

struct PermissionBanner: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Theme.Colors.coral)

            Text(message)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.ink)

            Spacer()

            Button(action: action) {
                Text(actionTitle)
                    .font(Theme.Typography.caption().bold())
                    .foregroundStyle(Theme.Colors.mint)
            }
        }
        .padding(Theme.Spacing.sm + 4)
        .background(Theme.Colors.coral.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Card") {
    Card {
        VStack(alignment: .leading) {
            Text("Similar Photos")
                .font(Theme.Typography.headline())
            Text("23 groups · 1.4 GB")
                .font(Theme.Typography.caption())
        }
    }
    .padding()
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        PrimaryButton("Review Selection", icon: "checkmark.circle") {}
        SecondaryButton("Select All", icon: "checklist") {}
    }
    .padding()
}

#Preview("ProgressRing") {
    ProgressRing(progress: 0.72)
}

#Preview("SkeletonView") {
    SkeletonView()
        .frame(height: 60)
        .padding()
}

#Preview("EmptyState") {
    EmptyStateView(
        icon: "photo.on.rectangle.angled",
        title: "No Similar Photos",
        message: "We couldn't find any duplicate or similar photos in your library.",
        actionTitle: "Scan Again"
    ) {}
}

#Preview("SelectionBar") {
    VStack {
        Spacer()
        SelectionBar(count: 42, totalSize: 1_500_000_000, actionTitle: "Review") {}
    }
}

#Preview("PermissionBanner") {
    PermissionBanner(
        message: "You've shared 23 photos with tidy",
        actionTitle: "Manage"
    ) {}
    .padding()
}
