import SwiftData
import SwiftUI
import UIKit

/// A pattern's card, used on every tab that lists patterns.
struct PatternCard: View {
    let pattern: Pattern
    let coverage: StashCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            VStack(alignment: .leading, spacing: 8) {
                Text(pattern.name)
                    .font(.heading(21, relativeTo: .title3))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(metaLine)
                    .font(.appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.mute)
                StatusPill(status: pattern.status)
                progress
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("patternCard")
    }

    private var metaLine: String {
        [pattern.designerLabel, pattern.mesh?.label].compactMap(\.self).joined(separator: " · ")
    }

    private var progressLabel: String { coverage.progressLabel(for: pattern) }

    private var accessibilityText: String {
        [pattern.name, pattern.designerLabel, pattern.mesh?.label, pattern.status.label, progressLabel]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    private var cover: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                if let data = pattern.displayImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 6) {
                        Text(pattern.placeholderLabel)
                            .font(.heading(22, relativeTo: .title3))
                            .foregroundStyle(Color.plum)
                        if !pattern.fileName.isEmpty {
                            Text(pattern.fileName)
                                .font(.appBody(13, relativeTo: .caption))
                                .foregroundStyle(Color.mute)
                                .lineLimit(1)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blush)
                }
            }
            .clipped()
    }

    @ViewBuilder
    private var progress: some View {
        if pattern.threads.isEmpty {
            Text(progressLabel)
                .font(.appBody(14, relativeTo: .subheadline))
                .foregroundStyle(Color.mute)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(coverage.coveredCount(in: pattern)), total: Double(pattern.threads.count))
                    .tint(Color("OK"))
                Text(progressLabel)
                    .font(.appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.mute)
            }
        }
    }
}

/// The status label on a card. Stitching, Needs finishing and Finished get
/// the web app's colors; the rest sit on blush.
struct StatusPill: View {
    let status: PatternStatus

    var body: some View {
        Text(status.label)
            .font(.appBody(13, relativeTo: .caption).weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch status {
        case .inProgress: .accentFill
        case .needsFinishing: .plumFill
        case .finished: Color("OKFill")
        case .wishlist, .notStarted: .blush
        }
    }

    private var foreground: Color {
        switch status {
        case .inProgress, .needsFinishing, .finished: .white
        case .wishlist, .notStarted: .ink
        }
    }
}

#Preview(traits: .sampleLibrary) {
    @Previewable @Query var patterns: [Pattern]
    @Previewable @Query var stash: [StashThread]
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
            ForEach(patterns) { pattern in
                PatternCard(pattern: pattern, coverage: StashCoverage(stash: stash))
            }
        }
        .padding()
    }
}

#Preview("Status pills") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(PatternStatus.allCases, id: \.self) { StatusPill(status: $0) }
    }
    .padding()
}
