import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// What the pattern editor sheet opens with.
enum PatternEditorRequest: Identifiable {
    /// A new pattern, with the designer filled in when added from a folder.
    case new(designer: String)
    case edit(Pattern)

    var id: String {
        switch self {
        case .new(let designer): "new:\(designer)"
        case .edit(let pattern): "edit:\(pattern.id)"
        }
    }
}

/// The pattern editor sheet.
struct PatternEditor: View {
    private enum Field: Hashable {
        case name, designer, notes
        case brand(UUID), code(UUID), threadName(UUID)
    }

    /// The pattern being edited, or nil for a new one.
    let pattern: Pattern?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query private var stash: [StashThread]
    @Query private var patterns: [Pattern]

    @State private var draft: PatternDraft
    @State private var confirmingDelete = false
    @State private var saveFailed = false
    @State private var importingFile = false
    @State private var viewingPDF = false
    @State private var fileProblem: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var coverProblem: String?
    @State private var takingPhoto = false
    @Environment(\.fakeCamera) private var fakeCamera
    @Environment(\.hideCamera) private var hideCamera
    @FocusState private var focus: Field?

    init(request: PatternEditorRequest) {
        switch request {
        case .new(let designer):
            pattern = nil
            _draft = State(initialValue: PatternDraft(designer: designer))
        case .edit(let pattern):
            self.pattern = pattern
            _draft = State(initialValue: PatternDraft(editing: pattern))
        }
    }

    private var coverage: StashCoverage { StashCoverage(stash: stash) }

    private var designerSuggestions: [String] {
        guard focus == .designer else { return [] }
        return BrandSuggestions.matching(draft.designer, in: DesignerSuggestions.all(from: patterns))
    }

    private func brandSuggestions(for row: EditableThread) -> [String] {
        guard focus == .brand(row.id) else { return [] }
        let brands = BrandSuggestions.all(stashBrands: stash.map(\.brand))
        return BrandSuggestions.matching(row.brand, in: brands)
    }

    var body: some View {
        NavigationStack {
            // Details come first: with a 360-point PDF preview at the top, the
            // name field started below the fold.
            Form {
                detailsSection
                fileSection
                coverSection
                threadsSection
                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focus, equals: .notes)
                        .accessibilityIdentifier("patternEditor.notes")
                }
                if saveFailed {
                    Text("The pattern couldn't be saved. Try again.")
                        .foregroundStyle(Color.warn)
                }
                if pattern != nil {
                    Section {
                        Button("Delete pattern", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(pattern == nil ? "Add pattern" : "Edit pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.canSave)
                }
            }
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text(deleteMessage)
            }
            .onAppear {
                if pattern == nil { focus = .name }
            }
            .fileImporter(isPresented: $importingFile, allowedContentTypes: [.pdf, .image]) { result in
                switch result {
                case .success(let url): attachFile(at: url)
                case .failure: fileProblem = "That file couldn't be opened."
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await useCoverPhoto(item) }
            }
            .fullScreenCover(isPresented: $takingPhoto) {
                CameraPicker { image in
                    takingPhoto = false
                    if let image { useCameraPhoto(image) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $viewingPDF) {
                if let file = draft.file {
                    PDFViewer(file: file)
                }
            }
        }
        // The default iPad form sheet is 660 points tall, too short for the
        // PDF preview and the fields around it.
        .presentationSizing(.page)
    }

    // MARK: - Pattern file and cover

    private var fileSection: some View {
        Section("Pattern file") {
            if let file = draft.file {
                if file.isPDF {
                    PDFKitView(data: file.data, accessibilityID: "patternEditor.pdfPreview")
                        .frame(height: 360)
                    Button("Open PDF full screen") { viewingPDF = true }
                } else if file.isImage, let image = UIImage(data: file.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .accessibilityLabel("Pattern image")
                }
                if !file.name.isEmpty {
                    Text(file.name)
                        .foregroundStyle(Color.mute)
                }
            } else {
                Text("No file yet")
                    .foregroundStyle(Color.mute)
            }
            Button(draft.file == nil ? "Attach file" : "Replace file") { importingFile = true }
            if let fileProblem {
                Text(fileProblem)
                    .foregroundStyle(Color.warn)
            }
        }
    }

    private var coverSection: some View {
        Section {
            if let cover = draft.cover, let image = UIImage(data: cover) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .accessibilityLabel("Cover photo")
                    .accessibilityIdentifier("patternEditor.coverPreview")
                Button("Remove cover", role: .destructive) { draft.cover = nil }
            }
            PhotosPicker("Choose a photo", selection: $photoItem, matching: .images)
            if !hideCamera && (fakeCamera || CameraPicker.isAvailable) {
                Button("Take a photo") {
                    if fakeCamera {
                        useCameraPhoto(CameraPicker.fakePhoto())
                    } else {
                        takingPhoto = true
                    }
                }
            }
            if draft.canUseFirstPageAsCover {
                Button("Use page 1 of the PDF") {
                    coverProblem = draft.useFirstPageAsCover() ? nil : "Page 1 of the PDF couldn't be read."
                }
            }
            if let coverProblem {
                Text(coverProblem)
                    .foregroundStyle(Color.warn)
            }
        } header: {
            Text("Cover photo")
        } footer: {
            if draft.cover == nil && draft.file?.isImage == true {
                Text("With no cover, cards show the pattern image.")
            }
        }
    }

    private func attachFile(at url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            // Check the size before reading, so a huge file isn't loaded just to be rejected.
            if let size = values.fileSize, size > AttachedFile.maxBytes {
                throw AttachedFile.Problem.tooLarge
            }
            let type = values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data
            draft.file = try AttachedFile.make(data: Data(contentsOf: url), name: url.lastPathComponent, type: type)
            fileProblem = nil
        } catch let problem as AttachedFile.Problem {
            fileProblem = problem.message
        } catch {
            fileProblem = "That file couldn't be opened."
        }
    }

    private func useCameraPhoto(_ image: UIImage) {
        coverProblem = draft.useCameraPhoto(image) ? nil : "That photo couldn't be used."
    }

    private func useCoverPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = CoverRenderer.jpeg(fromImage: data)
        else {
            coverProblem = "That photo couldn't be used."
            return
        }
        draft.cover = jpeg
        coverProblem = nil
    }

    private var detailsSection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .focused($focus, equals: .name)
                .submitLabel(.next)
                .onSubmit { focus = .designer }
                .accessibilityIdentifier("patternEditor.name")
            TextField("Designer", text: $draft.designer)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focus, equals: .designer)
                .accessibilityIdentifier("patternEditor.designer")
            if !designerSuggestions.isEmpty {
                SuggestionChips(suggestions: designerSuggestions) { designer in
                    draft.designer = designer
                    focus = nil
                }
            }
            Picker("Status", selection: $draft.status) {
                ForEach(PatternStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
            Picker("Mesh", selection: $draft.mesh) {
                Text("Not set").tag(Mesh?.none)
                ForEach(Mesh.allCases, id: \.self) { mesh in
                    Text(mesh.label).tag(Optional(mesh))
                }
            }
        }
    }

    private var threadsSection: some View {
        Section("Threads") {
            ForEach($draft.threads) { $row in
                ThreadRowEditor(
                    row: $row,
                    supply: row.hasKey ? coverage.supply(of: row.patternThread) : nil,
                    brandSuggestions: brandSuggestions(for: row),
                    focus: $focus,
                    brandField: .brand(row.id),
                    codeField: .code(row.id),
                    nameField: .threadName(row.id),
                    onRemove: { draft.removeThreadRow(row.id) })
            }
            Button {
                let id = draft.addThreadRow()
                // The new row's field doesn't exist until the next update, and
                // SwiftUI ignores focus on a field that isn't on screen yet.
                Task { focus = .code(id) }
            } label: {
                Label("Add thread", systemImage: "plus")
            }
            .accessibilityIdentifier("patternEditor.addThread")
        }
    }

    private var deleteTitle: String {
        pattern.map { PatternDraft.deleteConfirmation(for: $0).title } ?? ""
    }

    private var deleteMessage: String {
        pattern.map { PatternDraft.deleteConfirmation(for: $0).message } ?? ""
    }

    private func save() {
        do {
            try draft.save(to: pattern, in: context)
            toasts.show(PatternDraft.savedToast)
            dismiss()
        } catch {
            saveFailed = true
        }
    }

    private func delete() {
        guard let pattern else { return }
        do {
            try PatternDraft.delete(pattern, in: context)
            toasts.show(PatternDraft.deletedToast)
            dismiss()
        } catch {
            saveFailed = true
        }
    }

    /// One thread row: brand, number, color name, quantity and a remove
    /// button, with the stash status underneath.
    private struct ThreadRowEditor: View {
        @Binding var row: EditableThread
        let supply: ThreadSupply?
        let brandSuggestions: [String]
        var focus: FocusState<Field?>.Binding
        let brandField: Field
        let codeField: Field
        let nameField: Field
        let onRemove: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // One layout only: building the fields twice for ViewThatFits
                // would give each identifier and focus value two text fields.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        brand
                        code.frame(width: 110)
                    }
                    name
                    HStack {
                        quantity
                        Spacer()
                        removeButton
                    }
                }
                .textFieldStyle(.roundedBorder)
                if !brandSuggestions.isEmpty {
                    SuggestionChips(suggestions: brandSuggestions) { brand in
                        row.brand = brand
                        focus.wrappedValue = codeField
                    }
                }
                if let supply {
                    Text(supply.label)
                        .font(.appBody(13, relativeTo: .caption).weight(.semibold))
                        .foregroundStyle(supplyColor(supply))
                        .accessibilityIdentifier("threadRow.status")
                }
            }
            .padding(.vertical, 4)
        }

        private var brand: some View {
            TextField("Brand", text: $row.brand)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused(focus, equals: brandField)
                .accessibilityIdentifier("threadRow.brand")
        }

        private var code: some View {
            TextField("Number", text: $row.code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused(focus, equals: codeField)
                .accessibilityIdentifier("threadRow.code")
        }

        private var name: some View {
            TextField("Color name or where it's used", text: $row.name)
                .focused(focus, equals: nameField)
                .accessibilityIdentifier("threadRow.name")
        }

        private var quantity: some View {
            Stepper(value: $row.qty, in: 1...99) {
                Text("\(row.qty)")
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)
            }
            .fixedSize()
            .accessibilityLabel("Quantity")
            .accessibilityValue("\(row.qty)")
            .accessibilityIdentifier("threadRow.qty")
        }

        private var removeButton: some View {
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove thread")
        }

        private func supplyColor(_ supply: ThreadSupply) -> Color {
            if case .covered = supply { return Color("OK") }
            return Color.warn
        }
    }
}

/// A PDF filling the screen, opened from the editor's "Open PDF full screen".
private struct PDFViewer: View {
    let file: AttachedFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(data: file.data, accessibilityID: "patternViewer.pdf")
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(file.name.isEmpty ? "Pattern" : file.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
