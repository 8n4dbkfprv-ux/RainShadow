import CryptoKit
import Foundation

enum IEIndexedSpriteError: Error, Equatable, CustomStringConvertible {
    case resourceNotFound(character: String)
    case unreadableResource(name: String, reason: String)
    case malformedManifest(reason: String)
    case unsupportedSchema(String)
    case unsupportedVersion(Int)
    case invalidBlobName(String)
    case blobHashMismatch(expected: String, got: String)
    case truncatedHeader(got: Int)
    case invalidBlobMagic
    case invalidBlobVersion(Int)
    case inventoryCountMismatch(manifest: Int, blob: Int)
    case duplicateFrame(atlas: String, name: String)
    case invalidFrame(atlas: String, name: String, reason: String)
    case frameHashMismatch(atlas: String, name: String, expected: String, got: String)
    case invalidPaletteIndex(atlas: String, name: String, index: UInt8)
    case unclaimedBlobBytes(claimed: Int, actual: Int)

    var description: String {
        switch self {
        case let .resourceNotFound(character):
            return "IE indexed-avatar bundle not found for \(character)"
        case let .unreadableResource(name, reason):
            return "IE indexed-avatar resource \(name) could not be read: \(reason)"
        case let .malformedManifest(reason):
            return "IE indexed-avatar manifest is malformed: \(reason)"
        case let .unsupportedSchema(schema):
            return "unsupported IE indexed-avatar schema \(schema)"
        case let .unsupportedVersion(version):
            return "unsupported IE indexed-avatar manifest version \(version)"
        case let .invalidBlobName(name):
            return "IE indexed-avatar manifest names invalid blob \(name)"
        case let .blobHashMismatch(expected, got):
            return "IE indexed-avatar blob SHA-256 is \(got), expected \(expected)"
        case let .truncatedHeader(got):
            return "IE indexed-avatar blob is \(got) bytes, shorter than its 16-byte header"
        case .invalidBlobMagic:
            return "IE indexed-avatar blob has invalid magic"
        case let .invalidBlobVersion(version):
            return "unsupported IE indexed-avatar blob version \(version)"
        case let .inventoryCountMismatch(manifest, blob):
            return "IE indexed-avatar inventory has \(manifest) frames, blob header names \(blob)"
        case let .duplicateFrame(atlas, name):
            return "duplicate IE indexed-avatar frame \(atlas)/\(name)"
        case let .invalidFrame(atlas, name, reason):
            return "invalid IE indexed-avatar frame \(atlas)/\(name): \(reason)"
        case let .frameHashMismatch(atlas, name, expected, got):
            return "IE indexed-avatar frame \(atlas)/\(name) SHA-256 is \(got), expected \(expected)"
        case let .invalidPaletteIndex(atlas, name, index):
            return "IE indexed-avatar frame \(atlas)/\(name) contains invalid palette index \(index)"
        case let .unclaimedBlobBytes(claimed, actual):
            return "IE indexed-avatar inventory claims \(claimed) bytes from a \(actual)-byte blob"
        }
    }
}

/// A character sprite kept as byte-exact palette indices until draw time.
///
/// `ArtSource/Processing/ie_avatar_bundle.py` writes the v1 pair this reads: a
/// JSON inventory plus one packed index plane. This is the same division GemRB
/// uses for BAM avatars — the frame owns indexed pixels and a pivot, while
/// `SetupPaperdollColours` supplies the character's palette. The index payload
/// remains top-down row-major here; no image decoder is allowed to expand,
/// colour-manage, or flip it before the palette lookup.
struct IEIndexedSprite: Sendable {
    static let schema = "rainshadow.ie-indexed-avatar"
    static let version = 2
    static let manifestFileName = "avatar-v02.json"
    static let blobFileName = "avatar-v02.indices"
    static let blobMagic = Array("RSIEAV2\0".utf8)
    static let blobHeaderSize = 16

    struct PixelSize: Equatable, Sendable {
        let width: Int
        let height: Int
    }

    struct PixelVector: Equatable, Sendable {
        let x: Double
        let y: Double
    }

    /// How the native indexed BAM-style plane reaches its registered display
    /// footprint in the legacy SpriteKit presentation path. The native world
    /// renderer reads the indices directly and enlarges only its completed
    /// framebuffer; `super-xbr` remains readable for older fallback bundles.
    enum TextureFilter: String, Equatable, Sendable {
        case linear
        case superXBR = "super-xbr"
    }

    struct FrameID: Equatable, Hashable, Sendable {
        let atlas: String
        let name: String
    }

    struct Frame: Equatable, Sendable {
        let id: FrameID
        /// The registered footprint on the source canvas. Geometry — pivot,
        /// trim and node sizing — is all in this space, unchanged since v01.
        /// A direct-linear bundle may supply a native-size texture into it.
        let size: PixelSize
        /// The size of the stored index plane, which since v02 is the **native**
        /// craft raster.
        let nativeSize: PixelSize
        /// Location of this crop's top-left pixel edge on the source canvas.
        let trimOriginTopLeft: PixelSize
        /// BAM-style pivot measured from the crop's bottom-left pixel edge.
        let pivotFromCropBottomLeft: PixelVector
        /// Top-down, left-to-right `UInt8` palette indices.
        let indices: [UInt8]
        let isEmpty: Bool

        /// Indexes the stored plane, which is native resolution — not `size`.
        func index(x: Int, yFromTop: Int) -> UInt8 {
            precondition(x >= 0 && x < nativeSize.width, "x outside indexed-avatar frame")
            precondition(
                yFromTop >= 0 && yFromTop < nativeSize.height,
                "y outside indexed-avatar frame"
            )
            return indices[yFromTop * nativeSize.width + x]
        }

        /// The pivot in the unit square SpriteKit uses for `anchorPoint`.
        var normalizedPivot: PixelVector? {
            guard size.width > 0, size.height > 0 else { return nil }
            return PixelVector(
                x: pivotFromCropBottomLeft.x / Double(size.width),
                y: pivotFromCropBottomLeft.y / Double(size.height)
            )
        }
    }

    let character: String
    let colors: [UInt32]
    let sourceCanvasSize: PixelSize
    let sourcePivotFromCanvasBottomLeft: PixelVector
    let compatibilityDisplaySize: PixelVector
    let displayUnitsPerSourcePixel: PixelVector
    let hasEmbeddedShadow: Bool
    let shadowOwner: String
    let fallback: String
    let textureFilter: TextureFilter
    /// The bundle's shared registration scale, not a per-frame size ratio.
    /// Retained for explicit native-grid adapters; shipping geometry is unchanged.
    let registeredPixelsPerNativePixel: Double
    let frames: [Frame]
    let palette: IEPalette

    private let frameIndex: [FrameID: Int]
    private let tables: IEGradientTables

    init(manifestData: Data, indicesData: Data, tables: IEGradientTables) throws {
        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        } catch {
            throw IEIndexedSpriteError.malformedManifest(reason: String(describing: error))
        }

        guard manifest.schema == Self.schema else {
            throw IEIndexedSpriteError.unsupportedSchema(manifest.schema)
        }
        guard manifest.version == Self.version else {
            throw IEIndexedSpriteError.unsupportedVersion(manifest.version)
        }
        guard manifest.blob == Self.blobFileName else {
            throw IEIndexedSpriteError.invalidBlobName(manifest.blob)
        }
        try Self.validateLeaf(manifest.character, field: "character")
        guard manifest.byteOrder == "little" else {
            throw IEIndexedSpriteError.malformedManifest(reason: "byte_order must be little")
        }
        guard manifest.storage == "top-down-row-major-u8" else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "storage must be top-down-row-major-u8"
            )
        }

        let sourceCanvasSize = try Self.positiveSize(
            manifest.sourceCanvasPixels,
            field: "source_canvas_px"
        )
        let sourcePivotFromCanvasBottomLeft = try Self.finiteManifestVector(
            manifest.sourcePivotFromCanvasBottomLeftPixels,
            field: "source_pivot_from_canvas_bottom_left_px"
        )
        let compatibilityDisplaySize = try Self.positiveVector(
            manifest.compatibilityDisplaySize,
            field: "compatibility_display_size"
        )
        let displayUnitsPerSourcePixel = try Self.positiveVector(
            manifest.displayUnitsPerSourcePixel,
            field: "display_units_per_source_pixel"
        )
        let expectedScale = PixelVector(
            x: compatibilityDisplaySize.x / Double(sourceCanvasSize.width),
            y: compatibilityDisplaySize.y / Double(sourceCanvasSize.height)
        )
        guard abs(displayUnitsPerSourcePixel.x - expectedScale.x) <= 1e-12,
              abs(displayUnitsPerSourcePixel.y - expectedScale.y) <= 1e-12 else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "display_units_per_source_pixel disagrees with display size and source canvas"
            )
        }

        guard manifest.colors.count == IEMaterialSlot.allCases.count else {
            throw IEIndexedSpriteError.malformedManifest(reason: "colors must contain seven entries")
        }
        let colors: [UInt32] = try manifest.colors.map { value in
            guard (0...255).contains(value) else {
                throw IEIndexedSpriteError.malformedManifest(
                    reason: "colors entries must fit one gradient-index byte"
                )
            }
            return UInt32(value)
        }
        try Self.validatePaletteMetadata(manifest.palette)
        guard !manifest.shadow.owner.isEmpty else {
            throw IEIndexedSpriteError.malformedManifest(reason: "shadow owner is empty")
        }
        guard !manifest.fallback.isEmpty else {
            throw IEIndexedSpriteError.malformedManifest(reason: "fallback is empty")
        }
        guard manifest.textureScale.isFinite, manifest.textureScale > 0 else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "texture_scale must be positive and finite"
            )
        }
        guard let textureFilter = TextureFilter(rawValue: manifest.textureFilter) else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "texture_filter must be linear or super-xbr"
            )
        }

        let actualBlobHash = Self.sha256(indicesData)
        guard actualBlobHash == manifest.blobSHA256 else {
            throw IEIndexedSpriteError.blobHashMismatch(
                expected: manifest.blobSHA256,
                got: actualBlobHash
            )
        }
        guard indicesData.count >= Self.blobHeaderSize else {
            throw IEIndexedSpriteError.truncatedHeader(got: indicesData.count)
        }
        let blob = [UInt8](indicesData)
        guard Array(blob[0..<Self.blobMagic.count]) == Self.blobMagic else {
            throw IEIndexedSpriteError.invalidBlobMagic
        }
        let blobVersion = Int(Self.littleEndianUInt32(blob, at: 8))
        guard blobVersion == Self.version else {
            throw IEIndexedSpriteError.invalidBlobVersion(blobVersion)
        }
        let blobFrameCount = Int(Self.littleEndianUInt32(blob, at: 12))
        guard blobFrameCount == manifest.frames.count else {
            throw IEIndexedSpriteError.inventoryCountMismatch(
                manifest: manifest.frames.count,
                blob: blobFrameCount
            )
        }

        var expectedOffset = Self.blobHeaderSize
        var seen: Set<FrameID> = []
        var frameIndex: [FrameID: Int] = [:]
        var frames: [Frame] = []
        frames.reserveCapacity(manifest.frames.count)
        var containsShadowIndex = false

        for record in manifest.frames {
            let id = FrameID(atlas: record.atlas, name: record.name)
            try Self.validateFrameLeaf(id.atlas, suffix: ".atlas", id: id, field: "atlas")
            try Self.validateFrameLeaf(id.name, suffix: ".png", id: id, field: "name")
            guard seen.insert(id).inserted else {
                throw IEIndexedSpriteError.duplicateFrame(atlas: id.atlas, name: id.name)
            }
            guard record.offset == expectedOffset else {
                throw Self.invalid(id, "offset \(record.offset) is not contiguous offset \(expectedOffset)")
            }
            guard record.width >= 0, record.height >= 0, record.length >= 0 else {
                throw Self.invalid(id, "width, height and length must be non-negative")
            }
            let (area, areaOverflow) = record.width.multipliedReportingOverflow(by: record.height)
            guard !areaOverflow, record.length == area else {
                throw Self.invalid(id, "length \(record.length) differs from width × height")
            }
            let (end, endOverflow) = record.offset.addingReportingOverflow(record.length)
            guard !endOverflow, end <= blob.count else {
                throw Self.invalid(id, "payload extends beyond the index blob")
            }

            let trimOrigin = try Self.nonnegativeSize(
                record.trimOriginTopLeftPixels,
                id: id,
                field: "trim_origin_top_left_px"
            )
            let pivot = try Self.finiteVector(
                record.pivotFromCropBottomLeftPixels,
                id: id,
                field: "pivot_from_crop_bottom_left_px"
            )
            let textureSize = try Self.nonnegativeSize(
                record.texturePixels,
                id: id,
                field: "texture_px"
            )
            if record.empty {
                guard record.width == 0, record.height == 0, record.length == 0,
                      textureSize.width == 0, textureSize.height == 0 else {
                    throw Self.invalid(id, "an empty frame must have zero dimensions and length")
                }
            } else {
                guard record.width > 0, record.height > 0 else {
                    throw Self.invalid(id, "a non-empty frame must have positive dimensions")
                }
                guard textureSize.width > 0, textureSize.height > 0 else {
                    throw Self.invalid(id, "a non-empty frame must have a positive rendered size")
                }
                // Trim and pivot are texture space; the stored plane is native.
                let (trimRight, rightOverflow) =
                    trimOrigin.width.addingReportingOverflow(textureSize.width)
                let (trimBottom, bottomOverflow) =
                    trimOrigin.height.addingReportingOverflow(textureSize.height)
                guard !rightOverflow, !bottomOverflow,
                      trimRight <= sourceCanvasSize.width,
                      trimBottom <= sourceCanvasSize.height else {
                    throw Self.invalid(id, "trim rectangle extends beyond the source canvas")
                }
                let expectedPivot = PixelVector(
                    x: sourcePivotFromCanvasBottomLeft.x - Double(trimOrigin.width),
                    y: sourcePivotFromCanvasBottomLeft.y
                        - Double(sourceCanvasSize.height - trimBottom)
                )
                guard abs(pivot.x - expectedPivot.x) <= 1e-9,
                      abs(pivot.y - expectedPivot.y) <= 1e-9 else {
                    throw Self.invalid(id, "pivot disagrees with the source-canvas trim")
                }
            }

            let payload = Array(blob[record.offset..<end])
            let payloadHash = Self.sha256(Data(payload))
            guard payloadHash == record.sha256 else {
                throw IEIndexedSpriteError.frameHashMismatch(
                    atlas: id.atlas,
                    name: id.name,
                    expected: record.sha256,
                    got: payloadHash
                )
            }
            for index in payload {
                guard index <= 1 || (0x04..<0x58).contains(index) else {
                    throw IEIndexedSpriteError.invalidPaletteIndex(
                        atlas: id.atlas,
                        name: id.name,
                        index: index
                    )
                }
                containsShadowIndex = containsShadowIndex || index == IEPalette.shadowIndex
            }

            frameIndex[id] = frames.count
            frames.append(
                Frame(
                    id: id,
                    size: textureSize,
                    nativeSize: PixelSize(width: record.width, height: record.height),
                    trimOriginTopLeft: trimOrigin,
                    pivotFromCropBottomLeft: pivot,
                    indices: payload,
                    isEmpty: record.empty
                )
            )
            expectedOffset = end
        }

        guard expectedOffset == blob.count else {
            throw IEIndexedSpriteError.unclaimedBlobBytes(
                claimed: expectedOffset,
                actual: blob.count
            )
        }
        guard manifest.shadow.embedded == containsShadowIndex else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "shadow.embedded disagrees with the index inventory"
            )
        }

        character = manifest.character
        self.colors = colors
        self.sourceCanvasSize = sourceCanvasSize
        self.sourcePivotFromCanvasBottomLeft = sourcePivotFromCanvasBottomLeft
        self.compatibilityDisplaySize = compatibilityDisplaySize
        self.displayUnitsPerSourcePixel = displayUnitsPerSourcePixel
        hasEmbeddedShadow = manifest.shadow.embedded
        shadowOwner = manifest.shadow.owner
        fallback = manifest.fallback
        self.textureFilter = textureFilter
        registeredPixelsPerNativePixel = manifest.textureScale
        self.frames = frames
        palette = IEPaperdollColours.setup(colors: colors, tables: tables)
        self.frameIndex = frameIndex
        self.tables = tables
    }

    init(contentsOf manifestURL: URL, tables: IEGradientTables) throws {
        let manifestData: Data
        let indicesData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw IEIndexedSpriteError.unreadableResource(
                name: manifestURL.path,
                reason: error.localizedDescription
            )
        }
        let indicesURL = manifestURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.blobFileName, isDirectory: false)
        do {
            indicesData = try Data(contentsOf: indicesURL)
        } catch {
            throw IEIndexedSpriteError.unreadableResource(
                name: indicesURL.path,
                reason: error.localizedDescription
            )
        }
        try self.init(manifestData: manifestData, indicesData: indicesData, tables: tables)
    }

    /// Loads the current versioned avatar bundle from the app or
    /// SwiftPM bundle, with the checkout copy as the same development fallback
    /// used by ``IEGradientTables``.
    static func load(
        character: String,
        bundle: Bundle? = nil,
        tables suppliedTables: IEGradientTables? = nil
    ) throws -> IEIndexedSprite {
        let searchBundles: [Bundle] = {
            if let bundle { return [bundle] }
            #if SWIFT_PACKAGE
            return [.module, .main]
            #else
            return [.main]
            #endif
        }()
        // SwiftPM preserves the copied IE directory. Xcode's synchronized-group
        // resource phase flattens ordinary files, so the app target explicitly
        // copies each character directory as a folder reference (`Lila/`,
        // `Voss/`). Search both deterministic bundle layouts.
        let subdirectories = [
            "\(IEGradientTables.resourceSubdirectory)/Avatars/\(character)",
            character
        ]
        var manifestURL: URL?
        for candidate in searchBundles {
            for subdirectory in subdirectories {
                if let url = candidate.url(
                    forResource: (Self.manifestFileName as NSString).deletingPathExtension,
                    withExtension: "json",
                    subdirectory: subdirectory
                ) {
                    manifestURL = url
                    break
                }
            }
            if manifestURL != nil { break }
        }
        if manifestURL == nil {
            let developmentURL = IEGradientTables.developmentDirectory
                .appendingPathComponent("Avatars/\(character)", isDirectory: true)
                .appendingPathComponent(Self.manifestFileName, isDirectory: false)
            if FileManager.default.fileExists(atPath: developmentURL.path) {
                manifestURL = developmentURL
            }
        }
        guard let manifestURL else {
            throw IEIndexedSpriteError.resourceNotFound(character: character)
        }
        let tables = try suppliedTables ?? IEGradientTables.load(bundle: bundle)
        return try IEIndexedSprite(contentsOf: manifestURL, tables: tables)
    }

    func frame(atlas: String, name: String) -> Frame? {
        let id = FrameID(atlas: atlas, name: name)
        guard let index = frameIndex[id] else { return nil }
        return frames[index]
    }

    /// Resolves one top-down index plane through this character's seven material
    /// rows. Index 0 remains transparent and index 1 retains the palette's
    /// shadow entry; shadow-node policy stays outside this pure sprite model.
    func resolvedColors(for frame: Frame) -> [IEColor] {
        frame.indices.map { palette[Int($0)] }
    }

    func rgba(for frame: Frame) -> [UInt8] {
        rgba(for: frame, colors: colors)
    }

    /// Resolves the same authoritative index plane with another creature
    /// `colors[]` array. Geometry, transparency and pivot do not participate in
    /// recolouring; this is the runtime contract that replacing baked RGBA buys.
    func rgba(for frame: Frame, colors alternateColors: [UInt32]) -> [UInt8] {
        precondition(
            alternateColors.count == IEMaterialSlot.allCases.count,
            "an indexed avatar needs seven gradient indices"
        )
        let resolvedPalette = alternateColors == colors
            ? palette
            : IEPaperdollColours.setup(colors: alternateColors, tables: tables)
        // Always the native index plane. See `texturePixelSize(for:)`.
        return Self.resolve(indices: frame.indices, palette: resolvedPalette)
    }

    /// Actual pixel dimensions supplied to SpriteKit: always the native plane.
    ///
    /// Native presentation keeps the categorical craft at its authored
    /// resolution and lets SpriteKit perform the one display-scale
    /// interpolation, like BG:EE. Registered geometry stays in `frame.size`, and
    /// `IEAvatarFrameLibrary` derives display size from that, so actor scale and
    /// pivots do not move when a bundle changes filter.
    ///
    /// A bundle declaring `super-xbr` used to be prefiltered here instead, and
    /// that is gone. It was measured at 21.7 s of main-thread work inside
    /// `ClientActorNode.init` — two Super xBR passes per frame, colour and
    /// silhouette, for Lila's 25 frames — landing squarely on the area
    /// transition. Voss's V23 bundle had already moved to native presentation
    /// for the parity reasons above; Lila now matches, and no bundle can put
    /// the scaler back on the load path.
    ///
    /// `IEResample` and `IEIndexedSprite.render` remain as the offline bake
    /// reference that `IEResampleTests` and the compatibility-atlas round trip
    /// pin. They are no longer reachable from play.
    func texturePixelSize(for frame: Frame) -> PixelSize {
        frame.nativeSize
    }

    private static func resolve(indices: [UInt8], palette: IEPalette) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: indices.count * 4)
        for (pixel, index) in indices.enumerated() {
            let color = palette[Int(index)]
            let offset = pixel * 4
            bytes[offset] = color.r
            bytes[offset + 1] = color.g
            bytes[offset + 2] = color.b
            bytes[offset + 3] = color.a
        }
        return bytes
    }

    /// Resolve a native index plane and enlarge it to the rendered size.
    ///
    /// **Not a runtime path.** Presentation is native everywhere now — see
    /// `texturePixelSize(for:)`. This stays because it is the reference the
    /// offline bake is verified against, byte for byte, by
    /// `IEResampleTests.theWholeRenderPathMatchesThePythonBake` and by the
    /// compatibility-atlas round trip in `VossWardrobeColorTests`.
    ///
    /// Legacy Super-xBR bundles must reproduce
    /// `ie_avatar.AvatarFrame.render_texture` byte for byte. The bake writes the
    /// compatibility atlas with that and the Lila round-trip test compares this
    /// against it. `IEResampleTests` pins the resampler itself.
    ///
    /// Three steps, and the order matters: resolve, enlarge, then re-impose the
    /// 1-bit BAM silhouette. Every native pixel is alpha 0 or 255 with black
    /// under the transparent ones, so the premultiply inside the scaler is the
    /// identity going in and only the unpremultiply rounds.
    static func render(
        indices: [UInt8],
        nativeSize: PixelSize,
        textureSize: PixelSize,
        palette: IEPalette
    ) -> [UInt8] {
        guard nativeSize.width > 0, nativeSize.height > 0,
              textureSize.width > 0, textureSize.height > 0 else { return [] }

        var packed = [UInt32](repeating: 0, count: indices.count)
        for (offset, index) in indices.enumerated() {
            let color = palette[Int(index)]
            packed[offset] = UInt32(color.a) << 24 | UInt32(color.r) << 16
                | UInt32(color.g) << 8 | UInt32(color.b)
        }

        let factorX = Double(textureSize.width) / Double(nativeSize.width)
        let factorY = Double(textureSize.height) / Double(nativeSize.height)

        func filter(_ source: [UInt32]) -> [UInt32] {
            let scaled = IEResample.scaleSuperXBR(
                source, nativeSize.width, nativeSize.height, factorX, factorY
            )
            return IEResample.settle(
                scaled.pixels, scaled.width, scaled.height,
                textureSize.width, textureSize.height
            )
        }

        let settled = filter(packed)

        // The silhouette comes from a *separate* pass over a colourless stencil.
        // Super xBR decides each blend from the luma of what it samples, so an
        // alpha taken from the colour pass would depend on the palette and
        // recolouring the coat would move the edge. The silhouette belongs to the
        // index plane, so it is filtered from the index plane alone.
        var stencil = [UInt32](repeating: 0, count: indices.count)
        for (offset, index) in indices.enumerated() where index != 0 {
            stencil[offset] = 0xFFFF_FFFF
        }
        let edge = filter(stencil)

        var bytes = [UInt8](repeating: 0, count: textureSize.width * textureSize.height * 4)
        for offset in 0..<(textureSize.width * textureSize.height) {
            let value = settled[offset]
            guard (edge[offset] >> 24) & 0xFF >= 128 else { continue }  // 1-bit silhouette
            // The stencil decides the silhouette, so a pixel it keeps is opaque
            // even where the colour pass filtered its alpha to zero — at some
            // edges it does. Leaving those transparent instead would disagree
            // with the bake on real seat planes while every synthetic case still
            // matched, which is how this was found.
            bytes[offset * 4 + 3] = 255
            let alpha = Int((value >> 24) & 0xFF)
            guard alpha > 0 else { continue }  // RGB stays zero, as premultiplied
            let scale = Double(alpha) / 255.0
            func unpremultiply(_ channel: UInt32) -> UInt8 {
                let raw = (Double(channel) / scale).rounded(.toNearestOrEven)
                return UInt8(max(0.0, min(255.0, raw)))
            }
            bytes[offset * 4] = unpremultiply((value >> 16) & 0xFF)
            bytes[offset * 4 + 1] = unpremultiply((value >> 8) & 0xFF)
            bytes[offset * 4 + 2] = unpremultiply(value & 0xFF)
        }
        return bytes
    }

    private struct Manifest: Decodable {
        struct Palette: Decodable {
            let transparentIndex: Int
            let shadowIndex: Int
            let bodyIndexBase: Int
            let materialSlots: Int
            let shadesPerSlot: Int

            enum CodingKeys: String, CodingKey {
                case transparentIndex = "transparent_index"
                case shadowIndex = "shadow_index"
                case bodyIndexBase = "body_index_base"
                case materialSlots = "material_slots"
                case shadesPerSlot = "shades_per_slot"
            }
        }

        struct Shadow: Decodable {
            let embedded: Bool
            let owner: String
        }

        struct Frame: Decodable {
            let atlas: String
            let name: String
            let width: Int
            let height: Int
            let offset: Int
            let length: Int
            let texturePixels: [Int]
            let trimOriginTopLeftPixels: [Int]
            let pivotFromCropBottomLeftPixels: [Double]
            let sha256: String
            let empty: Bool

            enum CodingKeys: String, CodingKey {
                case atlas, name, width, height, offset, length, sha256, empty
                case texturePixels = "texture_px"
                case trimOriginTopLeftPixels = "trim_origin_top_left_px"
                case pivotFromCropBottomLeftPixels = "pivot_from_crop_bottom_left_px"
            }
        }

        let schema: String
        let version: Int
        let character: String
        let blob: String
        let blobSHA256: String
        let byteOrder: String
        let storage: String
        let sourceCanvasPixels: [Int]
        let sourcePivotFromCanvasBottomLeftPixels: [Double]
        let compatibilityDisplaySize: [Double]
        let displayUnitsPerSourcePixel: [Double]
        let textureScale: Double
        let textureFilter: String
        let colors: [Int]
        let palette: Palette
        let shadow: Shadow
        let fallback: String
        let frames: [Frame]

        enum CodingKeys: String, CodingKey {
            case schema, version, character, blob, storage, colors, palette, shadow, fallback, frames
            case blobSHA256 = "blob_sha256"
            case byteOrder = "byte_order"
            case sourceCanvasPixels = "source_canvas_px"
            case sourcePivotFromCanvasBottomLeftPixels = "source_pivot_from_canvas_bottom_left_px"
            case compatibilityDisplaySize = "compatibility_display_size"
            case displayUnitsPerSourcePixel = "display_units_per_source_pixel"
            case textureScale = "texture_scale"
            case textureFilter = "texture_filter"
        }
    }

    private static func validatePaletteMetadata(_ metadata: Manifest.Palette) throws {
        guard metadata.transparentIndex == IEPalette.colorKeyIndex,
              metadata.shadowIndex == IEPalette.shadowIndex,
              metadata.bodyIndexBase == IEMaterialSlot.metal.paletteOffset,
              metadata.materialSlots == IEMaterialSlot.allCases.count,
              metadata.shadesPerSlot == IEPaperdollColours.numCols else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "palette metadata differs from the seven-row IE layout"
            )
        }
    }

    private static func validateLeaf(_ value: String, field: String) throws {
        guard !value.isEmpty,
              value != ".",
              value != "..",
              !value.contains("/"),
              !value.contains("\\") else {
            throw IEIndexedSpriteError.malformedManifest(reason: "\(field) is not a resource leaf")
        }
    }

    private static func validateFrameLeaf(
        _ value: String,
        suffix: String,
        id: FrameID,
        field: String
    ) throws {
        do {
            try validateLeaf(value, field: field)
        } catch {
            throw invalid(id, "\(field) is not a resource leaf")
        }
        guard value.hasSuffix(suffix) else {
            throw invalid(id, "\(field) must end in \(suffix)")
        }
    }

    private static func positiveSize(_ values: [Int], field: String) throws -> PixelSize {
        guard values.count == 2, values[0] > 0, values[1] > 0 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "\(field) must contain two positive values")
        }
        return PixelSize(width: values[0], height: values[1])
    }

    private static func positiveVector(_ values: [Double], field: String) throws -> PixelVector {
        guard values.count == 2,
              values[0].isFinite, values[1].isFinite,
              values[0] > 0, values[1] > 0 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "\(field) must contain two positive finite values")
        }
        return PixelVector(x: values[0], y: values[1])
    }

    private static func finiteManifestVector(
        _ values: [Double],
        field: String
    ) throws -> PixelVector {
        guard values.count == 2, values[0].isFinite, values[1].isFinite else {
            throw IEIndexedSpriteError.malformedManifest(
                reason: "\(field) must contain two finite values"
            )
        }
        return PixelVector(x: values[0], y: values[1])
    }

    private static func nonnegativeSize(
        _ values: [Int],
        id: FrameID,
        field: String
    ) throws -> PixelSize {
        guard values.count == 2, values[0] >= 0, values[1] >= 0 else {
            throw invalid(id, "\(field) must contain two non-negative values")
        }
        return PixelSize(width: values[0], height: values[1])
    }

    private static func finiteVector(
        _ values: [Double],
        id: FrameID,
        field: String
    ) throws -> PixelVector {
        guard values.count == 2, values[0].isFinite, values[1].isFinite else {
            throw invalid(id, "\(field) must contain two finite values")
        }
        return PixelVector(x: values[0], y: values[1])
    }

    private static func invalid(_ id: FrameID, _ reason: String) -> IEIndexedSpriteError {
        .invalidFrame(atlas: id.atlas, name: id.name, reason: reason)
    }

    private static func littleEndianUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private static func sha256(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var result: [UInt8] = []
        result.reserveCapacity(64)
        for byte in SHA256.hash(data: data) {
            result.append(digits[Int(byte >> 4)])
            result.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: result, as: UTF8.self)
    }
}
