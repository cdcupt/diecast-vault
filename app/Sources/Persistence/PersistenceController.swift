import Foundation
import SwiftData
import DiecastVaultCore

/// Owns the app's local SwiftData container and the first-run seed. Local-first
/// and device-only: a plain on-disk `ModelContainer` with **iCloud sync OFF** in
/// slice 2 (no `cloudKitDatabase`), so the collection persists across launches
/// with zero network. The seed runs once when the store is empty.
@MainActor
enum PersistenceController {

    /// The shared production container (on-disk). Falls back to in-memory if the
    /// on-disk store can't be opened, so the app never hard-crashes at launch.
    static let shared: ModelContainer = {
        let schema = Schema([OwnedModel.self])
        do {
            let config = ModelConfiguration("DiecastVault", schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: config)
            seedIfEmpty(container.mainContext)
            return container
        } catch {
            // Last-resort in-memory store keeps the UI alive. Actually logged —
            // an invisible ephemeral fallback would mean every "saved" car
            // silently evaporates on relaunch with no trace to triage.
            AppLog.persistence.fault("persistent store failed to open, falling back to in-memory: \(error, privacy: .public)")
            let config = ModelConfiguration("DiecastVault-fallback", schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            let container = try! ModelContainer(for: schema, configurations: config)
            seedIfEmpty(container.mainContext)
            return container
        }
    }()

    /// An in-memory container for previews / tests.
    static func inMemory(seeded: Bool = true) -> ModelContainer {
        let schema = Schema([OwnedModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: config)
        if seeded { seedIfEmpty(container.mainContext) }
        return container
    }

    /// Seed the local collection from the bundled sample data exactly once
    /// (when the store has no owned rows yet). Idempotent on subsequent launches.
    static func seedIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<OwnedModel>())) ?? 0
        guard existing == 0 else { return }
        for copy in OwnedCopy.sampleSeed {
            context.insert(OwnedModel(copy))
        }
        do {
            try context.save()
        } catch {
            AppLog.persistence.error("first-run seed save failed: \(error, privacy: .public)")
        }
    }
}
