import CoreGraphics
import Foundation
import SpriteKit

/// One resolved indexed-avatar frame ready for SpriteKit presentation.
///
/// Size and anchor are inseparable from the texture. A cropped frame cannot be
/// installed with the old 512-cell size or foot anchor without moving the actor
/// relative to navigation, furniture and its external contact shadow.
@MainActor
struct IEAvatarVisualFrame {
    let texture: SKTexture?
    let displaySize: CGSize
    let anchorPoint: CGPoint
    let id: IEIndexedSprite.FrameID?
    let isEmpty: Bool
    /// Native compositor payload, independent of the historical atlas sampler.
    /// Registered SpriteKit geometry remains available for hit tests/fallback.
    var native: IEAvatarNativeFrame? = nil

    static func compatibility(
        texture: SKTexture,
        displaySize: CGSize = OfficeInteriorScale.ActorDisplay.spriteDisplaySize,
        anchorPoint: CGPoint
    ) -> IEAvatarVisualFrame {
        texture.filteringMode = .linear
        return IEAvatarVisualFrame(
            texture: texture,
            displaySize: displaySize,
            anchorPoint: anchorPoint,
            id: nil,
            isEmpty: false
        )
    }
}

/// Resolves a character's byte-exact index bundle once and caches textures.
///
/// GemRB's `BAMImporter::GetFrameInternal` supplies indexed frame pixels and a
/// centre; `CharAnimations` applies the creature palette. `IEIndexedSprite`
/// ports that data model and this class is RainShadow's SpriteKit adapter.
@MainActor
final class IEAvatarFrameLibrary {
    let sprite: IEIndexedSprite
    private var cache: [IEIndexedSprite.FrameID: IEAvatarVisualFrame] = [:]

    init(character: String) throws {
        sprite = try AreaLoadTrace.measure("IEIndexedSprite.load", character) {
            try IEIndexedSprite.load(character: character)
        }
    }

    /// One library per character, for the life of the process.
    ///
    /// Constructing one is a manifest decode, a SHA-256 over the whole index
    /// blob and a per-record validation pass; the instance then caches a
    /// resolved `SKTexture` for every frame it is asked for. All of that used to
    /// be rebuilt from scratch inside each actor node's `init`, which runs once
    /// per area entry — walking office → street → office paid for Voss's entire
    /// animation set three times over, on the main thread, during the transition.
    ///
    /// Sharing one instance between actors is safe: `IEAvatarVisualFrame` is an
    /// immutable value over a shared `SKTexture`, and the only mutation any
    /// consumer makes is `IEAvatarNode.apply` setting `.linear` filtering, which
    /// is what the library set at creation anyway.
    static func shared(character: String) throws -> IEAvatarFrameLibrary {
        if let cached = libraries[character] { return cached }
        let library = try IEAvatarFrameLibrary(character: character)
        libraries[character] = library
        return library
    }

    private static var libraries: [String: IEAvatarFrameLibrary] = [:]

    func frame(atlas: String, name: String) -> IEAvatarVisualFrame? {
        guard let indexed = sprite.frame(atlas: atlas, name: name) else { return nil }
        if let cached = cache[indexed.id] { return cached }

        let visual: IEAvatarVisualFrame
        if indexed.isEmpty {
            visual = IEAvatarVisualFrame(
                texture: nil,
                displaySize: .zero,
                anchorPoint: CGPoint(x: 0.5, y: 0.5),
                id: indexed.id,
                isEmpty: true
            )
        } else if let pivot = indexed.normalizedPivot {
            let texturePixels = sprite.texturePixelSize(for: indexed)
            guard let texture = Self.makeTexture(
                rgba: sprite.rgba(for: indexed),
                width: texturePixels.width,
                height: texturePixels.height
            ) else { return nil }
            texture.filteringMode = .linear
            visual = IEAvatarVisualFrame(
                texture: texture,
                displaySize: CGSize(
                    width: CGFloat(indexed.size.width)
                        * CGFloat(sprite.displayUnitsPerSourcePixel.x),
                    height: CGFloat(indexed.size.height)
                        * CGFloat(sprite.displayUnitsPerSourcePixel.y)
                ),
                anchorPoint: CGPoint(x: CGFloat(pivot.x), y: CGFloat(pivot.y)),
                id: indexed.id,
                isEmpty: false,
                native: try? IEAvatarNativeFrame(sprite: sprite, frame: indexed)
            )
        } else {
            return nil
        }
        cache[indexed.id] = visual
        return visual
    }

    private static func makeTexture(
        rgba: [UInt8],
        width: Int,
        height: Int
    ) -> SKTexture? {
        guard width > 0,
              height > 0,
              rgba.count == width * height * 4 else { return nil }
        let data = Data(rgba)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }
        return SKTexture(cgImage: image)
    }
}

/// Sprite node whose frame setter changes texture, crop size and pivot together.
@MainActor
final class IEAvatarNode: SKSpriteNode {
    private(set) var currentFrame: IEAvatarVisualFrame?
    weak var nativeWallStencil: WallStencilTexture?

    /// This layer's own ``IEBlitShader``.
    ///
    /// Per layer rather than per actor, which an earlier draft got wrong: the
    /// wall-stencil lookup is composed from the sprite's *own* world rect, and an
    /// actor's layers differ in size and anchor. One shared instance would point
    /// all three at whichever layer wrote the uniform last. The tint is still one
    /// answer per actor — `applyBodyTint` writes the same values to every layer.
    lazy var blitShader = IEBlitShader.make(tint: .opaqueWhite, flags: .blended)

    convenience init(frame: IEAvatarVisualFrame?) {
        self.init(texture: nil, color: .clear, size: .zero)
        if let frame { apply(frame) }
    }

    func apply(_ frame: IEAvatarVisualFrame) {
        currentFrame = frame
        texture = frame.texture
        size = frame.displaySize
        anchorPoint = frame.anchorPoint
        isHidden = frame.isEmpty
        texture?.filteringMode = .linear
    }

    func clear() {
        currentFrame = nil
        texture = nil
        size = .zero
        isHidden = true
    }
}

@MainActor
struct IEAvatarNativeFrame {
    let frame: IESoftwareBlit.Frame
    let rgba: Data
    let unitsPerPixel: CGSize

    init(sprite: IEIndexedSprite, frame: IEIndexedSprite.Frame) throws {
        self.frame = try sprite.softwareFrame(for: frame)
        rgba = Data(sprite.resolvedColors(for: frame).flatMap { [$0.r, $0.g, $0.b, $0.a] })
        unitsPerPixel = CGSize(width: sprite.registeredPixelsPerNativePixel * sprite.displayUnitsPerSourcePixel.x,
                              height: sprite.registeredPixelsPerNativePixel * sprite.displayUnitsPerSourcePixel.y)
    }
}

/// Indexed-first sequence loading with one all-or-nothing RGBA-atlas fallback.
/// A partial indexed clip is a data error; mixing its pivots with legacy
/// full-canvas cells would create a visible registration jump mid-animation.
@MainActor
enum IEAvatarFrames {
    static func sequence(
        library: IEAvatarFrameLibrary?,
        atlas: String,
        stems: [String],
        compatibilityAnchor: CGPoint
    ) -> [IEAvatarVisualFrame]? {
        if let library {
            let indexed = stems.compactMap {
                library.frame(atlas: atlas, name: "\($0).png")
            }
            if indexed.count == stems.count {
                return indexed
            }
            assertionFailure("Incomplete indexed-avatar clip \(atlas)")
        }

        let compatibility = stems.compactMap { stem -> IEAvatarVisualFrame? in
            guard let texture = GameArt.texture(named: stem) else { return nil }
            return .compatibility(texture: texture, anchorPoint: compatibilityAnchor)
        }
        return compatibility.count == stems.count ? compatibility : nil
    }
}
