import SwiftData
import SwiftUI

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

/// The pattern editor sheet. The pattern file and cover photo come in a later change.
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
            Form {
                detailsSection
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
        }
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
