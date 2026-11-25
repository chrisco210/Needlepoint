import Testing
@testable import Needlepoint

struct PatternStatusTests {
    @Test func rawValuesMatchTheWebAppData() {
        #expect(PatternStatus.allCases.map(\.rawValue) == [
            "Wishlist", "Not started", "In progress", "Needs finishing", "Finished",
        ])
    }

    @Test func labelsMatchTheReadme() {
        #expect(PatternStatus.allCases.map(\.label) == [
            "Wishlist", "Not started", "Stitching", "Stitched, needs finishing", "Finished",
        ])
    }

    @Test func sortOrderPutsWorkInProgressFirst() {
        let sorted = PatternStatus.allCases.sorted { $0.sortRank < $1.sortRank }
        #expect(sorted == [.inProgress, .needsFinishing, .notStarted, .wishlist, .finished])
    }

    @Test func onlyStitchingAndNeedsFinishingAreWorkInProgress() {
        #expect(PatternStatus.allCases.filter(\.isWorkInProgress) == [.inProgress, .needsFinishing])
    }
}

struct MeshTests {
    @Test func rawValuesMatchTheWebAppData() {
        #expect(Mesh.allCases.map(\.rawValue) == ["10", "13", "18", "Other"])
    }

    @Test func labelsReadAsMeshCounts() {
        #expect(Mesh.allCases.map(\.label) == ["10 mesh", "13 mesh", "18 mesh", "Other mesh"])
    }
}
