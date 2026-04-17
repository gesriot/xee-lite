import SwiftUI

enum AppThemePreference: String, CaseIterable, Identifiable, Equatable {
    case automatic
    case light
    case dark
    case black

    static let appStorageKey = "appThemePreference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .black:
            return "Black"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic:
            return nil
        case .light:
            return .light
        case .dark, .black:
            return .dark
        }
    }

    func resolvedTheme(for systemColorScheme: ColorScheme) -> ResolvedAppTheme {
        switch self {
        case .automatic:
            return systemColorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        case .black:
            return .black
        }
    }
}

enum ResolvedAppTheme: Equatable {
    case light
    case dark
    case black

    var palette: AppThemePalette {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .black:
            return .black
        }
    }
}

struct AppThemePalette {
    let viewerBackground: Color
    let viewerPrimaryText: Color
    let viewerSecondaryText: Color
    let dropTargetStroke: Color
    let dropTargetBubbleBackground: Color
    let dropTargetBubbleText: Color

    let chromeBackgroundWindowed: Color
    let chromeBackgroundFullScreen: Color
    let chromeBorderWindowed: Color
    let chromeBorderFullScreen: Color
    let chromePrimaryText: Color
    let chromeSecondaryText: Color
    let chromeMutedText: Color
    let chromeSelectionFill: Color
    let chromeSelectionFillStrong: Color
    let chromeSelectionBorder: Color
    let chromeSelectionBorderStrong: Color
    let chromeBadgeBackground: Color
    let chromeBadgeText: Color

    let browserGradientTop: Color
    let browserGradientBottom: Color
    let browserHeaderBackground: Color
    let browserDivider: Color
    let browserPrimaryText: Color
    let browserSecondaryText: Color
    let browserCardFill: Color
    let browserCardFillStrong: Color
    let browserCardBorder: Color
    let browserCardBorderStrong: Color
    let browserBadgeBackground: Color
    let browserBadgeText: Color
    let browserPlaceholder: Color

    let inspectorBackgroundWindowed: Color
    let inspectorBackgroundFullScreen: Color
    let inspectorBorderWindowed: Color
    let inspectorBorderFullScreen: Color
    let inspectorSectionBackgroundWindowed: Color
    let inspectorSectionBackgroundFullScreen: Color
    let inspectorPrimaryText: Color
    let inspectorSecondaryText: Color
    let inspectorMutedText: Color
    let inspectorCopiedText: Color
    let inspectorRowBackground: Color

    let floatingPanelBackground: Color
    let floatingPanelBorder: Color
    let floatingPanelPrimaryText: Color
    let floatingPanelSecondaryText: Color
    let floatingPanelMutedText: Color
    let floatingPanelTint: Color
    let floatingPanelShadow: Color

    static let light = AppThemePalette(
        viewerBackground: Color(red: 0.93, green: 0.94, blue: 0.96),
        viewerPrimaryText: Color.black.opacity(0.86),
        viewerSecondaryText: Color.black.opacity(0.56),
        dropTargetStroke: Color.black.opacity(0.46),
        dropTargetBubbleBackground: Color.white.opacity(0.92),
        dropTargetBubbleText: Color.black.opacity(0.84),
        chromeBackgroundWindowed: Color.white.opacity(0.92),
        chromeBackgroundFullScreen: Color.white.opacity(0.76),
        chromeBorderWindowed: Color.black.opacity(0.10),
        chromeBorderFullScreen: Color.black.opacity(0.12),
        chromePrimaryText: Color.black.opacity(0.88),
        chromeSecondaryText: Color.black.opacity(0.72),
        chromeMutedText: Color.black.opacity(0.44),
        chromeSelectionFill: Color.black.opacity(0.04),
        chromeSelectionFillStrong: Color.black.opacity(0.08),
        chromeSelectionBorder: Color.black.opacity(0.10),
        chromeSelectionBorderStrong: Color.black.opacity(0.70),
        chromeBadgeBackground: Color.black.opacity(0.88),
        chromeBadgeText: Color.white.opacity(0.94),
        browserGradientTop: Color(red: 0.98, green: 0.98, blue: 0.99),
        browserGradientBottom: Color(red: 0.92, green: 0.94, blue: 0.96),
        browserHeaderBackground: Color.white.opacity(0.82),
        browserDivider: Color.black.opacity(0.08),
        browserPrimaryText: Color.black.opacity(0.88),
        browserSecondaryText: Color.black.opacity(0.58),
        browserCardFill: Color.black.opacity(0.02),
        browserCardFillStrong: Color.black.opacity(0.06),
        browserCardBorder: Color.black.opacity(0.08),
        browserCardBorderStrong: Color.black.opacity(0.70),
        browserBadgeBackground: Color.black.opacity(0.88),
        browserBadgeText: Color.white.opacity(0.94),
        browserPlaceholder: Color.black.opacity(0.30),
        inspectorBackgroundWindowed: Color.white.opacity(0.88),
        inspectorBackgroundFullScreen: Color.white.opacity(0.78),
        inspectorBorderWindowed: Color.black.opacity(0.08),
        inspectorBorderFullScreen: Color.black.opacity(0.10),
        inspectorSectionBackgroundWindowed: Color.black.opacity(0.04),
        inspectorSectionBackgroundFullScreen: Color.black.opacity(0.05),
        inspectorPrimaryText: Color.black.opacity(0.88),
        inspectorSecondaryText: Color.black.opacity(0.72),
        inspectorMutedText: Color.black.opacity(0.56),
        inspectorCopiedText: Color.green.opacity(0.86),
        inspectorRowBackground: Color.black.opacity(0.02),
        floatingPanelBackground: Color.white.opacity(0.92),
        floatingPanelBorder: Color.black.opacity(0.10),
        floatingPanelPrimaryText: Color.black.opacity(0.88),
        floatingPanelSecondaryText: Color.black.opacity(0.74),
        floatingPanelMutedText: Color.black.opacity(0.56),
        floatingPanelTint: Color.accentColor,
        floatingPanelShadow: Color.black.opacity(0.12)
    )

    static let dark = AppThemePalette(
        viewerBackground: Color(red: 0.10, green: 0.11, blue: 0.13),
        viewerPrimaryText: Color.white.opacity(0.94),
        viewerSecondaryText: Color.white.opacity(0.62),
        dropTargetStroke: Color.white.opacity(0.75),
        dropTargetBubbleBackground: Color.black.opacity(0.70),
        dropTargetBubbleText: Color.white,
        chromeBackgroundWindowed: Color.black.opacity(0.84),
        chromeBackgroundFullScreen: Color.black.opacity(0.58),
        chromeBorderWindowed: Color.white.opacity(0.08),
        chromeBorderFullScreen: Color.white.opacity(0.10),
        chromePrimaryText: Color.white.opacity(0.96),
        chromeSecondaryText: Color.white.opacity(0.78),
        chromeMutedText: Color.white.opacity(0.34),
        chromeSelectionFill: Color.white.opacity(0.04),
        chromeSelectionFillStrong: Color.white.opacity(0.12),
        chromeSelectionBorder: Color.white.opacity(0.10),
        chromeSelectionBorderStrong: Color.white.opacity(0.94),
        chromeBadgeBackground: Color.white.opacity(0.94),
        chromeBadgeText: Color.black.opacity(0.86),
        browserGradientTop: Color(red: 0.10, green: 0.11, blue: 0.13),
        browserGradientBottom: Color(red: 0.06, green: 0.07, blue: 0.09),
        browserHeaderBackground: Color.black.opacity(0.74),
        browserDivider: Color.white.opacity(0.08),
        browserPrimaryText: Color.white.opacity(0.96),
        browserSecondaryText: Color.white.opacity(0.62),
        browserCardFill: Color.white.opacity(0.02),
        browserCardFillStrong: Color.white.opacity(0.10),
        browserCardBorder: Color.white.opacity(0.08),
        browserCardBorderStrong: Color.white.opacity(0.86),
        browserBadgeBackground: Color.white.opacity(0.94),
        browserBadgeText: Color.black.opacity(0.86),
        browserPlaceholder: Color.white.opacity(0.36),
        inspectorBackgroundWindowed: Color.black.opacity(0.72),
        inspectorBackgroundFullScreen: Color.black.opacity(0.50),
        inspectorBorderWindowed: Color.white.opacity(0.08),
        inspectorBorderFullScreen: Color.white.opacity(0.10),
        inspectorSectionBackgroundWindowed: Color.white.opacity(0.04),
        inspectorSectionBackgroundFullScreen: Color.white.opacity(0.05),
        inspectorPrimaryText: Color.white.opacity(0.92),
        inspectorSecondaryText: Color.white.opacity(0.88),
        inspectorMutedText: Color.white.opacity(0.70),
        inspectorCopiedText: Color.green.opacity(0.95),
        inspectorRowBackground: Color.white.opacity(0.02),
        floatingPanelBackground: Color.black.opacity(0.72),
        floatingPanelBorder: Color.white.opacity(0.10),
        floatingPanelPrimaryText: Color.white,
        floatingPanelSecondaryText: Color.white.opacity(0.86),
        floatingPanelMutedText: Color.white.opacity(0.72),
        floatingPanelTint: Color.white,
        floatingPanelShadow: Color.black.opacity(0.22)
    )

    static let black = AppThemePalette(
        viewerBackground: Color.black.opacity(0.98),
        viewerPrimaryText: Color.white.opacity(0.96),
        viewerSecondaryText: Color.white.opacity(0.62),
        dropTargetStroke: Color.white.opacity(0.82),
        dropTargetBubbleBackground: Color.black.opacity(0.82),
        dropTargetBubbleText: Color.white,
        chromeBackgroundWindowed: Color.black.opacity(0.90),
        chromeBackgroundFullScreen: Color.black.opacity(0.64),
        chromeBorderWindowed: Color.white.opacity(0.08),
        chromeBorderFullScreen: Color.white.opacity(0.12),
        chromePrimaryText: Color.white.opacity(0.98),
        chromeSecondaryText: Color.white.opacity(0.80),
        chromeMutedText: Color.white.opacity(0.34),
        chromeSelectionFill: Color.white.opacity(0.03),
        chromeSelectionFillStrong: Color.white.opacity(0.12),
        chromeSelectionBorder: Color.white.opacity(0.10),
        chromeSelectionBorderStrong: Color.white.opacity(0.96),
        chromeBadgeBackground: Color.white.opacity(0.96),
        chromeBadgeText: Color.black.opacity(0.90),
        browserGradientTop: Color.black.opacity(0.98),
        browserGradientBottom: Color.black.opacity(0.90),
        browserHeaderBackground: Color.black.opacity(0.82),
        browserDivider: Color.white.opacity(0.08),
        browserPrimaryText: Color.white.opacity(0.98),
        browserSecondaryText: Color.white.opacity(0.62),
        browserCardFill: Color.white.opacity(0.02),
        browserCardFillStrong: Color.white.opacity(0.10),
        browserCardBorder: Color.white.opacity(0.08),
        browserCardBorderStrong: Color.white.opacity(0.92),
        browserBadgeBackground: Color.white.opacity(0.96),
        browserBadgeText: Color.black.opacity(0.90),
        browserPlaceholder: Color.white.opacity(0.38),
        inspectorBackgroundWindowed: Color.black.opacity(0.78),
        inspectorBackgroundFullScreen: Color.black.opacity(0.58),
        inspectorBorderWindowed: Color.white.opacity(0.08),
        inspectorBorderFullScreen: Color.white.opacity(0.12),
        inspectorSectionBackgroundWindowed: Color.white.opacity(0.04),
        inspectorSectionBackgroundFullScreen: Color.white.opacity(0.05),
        inspectorPrimaryText: Color.white.opacity(0.94),
        inspectorSecondaryText: Color.white.opacity(0.90),
        inspectorMutedText: Color.white.opacity(0.70),
        inspectorCopiedText: Color.green.opacity(0.98),
        inspectorRowBackground: Color.white.opacity(0.02),
        floatingPanelBackground: Color.black.opacity(0.80),
        floatingPanelBorder: Color.white.opacity(0.10),
        floatingPanelPrimaryText: Color.white,
        floatingPanelSecondaryText: Color.white.opacity(0.88),
        floatingPanelMutedText: Color.white.opacity(0.74),
        floatingPanelTint: Color.white,
        floatingPanelShadow: Color.black.opacity(0.24)
    )
}

private struct XeeThemePaletteKey: EnvironmentKey {
    static let defaultValue = AppThemePalette.dark
}

extension EnvironmentValues {
    var xeeThemePalette: AppThemePalette {
        get { self[XeeThemePaletteKey.self] }
        set { self[XeeThemePaletteKey.self] = newValue }
    }
}

struct XeeThemedSceneRoot<Content: View>: View {
    @AppStorage(AppThemePreference.appStorageKey) private var themePreferenceRawValue = AppThemePreference.automatic.rawValue
    @Environment(\.colorScheme) private var systemColorScheme

    @ViewBuilder let content: () -> Content

    var body: some View {
        let preference = AppThemePreference(rawValue: themePreferenceRawValue) ?? .automatic
        let palette = preference.resolvedTheme(for: systemColorScheme).palette

        content()
            .preferredColorScheme(preference.preferredColorScheme)
            .environment(\.xeeThemePalette, palette)
    }
}
