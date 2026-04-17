import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var viewerCoordinator: ViewerCoordinator
    @AppStorage(AppThemePreference.appStorageKey) private var themePreferenceRawValue = AppThemePreference.automatic.rawValue
    @AppStorage(ImageOpenZoomBehavior.appStorageKey) private var zoomBehaviorRawValue = ImageOpenZoomBehavior.rememberCurrent.rawValue
    @StateObject private var preferencesStore = PreferencesStore()
    @StateObject private var slideshowState = SlideshowPlaybackState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                appearanceSection
                viewingSection
                transferDestinationsSection
                slideshowSection
                keyboardShortcutsSection
            }
            .padding(20)
        }
        .frame(width: 720, height: 640)
    }

    private var appearanceSection: some View {
        preferenceSection(
            title: "Appearance",
            description: "Choose how XeeLite follows system appearance and how deep dark mode should go."
        ) {
            Picker("Theme", selection: $themePreferenceRawValue) {
                ForEach(AppThemePreference.allCases) { preference in
                    Text(preference.title).tag(preference.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220, alignment: .leading)
        }
    }

    private var viewingSection: some View {
        let zoomBehavior = ImageOpenZoomBehavior(rawValue: zoomBehaviorRawValue) ?? .rememberCurrent

        return preferenceSection(
            title: "Viewing",
            description: "Control how newly opened images choose their initial zoom mode."
        ) {
            Picker("Zoom When Opening", selection: $zoomBehaviorRawValue) {
                ForEach(ImageOpenZoomBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240, alignment: .leading)

            Text(zoomBehavior.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var transferDestinationsSection: some View {
        preferenceSection(
            title: "Transfer Destinations",
            description: "Configure the folders used by number keys `1–9` for move and `Shift+1–9` for copy."
        ) {
            VStack(spacing: 10) {
                ForEach(preferencesStore.fileActionDestinations) { destination in
                    destinationRow(for: destination)
                }
            }
        }
    }

    private var slideshowSection: some View {
        preferenceSection(
            title: "Slideshow",
            description: "These defaults are used the next time slideshow starts in any viewer window."
        ) {
            HStack(spacing: 16) {
                Picker("Default Interval", selection: intervalBinding) {
                    ForEach(slideshowState.availableIntervals, id: \.self) { interval in
                        Text(intervalLabel(for: interval)).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180, alignment: .leading)

                Picker("Transition", selection: transitionBinding) {
                    ForEach(SlideshowTransitionStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180, alignment: .leading)
            }
        }
    }

    private var keyboardShortcutsSection: some View {
        preferenceSection(
            title: "Keyboard Shortcuts",
            description: "A quick reference for the most important shortcuts already available in the viewer."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(shortcutGroups.enumerated()), id: \.element.id) { index, group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title)
                            .font(.system(size: 12, weight: .semibold))

                        ForEach(group.items) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title)
                                Spacer(minLength: 20)
                                Text(item.shortcut)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if index < shortcutGroups.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func preferenceSection<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func destinationRow(for destination: FileActionDestination) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(destination.slotNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 20, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.displayName)
                    .font(.system(size: 13, weight: .semibold))

                if let path = destination.displayPath {
                    Text(path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } else {
                    Text("No folder configured for this slot.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                if let url = destination.url {
                    Button("Reveal") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderless)
                }

                if destination.isConfigured {
                    Button("Clear") {
                        preferencesStore.clearDestination(forSlot: destination.slotNumber)
                    }
                    .buttonStyle(.borderless)
                }

                Button(destination.isConfigured ? "Change…" : "Choose…") {
                    chooseFolder(for: destination)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func chooseFolder(for destination: FileActionDestination) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = destination.url ?? viewerCoordinator.activeSession?.appState.currentImageURL?.deletingLastPathComponent()

        if panel.runModal() == .OK, let folderURL = panel.url?.standardizedFileURL {
            preferencesStore.setDestination(folderURL, forSlot: destination.slotNumber)
        }
    }

    private var intervalBinding: Binding<TimeInterval> {
        Binding(
            get: { slideshowState.interval },
            set: { slideshowState.setInterval($0) }
        )
    }

    private var transitionBinding: Binding<SlideshowTransitionStyle> {
        Binding(
            get: { slideshowState.transitionStyle },
            set: { slideshowState.setTransitionStyle($0) }
        )
    }

    private func intervalLabel(for interval: TimeInterval) -> String {
        let rounded = interval.rounded()
        if abs(interval - rounded) < 0.001 {
            return "\(Int(rounded)) seconds"
        }

        return "\(interval.formatted(.number.precision(.fractionLength(1)))) seconds"
    }

    private var shortcutGroups: [ShortcutGroup] {
        [
            ShortcutGroup(
                id: "navigation",
                title: "Navigation",
                items: [
                    ShortcutItem(id: "nav-step", title: "Previous / Next image", shortcut: "← / →"),
                    ShortcutItem(id: "nav-ends", title: "First / Last image", shortcut: "Home / End"),
                    ShortcutItem(id: "nav-jump", title: "Jump by 10 images", shortcut: "⌘← / ⌘→"),
                    ShortcutItem(id: "nav-browser", title: "Open Browser", shortcut: "⌘B")
                ]
            ),
            ShortcutGroup(
                id: "view",
                title: "View",
                items: [
                    ShortcutItem(id: "view-fit", title: "Fit in Window", shortcut: "⌘0"),
                    ShortcutItem(id: "view-actual", title: "Actual Size", shortcut: "⌘1"),
                    ShortcutItem(id: "view-zoom", title: "Zoom In / Out", shortcut: "⌘+ / ⌘-"),
                    ShortcutItem(id: "view-fullscreen", title: "Toggle Full Screen", shortcut: "⌘F"),
                    ShortcutItem(id: "view-inspector", title: "Toggle Inspector", shortcut: "⌘I"),
                    ShortcutItem(id: "view-strip", title: "Toggle Thumbnail Strip", shortcut: "⌥⌘T")
                ]
            ),
            ShortcutGroup(
                id: "file-actions",
                title: "File Actions",
                items: [
                    ShortcutItem(id: "file-rename", title: "Rename", shortcut: "⌘R"),
                    ShortcutItem(id: "file-trash", title: "Move to Trash", shortcut: "⌘⌫"),
                    ShortcutItem(id: "file-clipboard", title: "Copy Image / Paste Image", shortcut: "⌘C / ⌘V"),
                    ShortcutItem(id: "file-move-slot", title: "Move to destination slot", shortcut: "1–9"),
                    ShortcutItem(id: "file-copy-slot", title: "Copy to destination slot", shortcut: "⇧1–9")
                ]
            ),
            ShortcutGroup(
                id: "tools",
                title: "Tools",
                items: [
                    ShortcutItem(id: "tool-slideshow", title: "Slideshow", shortcut: "⌥⌘S"),
                    ShortcutItem(id: "tool-color", title: "Color Adjustments", shortcut: "⌥⌘C"),
                    ShortcutItem(id: "tool-crop", title: "Crop", shortcut: "⌘K"),
                    ShortcutItem(id: "tool-export", title: "Export", shortcut: "⇧⌘E"),
                    ShortcutItem(id: "tool-print", title: "Print", shortcut: "⌘P")
                ]
            )
        ]
    }
}

private struct ShortcutGroup: Identifiable {
    let id: String
    let title: String
    let items: [ShortcutItem]
}

private struct ShortcutItem: Identifiable {
    let id: String
    let title: String
    let shortcut: String
}
