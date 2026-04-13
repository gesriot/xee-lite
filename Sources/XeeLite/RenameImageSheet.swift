import SwiftUI

struct RenameImageSheet: View {
    let imageURL: URL
    let validationMessage: (String) -> String?
    let onRename: (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFieldFocused: Bool
    @State private var draftName: String
    @State private var submitErrorMessage: String?

    init(
        imageURL: URL,
        validationMessage: @escaping (String) -> String?,
        onRename: @escaping (String) throws -> Void
    ) {
        self.imageURL = imageURL
        self.validationMessage = validationMessage
        self.onRename = onRename
        _draftName = State(initialValue: imageURL.deletingPathExtension().lastPathComponent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename File")
                .font(.title3.weight(.semibold))

            Text("Rename the current image in place. The file extension stays unchanged.")
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("File name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)

                if let pathExtension, !pathExtension.isEmpty {
                    Text(".\(pathExtension)")
                        .foregroundStyle(.secondary)
                }
            }

            if let message = currentMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Current file: \(imageURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    submitRename()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRenameDisabled)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            DispatchQueue.main.async {
                isNameFieldFocused = true
            }
        }
        .onChange(of: draftName) { _, _ in
            submitErrorMessage = nil
        }
    }

    private var originalBaseName: String {
        imageURL.deletingPathExtension().lastPathComponent
    }

    private var pathExtension: String? {
        let value = imageURL.pathExtension
        return value.isEmpty ? nil : value
    }

    private var liveValidationMessage: String? {
        validationMessage(draftName)
    }

    private var currentMessage: String? {
        submitErrorMessage ?? liveValidationMessage
    }

    private var isRenameDisabled: Bool {
        let trimmedDraftName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraftName.isEmpty || trimmedDraftName == originalBaseName || liveValidationMessage != nil
    }

    private func submitRename() {
        do {
            try onRename(draftName)
            dismiss()
        } catch {
            submitErrorMessage = error.localizedDescription
        }
    }
}
