// generate.swift — one-shot procedural low-poly car → USDZ exporter.
//
// Run on macOS with Xcode's toolchain (Model I/O ships in the SDK):
//   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//     swift tools/usdz-gen/generate.swift <output.usdc>
//   usdzip <output.usdz> <output.usdc>
//
// Model I/O on this toolchain exports .usdc (binary USD) but not .usdz directly,
// so we emit .usdc here and package it into .usdz with the SDK's `usdzip` (see
// tools/usdz-gen/build.sh). Both AR Quick Look and RealityView load the result.
//
// This is a BUILD-TIME asset generator, not app code. It composes a blocky
// "diecast" hatchback from MDLMesh primitives (body, cabin, four wheels) tinted
// in the Diecast Vault palette and writes a single binary .usdz the 3D viewer
// loads. Keeping the source here documents exactly how the bundled sample model
// was produced so it can be regenerated deterministically.

import Foundation
import ModelIO
import simd

// Diecast Vault palette (sRGB 0...1) — body in tungsten, glass in steel.
func color(_ r: Double, _ g: Double, _ b: Double) -> SIMD4<Float> {
    SIMD4(Float(r), Float(g), Float(b), 1)
}
let tungsten = color(0xF2 / 255.0, 0x6B / 255.0, 0x1F / 255.0)
let steelGlass = color(0x1B / 255.0, 0x20 / 255.0, 0x29 / 255.0)
let tyre = color(0x16 / 255.0, 0x18 / 255.0, 0x1D / 255.0)
let rim = color(0xEA / 255.0, 0xE4 / 255.0, 0xD6 / 255.0)

let allocator = MDLMeshBufferDataAllocator()

func scatterMaterial(name: String, base: SIMD4<Float>, roughness: Float, metallic: Float) -> MDLMaterial {
    let fn = MDLPhysicallyPlausibleScatteringFunction()
    fn.baseColor.float4Value = base
    fn.roughness.floatValue = roughness
    fn.metallic.floatValue = metallic
    return MDLMaterial(name: name, scatteringFunction: fn)
}

func box(_ dims: SIMD3<Float>, material: MDLMaterial) -> MDLMesh {
    let mesh = MDLMesh(
        boxWithExtent: dims,
        segments: SIMD3(1, 1, 1),
        inwardNormals: false,
        geometryType: .triangles,
        allocator: allocator
    )
    mesh.submeshes?.forEach { ($0 as? MDLSubmesh)?.material = material }
    return mesh
}

func cylinder(radius: Float, height: Float, material: MDLMaterial) -> MDLMesh {
    let mesh = MDLMesh(
        cylinderWithExtent: SIMD3(radius * 2, height, radius * 2),
        segments: SIMD2(16, 1),
        inwardNormals: false,
        topCap: true,
        bottomCap: true,
        geometryType: .triangles,
        allocator: allocator
    )
    mesh.submeshes?.forEach { ($0 as? MDLSubmesh)?.material = material }
    return mesh
}

let bodyMat = scatterMaterial(name: "Body", base: tungsten, roughness: 0.28, metallic: 0.45)
let glassMat = scatterMaterial(name: "Glass", base: steelGlass, roughness: 0.12, metallic: 0.2)
let tyreMat = scatterMaterial(name: "Tyre", base: tyre, roughness: 0.85, metallic: 0.0)
let rimMat = scatterMaterial(name: "Rim", base: rim, roughness: 0.4, metallic: 0.6)

let object = MDLObject()
object.name = "DiecastCar"

func add(_ mesh: MDLMesh, at p: SIMD3<Float>, rotate rot: SIMD3<Float> = .zero) {
    let t = MDLTransform()
    t.translation = p
    t.rotation = rot
    mesh.transform = t
    object.addChild(mesh)
}

// Dimensions in metres (1:64-ish display scale, ~0.16 m long hero car).
let L: Float = 0.16, W: Float = 0.072, H: Float = 0.042

// Lower body slab.
add(box(SIMD3(L, H, W), material: bodyMat), at: SIMD3(0, H / 2 + 0.018, 0))
// Cabin / glasshouse, shorter & set back a touch.
add(box(SIMD3(L * 0.5, H * 0.78, W * 0.82), material: glassMat),
    at: SIMD3(-0.006, H + 0.034, 0))

// Four wheels (cylinders laid on their sides), with a lighter rim disc inset.
let wheelR: Float = 0.018, wheelW: Float = 0.012
for sx: Float in [-1, 1] {
    for sz: Float in [-1, 1] {
        let x = sx * L * 0.34
        let z = sz * (W / 2 - wheelW / 2 + 0.002)
        add(cylinder(radius: wheelR, height: wheelW, material: tyreMat),
            at: SIMD3(x, 0.018, z), rotate: SIMD3(.pi / 2, 0, 0))
        add(cylinder(radius: wheelR * 0.55, height: wheelW * 1.05, material: rimMat),
            at: SIMD3(x, 0.018, z), rotate: SIMD3(.pi / 2, 0, 0))
    }
}

let asset = MDLAsset(bufferAllocator: allocator)
asset.add(object)

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/SampleCar.usdc"
let url = URL(fileURLWithPath: outPath)

guard MDLAsset.canExportFileExtension("usdc") else {
    FileHandle.standardError.write(Data("Model I/O cannot export usdc on this toolchain\n".utf8))
    exit(1)
}

do {
    try asset.export(to: url)
    print("Wrote \(url.path)")
} catch {
    FileHandle.standardError.write(Data("Export failed: \(error)\n".utf8))
    exit(1)
}
