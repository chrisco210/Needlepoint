import Foundation

/// Brand names offered while typing in a brand field.
nonisolated enum BrandSuggestions {
    static let builtIn = [
        "DMC Pearl Cotton #3", "DMC Pearl Cotton #5", "DMC Floss", "Silk & Ivory", "Splendor",
        "Vineyard Silk", "Planet Earth Fiber", "Rainbow Gallery Neon Rays",
        "Rainbow Gallery Fyre Werks", "Kreinik #12 Braid", "Pepper Pot Silk", "Appleton Wool",
        "Paternayan", "Watercolours", "Silk Lamé Braid", "Entice", "Bravo!",
    ]

    /// The built-in brands, then any other brands from the stash, sorted.
    /// Brands that differ only in case or surrounding whitespace appear once.
    static func all(stashBrands: [String]) -> [String] {
        var seen = Set(builtIn.map(normalize))
        var extra: [String] = []
        for brand in stashBrands {
            let trimmed = brand.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(normalize(trimmed)).inserted else { continue }
            extra.append(trimmed)
        }
        return builtIn + extra.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Brands containing `query`, ignoring case. Brands that start with it come
    /// first. A brand the user has already typed in full isn't suggested.
    static func matching(_ query: String, in brands: [String], limit: Int = 6) -> [String] {
        let needle = normalize(query)
        guard !needle.isEmpty else { return [] }
        let hits = brands.filter {
            let brand = normalize($0)
            return brand != needle && brand.contains(needle)
        }
        let prefix = hits.filter { normalize($0).hasPrefix(needle) }
        let other = hits.filter { !normalize($0).hasPrefix(needle) }
        return Array((prefix + other).prefix(limit))
    }

    private static func normalize(_ brand: String) -> String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
