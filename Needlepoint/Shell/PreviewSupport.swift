#if DEBUG
import SwiftData
import SwiftUI

// Previews get what the app normally sets up in MyApp and RootView: a model
// container and a ToastCenter in the environment. Without them, views that use
// @Query or show toasts crash in the canvas.
//
//     #Preview(traits: .sampleLibrary) { StashTab() }

extension PreviewTrait where T == Preview.ViewTraits {
    /// The sample library from `SampleData`: two stash threads, three patterns.
    static var sampleLibrary: Self { .modifier(SampleLibraryPreview()) }
    /// An empty store, for the empty states.
    static var emptyLibrary: Self { .modifier(EmptyLibraryPreview()) }
}

private struct SampleLibraryPreview: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try SampleData.container()
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modifier(PreviewEnvironment(container: context))
    }
}

private struct EmptyLibraryPreview: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try SampleData.container(seeded: false)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modifier(PreviewEnvironment(container: context))
    }
}

private struct PreviewEnvironment: ViewModifier {
    let container: ModelContainer
    @State private var toasts = ToastCenter()

    func body(content: Content) -> some View {
        content
            .toastOverlay(toasts)
            .environment(toasts)
            .modelContainer(container)
    }
}
#endif
