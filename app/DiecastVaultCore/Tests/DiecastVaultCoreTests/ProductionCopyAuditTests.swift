import XCTest
@testable import DiecastVaultCore

/// Guards the App Review 2.1(a) fix: production-visible copy must never promise
/// scanning, camera capture, or any coming-soon feature. Both v1.0 rejections
/// were caused by scan-advertising surfaces (first a stalled capture simulation,
/// then a "guided scanning arrives in an upcoming update" placeholder), so this
/// audit walks the app's String Catalog and fails if scan/roadmap vocabulary
/// creeps back into any key that ships on a production screen.
///
/// Keys used only by DEBUG/dev-route views (the unshipped guided-capture flow
/// and its share prompt) are exempt — they are compiled out of or unreachable in
/// Release builds and may keep their vocabulary until the feature truly ships.
final class ProductionCopyAuditTests: XCTestCase {

    /// Key prefixes whose UI is dev-only (DV_ROUTE / DV_FORCE_SCAN_SUPPORT gated,
    /// unreachable on a store install).
    private static let devOnlyKeyPrefixes = [
        "scan.title",
        "scan.invite.",
        "scan.tip.",
        "scan.capture.",
        "scan.recon.",
        "scan.verdict.",
        "scan.step",
        "share.",
        "bond.subhead.scan",
    ]

    /// Vocabulary that must not appear in production-reachable copy.
    /// English terms are matched case-insensitively.
    private static let forbiddenEnglish = [
        "scan", "camera", "lidar", "photogrammetry",
        "coming soon", "upcoming update", "lands later", "comes later",
        "v1.1",
    ]
    private static let forbiddenChinese = [
        "扫描", "相机", "摄像头", "稍后推出", "后续更新", "即将推出",
    ]

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct Unit: Decodable { let value: String }
                let stringUnit: Unit
            }
            let localizations: [String: Localization]?
        }
        let strings: [String: Entry]
    }

    private func loadCatalog() throws -> Catalog {
        // Tests/DiecastVaultCoreTests/ -> DiecastVaultCore/ -> app/
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let appDir = testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = appDir
            .appendingPathComponent("Sources/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    func testProductionCopyCarriesNoScanOrRoadmapPromises() throws {
        let catalog = try loadCatalog()
        var violations: [String] = []

        for (key, entry) in catalog.strings {
            if Self.devOnlyKeyPrefixes.contains(where: { key.hasPrefix($0) }) { continue }
            guard let localizations = entry.localizations else { continue }

            for (locale, localization) in localizations {
                let value = localization.stringUnit.value
                let lowered = value.lowercased()
                for term in Self.forbiddenEnglish where lowered.contains(term) {
                    violations.append("\(key) [\(locale)] contains \"\(term)\": \(value)")
                }
                for term in Self.forbiddenChinese where value.contains(term) {
                    violations.append("\(key) [\(locale)] contains \"\(term)\": \(value)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Production copy must not promise scanning/camera/roadmap features "
                + "(App Review 2.1a). Violations:\n" + violations.joined(separator: "\n")
        )
    }

    /// The Real-Car face renders `RealCarProfile.sample(for:)` — embedded Core
    /// copy the String Catalog audit cannot see. Codex review of the 2.1(a) fix
    /// caught roadmap promises hiding here ("When the enrichment backend
    /// lands…", "Wikimedia Commons later"), so audit the generated profiles in
    /// both locales too.
    func testBundledRealCarProfilesCarryNoRoadmapPromises() {
        let forbiddenEnglish = Self.forbiddenEnglish + ["later", "backend", "lands"]
        let forbiddenChinese = Self.forbiddenChinese + ["稍后", "后续", "上线", "即将"]
        var violations: [String] = []

        for release in Release.catalogSample {
            for locale in [SampleLocale.english, .simplifiedChinese] {
                let profile = RealCarProfile.sample(for: release, locale: locale)
                var texts = profile.history + [profile.historySource]
                texts += profile.specs.flatMap { [$0.key, $0.value] }
                for image in [profile.hero] + profile.gallery {
                    texts += [image.caption, image.attribution, image.license]
                }
                for text in texts {
                    let lowered = text.lowercased()
                    for term in forbiddenEnglish where lowered.contains(term) {
                        violations.append("\(release.mgtNumber) [\(locale)] contains \"\(term)\": \(text)")
                    }
                    for term in forbiddenChinese where text.contains(term) {
                        violations.append("\(release.mgtNumber) [\(locale)] contains \"\(term)\": \(text)")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Bundled Real-Car copy must not promise future features (App Review 2.1a). "
                + "Violations:\n" + violations.joined(separator: "\n")
        )
    }

    func testDeletedPlaceholderKeysStayDeleted() throws {
        let catalog = try loadCatalog()
        // Each of these carried a coming-soon promise or a dead control; they were
        // removed for v1.0 and must not silently return.
        let bannedKeys = [
            "detail.invite.notify",
            "detail.invite.notified",
            "detail.invite.proCta",
            "detail.invite.proTitle",
            "detail.invite.proNote",
            "realcar.sampleBanner",
            "me.row.icloudSync",
            "me.row.icloudSync.note",
            "cabinet.empty.scan",
        ]
        for key in bannedKeys {
            XCTAssertNil(
                catalog.strings[key],
                "\(key) was removed with its placeholder UI; re-adding it needs the real feature."
            )
        }
    }
}
