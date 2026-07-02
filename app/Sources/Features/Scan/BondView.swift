import SwiftUI
import SwiftData
import DiecastVaultCore

/// The BOND step (mockup #s-bond) — deliberately SEPARATE from scanning. It
/// attaches the catalog identity `(mgtNumber, drive)` + optional per-copy edition
/// serial to a model and saves it to the local collection, where it appears LIT
/// in the 3D cabinet. Identity never depends on a scan succeeding: this same
/// screen bonds a freshly-kept scan, a community model, or (the DEV path) the
/// bundled sample USDZ.
///
/// The number is matched live against the bundled catalog so the user gets the
/// car's name back as confirmation. The drive toggle is the teal-L / amber-R
/// control; drive is required because it is half the dedup key.
struct BondView: View {
    /// The scan being bonded. `nil` on the dev / invite path (no live scan) —
    /// `hasModel` is still true because the bundled sample USDZ is attached, so
    /// the bonded niche lights up and the bond→save→cabinet chain is verifiable
    /// without a camera.
    let scanResult: ScanResult?
    /// When the bond was launched from a release's gap-nudge, the form opens
    /// pre-seeded with that release's `(number, drive)` so a world-first lights the
    /// correct niche.
    var prefillKey: CatalogKey? = nil

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: ScanRouter

    @State private var draft: BondDraft

    init(scanResult: ScanResult?, prefillKey: CatalogKey? = nil) {
        self.scanResult = scanResult
        self.prefillKey = prefillKey
        if let key = prefillKey {
            _draft = State(initialValue: BondDraft(mgtNumber: key.mgtNumber, drive: key.drive))
        } else {
            _draft = State(initialValue: BondDraft())
        }
    }

    /// Live catalog match for the typed number (any drive) — drives the confirmation chip.
    private var match: Release? {
        let normalized = CatalogKey.normalize(draft.mgtNumber)
        guard draft.hasValidNumber else { return nil }
        return Release.catalogSample.first { $0.mgtNumber == normalized }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                numberField
                driveField
                editionField

                Button(action: bond) {
                    PrimaryCTALabel(title: "bond.cta", systemImage: "link")
                        .opacity(draft.isComplete ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!draft.isComplete)
                .accessibilityHint(Text("bond.cta.hint"))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Ink.paper)
        .navigationTitle(Text("bond.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Lightbar(label: "bond.eyebrow")
            Text("bond.heading")
                .font(Voice.serif(28))
                .foregroundStyle(Ink.primary)
            Text(scanResult != nil ? "bond.subhead.scan" : "bond.subhead.dev")
                .font(.footnote)
                .foregroundStyle(Ink.soft)
        }
    }

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("bond.field.number")
            HStack {
                TextField("MGT00802", text: $draft.mgtNumber)
                    .font(Voice.mono(15, weight: .medium))
                    .foregroundStyle(Ink.primary)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Spacer(minLength: 8)
                if let match {
                    Text("bond.matched \(match.name)")
                        .font(Voice.mono(10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Ink.ok, in: Capsule())
                        .lineLimit(1)
                }
            }
            .padding(14)
            .background(Ink.cellSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(match != nil ? Ink.ok : Ink.line, lineWidth: 1.5)
            )
        }
    }

    private var driveField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("bond.field.drive")
            DriveToggle(drives: Drive.allCases, selection: draft.drive) { draft.drive = $0 }
        }
    }

    private var editionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel("bond.field.edition")
            TextField("1510/2022", text: $draft.editionNo)
                .font(Voice.mono(15, weight: .medium))
                .foregroundStyle(Ink.primary)
                .autocorrectionDisabled()
                .padding(14)
                .background(Ink.cellSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.line, lineWidth: 1)
                )
            Text("bond.field.edition.note")
                .font(.caption2)
                .foregroundStyle(Ink.muted)
        }
    }

    // MARK: Save

    /// Persist the bonded copy to the local SwiftData store. `hasModel` is true
    /// whenever a viewable model is attached (a real/dev scan), which is what
    /// lights the niche in the cabinet. Upsert-safe against the unique key.
    private func bond() {
        // A model is attached for both the real scan and the dev path (bundled USDZ).
        let hasModel = scanResult != nil || SampleModel.url != nil
        guard let copy = draft.ownedCopy(hasModel: hasModel) else { return }

        let id = copy.key.stableID
        let existing = try? modelContext.fetch(
            FetchDescriptor<OwnedModel>(predicate: #Predicate { $0.stableID == id })
        )
        if let row = existing?.first {
            // Already on the shelf — light it (a model is now bonded) and keep the
            // newer edition serial if one was entered.
            row.hasModel = hasModel || row.hasModel
            if let edition = copy.editionNo { row.editionNo = edition }
        } else {
            modelContext.insert(OwnedModel(copy))
        }
        try? modelContext.save()
        // Only a bond that carries a REAL capture has a scan to offer the
        // community. An invite / gap-nudge bond (scanResult == nil — no camera
        // ever ran) saves quietly and finishes back to the cabinet: narrating
        // "you're the first to scan this" after a camera-free form would
        // fabricate a scan that never happened (App Review 2.1a).
        if scanResult != nil {
            router.go(.share(copy: copy, isFirstToScan: true))
        } else {
            router.finish()
        }
    }
}

/// A mono uppercase field label, matching the bond form's "uplabel" idiom.
private struct FieldLabel: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }
    var body: some View {
        Text(key)
            .textCase(.uppercase)
            .font(Voice.mono(10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Ink.muted)
    }
}

#Preview {
    NavigationStack { BondView(scanResult: nil) }
        .modelContainer(PersistenceController.inMemory())
        .environmentObject(ScanRouter())
        .tint(Ink.tungsten)
}
