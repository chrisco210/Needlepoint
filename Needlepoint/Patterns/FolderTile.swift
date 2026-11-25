import SwiftUI
import UIKit

/// A designer folder on the Patterns tab.
struct FolderTile: View {
    let folder: PatternFolder
    let style: FolderStyle?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FolderArt(folder: folder, style: style)
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.heading(21, relativeTo: .title3))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(detailLine)
                    .font(.appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.mute)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line))
    }

    private var detailLine: String {
        [folder.countLabel, folder.inProgressLabel].compactMap(\.self).joined(separator: " · ")
    }

    var accessibilityText: String {
        [folder.name, folder.countLabel, folder.inProgressLabel].compactMap(\.self).joined(separator: ", ")
    }
}

/// The tile image: the folder's own image, a mosaic of up to four pattern
/// covers, or a folder glyph with the designer's initial.
private struct FolderArt: View {
    let folder: PatternFolder
    let style: FolderStyle?

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay { content }
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if let style, let data = style.imageData, let image = UIImage(data: data) {
            ZStack {
                Color(swatch: style.background)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: style.fit == .contain ? .fit : .fill)
                    .padding(style.fit == .contain ? 12 : 0)
            }
        } else if !folder.coverImages.isEmpty {
            mosaic(folder.coverImages.compactMap(UIImage.init(data:)))
        } else {
            ZStack {
                // A background chosen in "Edit folder image" shows even without an image.
                style.map { Color(swatch: $0.background) } ?? Color.blush
                Image(systemName: "folder.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.plum)
                if let initial = folder.initial {
                    Text(initial)
                        .font(.heading(26, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .offset(y: 5)
                }
            }
        }
    }

    @ViewBuilder
    private func mosaic(_ images: [UIImage]) -> some View {
        if images.count == 1 {
            cell(images[0])
        } else {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    cell(images[0])
                    cell(images[1])
                }
                if images.count > 2 {
                    GridRow {
                        cell(images[2])
                        if images.count > 3 { cell(images[3]) } else { Color.blush }
                    }
                }
            }
        }
    }

    private func cell(_ image: UIImage) -> some View {
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
