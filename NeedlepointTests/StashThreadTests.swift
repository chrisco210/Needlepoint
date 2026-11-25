import Foundation
import SwiftData
import Testing
@testable import Needlepoint

/// Swift Testing makes a new instance for each test, so each test gets its
/// own empty in-memory store.
@MainActor
struct StashThreadTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: StashThread.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allThreads() throws -> [StashThread] {
        try context.fetch(FetchDescriptor<StashThread>())
    }

    // MARK: - Initializer and quantity

    @Test func initTrimsFieldsAndSetsDefaults() {
        let thread = StashThread(brand: "  DMC Floss ", code: " 310 ", name: " Black ")
        #expect(thread.brand == "DMC Floss")
        #expect(thread.code == "310")
        #expect(thread.name == "Black")
        #expect(thread.color == StashThread.unknownColor)
        #expect(thread.qty == 1)
        #expect(thread.key == ThreadKey(brand: "dmc floss", code: "310"))
    }

    @Test func initClampsNegativeQuantityToZero() {
        #expect(StashThread(brand: "DMC", code: "310", qty: -3).qty == 0)
    }

    @Test(arguments: [(5, -2, 3), (2, -5, 0), (0, -1, 0), (0, 4, 4)])
    func adjustQuantityNeverGoesBelowZero(start: Int, delta: Int, expected: Int) {
        let thread = StashThread(brand: "DMC", code: "310", qty: start)
        thread.adjustQuantity(by: delta)
        #expect(thread.qty == expected)
    }

    @Test func setQuantityClampsToZero() {
        let thread = StashThread(brand: "DMC", code: "310", qty: 4)
        thread.setQuantity(-1)
        #expect(thread.qty == 0)
    }

    @Test func setIdentityUpdatesTheMatchKey() throws {
        let thread = StashThread(brand: "DMC", code: "310")
        context.insert(thread)
        thread.setIdentity(brand: " Silk & Ivory ", code: "01")

        #expect(thread.brand == "Silk & Ivory")
        #expect(try StashThread.find(ThreadKey(brand: "silk & ivory", code: "01"), in: context) === thread)
        #expect(try StashThread.find(ThreadKey(brand: "DMC", code: "310"), in: context) == nil)
    }

    // MARK: - find

    @Test func findMatchesIgnoringCaseAndWhitespace() throws {
        let thread = StashThread(brand: "DMC Floss", code: "310")
        context.insert(thread)
        #expect(try StashThread.find(ThreadKey(brand: " dmc FLOSS", code: "310 "), in: context) === thread)
    }

    @Test func findReturnsNilForAnUnknownKey() throws {
        context.insert(StashThread(brand: "DMC Floss", code: "310"))
        #expect(try StashThread.find(ThreadKey(brand: "DMC Floss", code: "0310"), in: context) == nil)
    }

    // MARK: - upsert (Add thread editor)

    @Test func upsertInsertsANewThread() throws {
        let thread = try StashThread.upsert(
            brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2, in: context)

        #expect(try allThreads().count == 1)
        #expect(thread.name == "Black")
        #expect(thread.color == "#000000")
        #expect(thread.qty == 2)
    }

    @Test func upsertOverwritesAnExistingKeyInsteadOfDuplicating() throws {
        let first = try StashThread.upsert(
            brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2, in: context)
        let created = first.created

        let second = try StashThread.upsert(
            brand: " dmc floss", code: "310 ", name: "Noir", color: "#111111", qty: 5, in: context)

        #expect(second === first)
        #expect(try allThreads().count == 1)
        #expect(second.brand == "dmc floss")
        #expect(second.name == "Noir")
        #expect(second.color == "#111111")
        #expect(second.qty == 5)
        #expect(second.created == created)
    }

    @Test func upsertClampsNegativeQuantity() throws {
        let thread = try StashThread.upsert(
            brand: "DMC", code: "310", name: "", color: "#000000", qty: -2, in: context)
        #expect(thread.qty == 0)
    }

    // MARK: - addStock (Paste a list, Bought it)

    @Test func addStockCreatesAThreadWithTheUnknownSwatch() throws {
        let thread = try StashThread.addStock(3, brand: "Silk & Ivory", code: "01", name: "Snow", in: context)

        #expect(try allThreads().count == 1)
        #expect(thread.name == "Snow")
        #expect(thread.color == StashThread.unknownColor)
        #expect(thread.qty == 3)
    }

    @Test func addStockAddsToAnExistingThreadAndKeepsItsDetails() throws {
        let existing = try StashThread.upsert(
            brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2, in: context)

        let result = try StashThread.addStock(3, brand: "DMC FLOSS", code: "310", name: "Other name", in: context)

        #expect(result === existing)
        #expect(try allThreads().count == 1)
        #expect(result.qty == 5)
        #expect(result.name == "Black")
        #expect(result.color == "#000000")
        #expect(result.brand == "DMC Floss")
    }

    @Test func addStockIgnoresANegativeAmount() throws {
        let existing = try StashThread.addStock(4, brand: "DMC", code: "310", in: context)
        try StashThread.addStock(-2, brand: "DMC", code: "310", in: context)
        #expect(existing.qty == 4)
    }

    @Test func addStockKeepsDifferentCodesSeparate() throws {
        try StashThread.addStock(1, brand: "DMC", code: "310", in: context)
        try StashThread.addStock(1, brand: "DMC", code: "0310", in: context)
        #expect(try allThreads().count == 2)
    }

    // MARK: - Persistence

    @Test func savedThreadsCanBeFetchedFromANewContext() throws {
        try StashThread.upsert(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2, in: context)
        try context.save()

        let other = ModelContext(container)
        let fetched = try StashThread.find(ThreadKey(brand: "dmc floss", code: "310"), in: other)
        #expect(fetched?.name == "Black")
        #expect(fetched?.qty == 2)
    }
}
