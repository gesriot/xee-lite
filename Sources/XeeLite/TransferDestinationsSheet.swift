import AppKit
import SwiftUI

struct TransferDestinationsSheet: View {
    let destinations: [FileActionDestination]
    let currentImageURL: URL?
    let onChooseDestination: (Int, URL) -> Void
    let onClearDestination: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transfer Destinations")
                .font(.title3.weight(.semibold))

            Text("Use number keys `1–9` to move the current file. Use `Shift+1–9` to copy it.")
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(destinations) { destination in
                        row(for: destination)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 460)
    }

    private func row(for destination: FileActionDestination) -> some View {
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
                        onClearDestination(destination.slotNumber)
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
                .fill(Color(nsColor: .windowBackgroundColor))
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
        panel.directoryURL = destination.url ?? currentImageURL?.deletingLastPathComponent()

        if panel.runModal() == .OK, let folderURL = panel.url?.standardizedFileURL {
            onChooseDestination(destination.slotNumber, folderURL)
        }
    }
}
