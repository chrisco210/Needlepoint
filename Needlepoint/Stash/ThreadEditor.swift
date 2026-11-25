import SwiftData
import SwiftUI

/// What the thread editor sheet opens with.
enum ThreadEditorRequest: Identifiable {
    case add
    case edit(StashThread)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let thread): "edit:\(thread.id)"
        }
    }
}

/// The Add thread and Edit thread sheet.
struct ThreadEditor: View {
    private enum Field { case brand, code, name, qty }

    /// The thread being edited, or nil when adding one.
    let thread: StashThread?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @Query private var stash: [StashThread]

    @State private var draft: ThreadDraft
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @FocusState private var focus: Field?

    init(request: ThreadEditorRequest = .add) {
        switch request {
        case .add:
            thread = nil
            _draft = State(initialValue: ThreadDraft())
        case .edit(let thread):
            self.thread = thread
            _draft = State(initialValue: ThreadDraft(editing: thread))
        }
    }

    private var brandSuggestions: [String] {
        guard focus == .brand else { return [] }
        let brands = BrandSuggestions.all(stashBrands: stash.map(\.brand))
        return BrandSuggestions.matching(draft.brand, in: brands)
    }

    /// ColorPicker works in `Color`; the draft keeps the stored `#rrggbb` string.
    private var swatch: Binding<Color> {
        Binding(
            get: { Color(swatch: draft.color) },
            set: { draft.color = HexColor($0).string })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand", text: $draft.brand)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .brand)
                        .submitLabel(.next)
                        .onSubmit { focus = .code }
                        .accessibilityIdentifier("threadEditor.brand")
                    if !brandSuggestions.isEmpty {
                        SuggestionChips(suggestions: brandSuggestions) { brand in
                            draft.brand = brand
                            focus = .code
                        }
                    }
                    TextField("Color number", text: $draft.code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .code)
                        .submitLabel(.next)
                        .onSubmit { focus = .name }
                        .accessibilityIdentifier("threadEditor.code")
                    TextField("Color name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($focus, equals: .name)
                        .submitLabel(.done)
                        .accessibilityIdentifier("threadEditor.name")
                }

                Section {
                    ColorPicker("Swatch", selection: swatch, supportsOpacity: false)
                    quantityRow
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.warn)
                }

                if thread != nil {
                    Section {
                        Button("Remove from stash", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(thread == nil ? "Add thread" : "Edit thread")
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
            .onAppear {
                if thread == nil { focus = .brand }
            }
            .confirmationDialog(
                thread.map { StashDelete.confirmation(for: $0).title } ?? "",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive, action: delete)
            } message: {
                Text(thread.map { StashDelete.confirmation(for: $0).message } ?? "")
            }
        }
    }

    private var quantityRow: some View {
        HStack {
            Text("Quantity on hand")
            Spacer()
            TextField("Quantity", value: $draft.qty, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)
                .focused($focus, equals: .qty)
                .accessibilityLabel("Quantity on hand")
            Stepper("Quantity on hand", value: $draft.qty, in: 0...999)
                .labelsHidden()
                .accessibilityIdentifier("threadEditor.qty")
        }
    }

    private func save() {
        do {
            let outcome = try draft.save(editing: thread, in: context)
            try context.save()
            toasts.show(outcome.toast)
            dismiss()
        } catch let error as ThreadDraft.SaveError {
            errorMessage = error.message
        } catch {
            errorMessage = "The thread couldn't be saved. Try again."
        }
    }

    private func delete() {
        guard let thread else { return }
        do {
            try StashDelete.delete(thread, in: context)
            toasts.show(StashDelete.toast)
            dismiss()
        } catch {
            errorMessage = "The thread couldn't be removed. Try again."
        }
    }
}
