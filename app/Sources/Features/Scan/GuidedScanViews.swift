import SwiftUI
import DiecastVaultCore

// MARK: - Step 1 · Before you scan (diffuse-light tip)

/// Remove-from-case + diffuse-light guidance (mockup #s-scan-tip). Clear acrylic
/// and glossy diecast both fight photogrammetry; this screen sets the user up to
/// succeed before `ObjectCaptureSession` starts.
struct ScanTipView: View {
    var onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StepChip(step: .tip)

                Text("scan.tip.title")
                    .font(Voice.serif(28))
                    .foregroundStyle(Ink.primary)

                tipCard
                lightingWell

                Button(action: onStart) {
                    PrimaryCTALabel(title: "scan.tip.cta", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Ink.paper)
        .navigationTitle(Text("scan.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tipCard: some View {
        VStack(spacing: 12) {
            DiecastGlyph()
                .frame(width: 150, height: 96)
            Text("scan.tip.removeTitle")
                .font(Voice.serif(18))
                .foregroundStyle(Ink.primary)
            Text("scan.tip.removeBody")
                .font(.footnote)
                .foregroundStyle(Ink.soft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1)
        )
    }

    private var lightingWell: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.max")
                .foregroundStyle(Ink.warn)
            VStack(alignment: .leading, spacing: 3) {
                Text("scan.tip.lightingTitle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                Text("scan.tip.lightingBody")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(Palette.warn).opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 2 · Capture orbit (coverage gauge)

/// The guided-capture orbit (mockup #s-scan-capture) — the one moment that lives
/// on the dark stage during capture. A radial coverage gauge + mono telemetry
/// echoes the `ObjectCaptureSession` feedback loop; "Finish & reconstruct" hands
/// off to `PhotogrammetrySession`.
struct ScanCaptureView: View {
    let coverage: Double
    let shotCount: Int
    var onFinish: () -> Void

    private var percent: Int { Int((coverage * 100).rounded()) }

    var body: some View {
        ZStack {
            Color(Palette.stage0).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    StepChip(step: .capture, onStage: true)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                gauge
                telemetry

                Spacer()

                Button(action: onFinish) {
                    HStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                        Text("scan.capture.finish").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color(Palette.stage0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var gauge: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle()
                .trim(from: 0, to: coverage)
                .stroke(
                    AngularGradient(
                        colors: [Color(Palette.tungstenGlow), Color(Palette.tungsten)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.18), value: coverage)
            VStack(spacing: 2) {
                Text("\(percent)%")
                    .font(Voice.serif(34))
                    .foregroundStyle(.white)
                Text("scan.capture.coverageLabel")
                    .font(Voice.mono(9, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 170, height: 170)
    }

    private var telemetry: some View {
        VStack(spacing: 6) {
            Text("scan.capture.telemetry \(percent) \(shotCount)")
                .font(Voice.mono(11, weight: .semibold))
                .foregroundStyle(.white)
            Text("scan.capture.hint")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
        }
        .multilineTextAlignment(.center)
        .padding(.top, 18)
    }
}

// MARK: - Step 3 · Reconstructing (determinate)

/// On-device reconstruction (mockup #s-scan-recon) — a determinate progress bar
/// over a lit niche, with the honest "nothing leaves the device" note. This is
/// the `PhotogrammetrySession` meshing stage.
struct ScanReconView: View {
    let progress: Double
    let shotCount: Int

    private var percent: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                StepChip(step: .reconstruct)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer()

            litNiche

            VStack(spacing: 12) {
                HStack {
                    Text("scan.recon.label")
                        .font(Voice.mono(10, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.muted)
                    Spacer()
                    Text("\(percent)%")
                        .font(Voice.mono(11, weight: .medium))
                        .foregroundStyle(Ink.soft)
                }
                ProgressView(value: progress)
                    .tint(Ink.tungsten)
                Text("scan.recon.body \(max(shotCount, 41))")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.paper)
        .navigationTitle(Text("scan.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var litNiche: some View {
        ZStack {
            RadialGradient(colors: [Ink.tungstenGlow, .clear], center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 150)
                .background(Ink.cellSurface)
            DiecastGlyph().frame(width: 110, height: 70)
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1))
        .shadow(color: Color(Palette.ink).opacity(0.08), radius: 14, y: 10)
    }
}

// MARK: - Step 4 · Verdict (keep / re-scan, Spike-0 honesty)

/// The "good enough to show a friend?" verdict (mockup #s-scan-verdict). Carries
/// the Spike-0 honesty: a reduced-detail caveat, the real size/coverage specs,
/// and an equal-weight KEEP → Bond / Re-scan choice.
struct ScanVerdictView: View {
    let result: ScanResult
    var onKeep: () -> Void
    var onRescan: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                StepChip(step: .verdict)

                Text("scan.verdict.title")
                    .font(Voice.serif(28))
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                previewCard
                if result.showsReducedCaveat { caveat }

                Button(action: onKeep) {
                    PrimaryCTALabel(title: "scan.verdict.keep", systemImage: "checkmark")
                }
                .buttonStyle(.plain)

                Button(action: onRescan) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("scan.verdict.rescan").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Ink.tungstenDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Ink.tungsten, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Ink.paper)
        .navigationTitle(Text("scan.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var previewCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RadialGradient(colors: [Ink.tungstenGlow, .clear], center: .init(x: 0.5, y: 1.1), startRadius: 0, endRadius: 90)
                        .background(Color(Palette.stage1))
                    DiecastGlyph().frame(width: 88, height: 56)
                }
                .frame(width: 110, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("scan.verdict.complete")
                        .textCase(.uppercase)
                        .font(Voice.mono(9, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Ink.ok, in: Capsule())
                    Text("scan.verdict.captured")
                        .font(.footnote)
                        .foregroundStyle(Ink.soft)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                specRow("scan.verdict.spec.detail", value: result.detail.monoLabel)
                Divider()
                specRow("scan.verdict.spec.size", value: result.sizeLabel)
                Divider()
                specRow("scan.verdict.spec.coverage", value: "\(result.coveragePercent)%")
            }
        }
        .padding(14)
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1))
    }

    private func specRow(_ key: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(key)
                .font(Voice.mono(10, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(Ink.muted)
            Spacer()
            Text(value)
                .font(Voice.mono(11, weight: .medium))
                .foregroundStyle(Ink.soft)
        }
        .padding(.vertical, 8)
    }

    private var caveat: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                Text("scan.verdict.caveat.title").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color(red: 0.48, green: 0.35, blue: 0))
            Text("scan.verdict.caveat.body")
                .font(.footnote)
                .foregroundStyle(Color(red: 0.48, green: 0.35, blue: 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(Palette.warn).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(Palette.warn).opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Shared bits

/// The "Step N / 4" chip used across the guided flow.
struct StepChip: View {
    let step: ScanStep
    var onStage: Bool = false

    var body: some View {
        Text("scan.step \(step.ordinal) \(ScanStep.total)")
            .font(Voice.mono(10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(onStage ? Color.white.opacity(0.8) : Ink.steel)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(onStage ? Color.white.opacity(0.12) : Ink.steelSoft)
            )
    }
}

/// The shared primary CTA label (full-width, filled). Tungsten by default; a
/// `fill` override lets a secondary action (e.g. "offer as alternate") wear steel
/// while keeping the same shape and metrics.
struct PrimaryCTALabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var fill: Color = Ink.tungsten

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// A small SVG-echo of the mockup's diecast car glyph (red body, dark glass,
/// gold stripe), drawn in SwiftUI so the capture flow has a believable subject
/// without bundling raster art.
struct DiecastGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color(Palette.ink).opacity(0.14))
                    .frame(width: w * 0.78, height: h * 0.14)
                    .offset(y: h * 0.36)
                CarBody()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.78, green: 0.21, blue: 0.17), Color(red: 0.56, green: 0.13, blue: 0.09)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .frame(width: w, height: h)
        }
    }
}

/// A simple, recognizable side-profile car silhouette path.
private struct CarBody: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }
        var path = Path()
        path.move(to: p(0.08, 0.66))
        path.addCurve(to: p(0.30, 0.50), control1: p(0.12, 0.55), control2: p(0.22, 0.50))
        path.addCurve(to: p(0.55, 0.36), control1: p(0.36, 0.40), control2: p(0.46, 0.34))
        path.addCurve(to: p(0.86, 0.52), control1: p(0.70, 0.38), control2: p(0.80, 0.44))
        path.addCurve(to: p(0.95, 0.68), control1: p(0.92, 0.54), control2: p(0.95, 0.60))
        path.addLine(to: p(0.95, 0.74))
        path.addLine(to: p(0.08, 0.74))
        path.closeSubpath()
        // Wheels punched as circles for a touch of realism.
        path.addEllipse(in: CGRect(x: 0.20 * w, y: 0.62 * h, width: 0.16 * w, height: 0.16 * w))
        path.addEllipse(in: CGRect(x: 0.66 * w, y: 0.62 * h, width: 0.16 * w, height: 0.16 * w))
        return path
    }
}
