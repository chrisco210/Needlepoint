import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Edit folder image": the folder tile's image, fit and background.
struct FolderImageEditor: View {
    let folderKey: String
    let folderName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts

    @State private var draft: FolderImageDraft
    @State private var photoItem: PhotosPickerItem?
    @State private var importingFile = false
    @State private var problem: String?

    init(folderKey: String, folderName: String, style: FolderStyle?) {
        self.folderKey = folderKey
        self.folderName = folderName
        _draft = State(initialValue: FolderImageDraft(style: style))
    }

    /// ColorPicker works in `Color`; the draft keeps the stored `#rrggbb` string.
    private var customColor: Binding<Color> {
        Binding(
            get: { Color(swatch: draft.background) },
            set: { draft.background = HexColor($0).string })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                }

                Section("Image") {
                    PhotosPicker("Choose a photo", selection: $photoItem, matching: .images)
                    Button("Choose an image file") { importingFile = true }
                    if draft.imageData != nil {
                        Button("Remove image", role: .destructive) { draft.imageData = nil }
                    }
                    if let problem {
                        Text(problem)
                            .foregroundStyle(Color.warn)
                    }
                }

                Section("Fit") {
                    Picker("Fit", selection: $draft.fit) {
                        Text("Show whole image (best for logos)").tag(FolderStyle.Fit.contain)
                        Text("Fill the tile").tag(FolderStyle.Fit.cover)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Background") {
                    HStack(spacing: 12) {
                        ForEach(FolderImageDraft.backgrounds, id: \.hex) { option in
                            swatchButton(option)
                        }
                    }
                    .padding(.vertical, 4)
                    ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                }
            }
            .navigationTitle("Folder image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .fileImporter(isPresented: $importingFile, allowedContentTypes: [.image]) { result in
                guard case .success(let url) = result else {
                    problem = FolderImageDraft.ImageError.unreadable.message
                    return
                }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
                    ?? UTType(filenameExtension: url.pathExtension) ?? .image
                setImage((try? Data(contentsOf: url)) ?? Data(), type: type)
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    setImage(data ?? Data(), type: item.supportedContentTypes.first ?? .jpeg)
                    photoItem = nil
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 8) {
            ZStack {
                Color(swatch: draft.background)
                if let data = draft.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: draft.fit == .contain ? .fit : .fill)
                        .padding(draft.fit == .contain ? 12 : 0)
                } else {
                    Text("No image")
                        .foregroundStyle(isDark(draft.background) ? .white : Color.mute)
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxWidth: 320)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of the \(folderName) folder tile")
            .accessibilityIdentifier("folderImage.preview")
        }
        .frame(maxWidth: .infinity)
    }

    private func swatchButton(_ option: FolderImageDraft.Background) -> some View {
        let selected = draft.background.lowercased() == option.hex
        return Button {
            draft.background = option.hex
        } label: {
            Circle()
                .fill(Color(swatch: option.hex))
                .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.line, lineWidth: selected ? 3 : 1))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The web app showed white "No image" text on the plum and ink backgrounds.
    private func isDark(_ hex: String) -> Bool {
        guard let color = HexColor(hex) else { return false }
        return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue < 0.5
    }

    private func setImage(_ data: Data, type: UTType) {
        do {
            try draft.setImage(data, type: type)
            problem = nil
        } catch {
            problem = FolderImageDraft.ImageError.unreadable.message
        }
    }

    private func save() {
        do {
            try draft.save(folderKey: folderKey, in: context)
            toasts.show(FolderImageDraft.toast)
            dismiss()
        } catch {
            problem = "The folder image couldn't be saved. Try again."
        }
    }
}
