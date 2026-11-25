import Testing
@testable import Needlepoint

@MainActor
struct StashSectionsTests {
    private func thread(_ brand: String, _ code: String) -> StashThread {
        StashThread(brand: brand, code: code)
    }

    @Test func emptyStashHasNoSections() {
        #expect(StashSections.make(from: []).isEmpty)
    }

    @Test func groupsByBrandSortedByName() {
        let sections = StashSections.make(from: [
            thread("Silk & Ivory", "01"), thread("DMC Floss", "310"), thread("Appleton Wool", "991"),
        ])
        #expect(sections.map(\.brand) == ["Appleton Wool", "DMC Floss", "Silk & Ivory"])
    }

    @Test func brandsThatDifferOnlyInCaseShareASection() {
        let sections = StashSections.make(from: [thread("DMC Floss", "310"), thread("dmc floss", "321")])
        #expect(sections.count == 1)
        #expect(sections.first?.threads.count == 2)
    }

    @Test func sortsCodesNumerically() {
        let sections = StashSections.make(from: [
            thread("DMC", "310"), thread("DMC", "3865"), thread("DMC", "B5200"), thread("DMC", "34"),
        ])
        #expect(sections.first?.threads.map(\.code) == ["34", "310", "3865", "B5200"])
    }
}
