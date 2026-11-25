import Foundation

/// One brand's threads in the stash list.
struct StashSection: Identifiable {
    /// The brand as written on the first thread found with it.
    let brand: String
    let threads: [StashThread]

    var id: String { brand.lowercased() }
}

enum StashSections {
    /// Groups threads by brand, ignoring case and surrounding whitespace.
    /// Sections sort by brand and threads by code, both with numeric-aware
    /// comparison, so "34" comes before "310".
    static func make(from threads: [StashThread]) -> [StashSection] {
        let groups = Dictionary(grouping: threads) { $0.key.brand }
        return groups.values
            .map { group in
                StashSection(
                    brand: group[0].brand,
                    threads: group.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending })
            }
            .sorted { $0.brand.localizedStandardCompare($1.brand) == .orderedAscending }
    }
}
