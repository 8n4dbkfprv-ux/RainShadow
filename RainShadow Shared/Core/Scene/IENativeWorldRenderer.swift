import CoreGraphics
import Foundation
import Metal
import SpriteKit

/// Draws the live world, in its existing painter order, into one native raster.
/// The original graph continues owning animation, navigation and input. Only
/// presentation is replaced; no node is moved, hidden or reparented for capture.
/// Plain artwork and indexed actors use the integer compositor. SpriteKit is
/// retained as a *source rasterizer* for authored warps, paths, fog and particles,
/// never as the final alpha blender between world draw items.
@MainActor
final class IENativeWorldRenderer {
    private struct Item {
        let node: SKNode
        let z: CGFloat
        let opacity: CGFloat
        let order: Int
    }
    private struct TextureEntry {
        let source: SKTexture // retain identity: an address must not be recycled
        let native: Bool
        let texture: MTLTexture
        let bytes: Int
        /// Monotonic tick of the last frame that drew this, for LRU eviction.
        var lastUsed: Int
    }
    private final class ParticlePass {
        let scene = SKScene()
        let camera = SKCameraNode()
        let renderer: SKRenderer
        var transforms: [(SKNode, SKNode)] = []
        var clock = ProcessInfo.processInfo.systemUptime
        var time: TimeInterval = 0
        init(device: MTLDevice) {
            renderer = SKRenderer(device: device)
            scene.scaleMode = .fill
            scene.backgroundColor = .clear
            scene.addChild(camera)
            scene.camera = camera
            renderer.scene = scene
        }
    }
    private let compositor: IENativeCompositor
    private let sourceRenderer: SKRenderer
    private let sourceScene = SKScene()
    private let sourceCamera = SKCameraNode()
    private let queue: MTLCommandQueue
    private var textures: [ObjectIdentifier: TextureEntry] = [:]
    private var maskCache: [ObjectIdentifier: (WallStencilTexture, MTLBuffer)] = [:]
    /// Depth/stencil attachments for the SpriteKit source passes, keyed by size.
    ///
    /// `SKView` always hands SpriteKit a `depth32Float_stencil8` attachment. For
    /// some draws SpriteKit binds a depth-stencil state with `frontFaceStencil`
    /// and `backFaceStencil` set, and against a pass whose `stencilAttachment`
    /// is nil that fails `validateCommonDrawErrors:` outright. A pass built here
    /// by hand therefore has to supply one too.
    ///
    /// Measured, not assumed — two of the four node kinds this renderer sends
    /// through `SKRenderer` take that path, and both ship in this game:
    ///
    /// - an `SKCropNode` whose `maskNode` is a *sprite*. That is `addWindowRain`
    ///   whenever `office_window_glass_mask` registers; the `SKShapeNode` mask
    ///   on the pre-V11 rollback branch does not stencil.
    /// - an `SKShapeNode` filled on a non-convex path, which is every
    ///   `HighlightOutlineLayer` polygon.
    ///
    /// A stroked unfilled ellipse (`GroundCircleNode`), an `SKLabelNode` and a
    /// bare `SKEmitterNode` do not. Nothing here reads either buffer back;
    /// SpriteKit only needs somewhere to put them.
    ///
    /// Kept by size because `renderSource` runs once per source pass per frame,
    /// and the sizes one scene asks for are few and stable.
    private var depthStencils: [SIMD2<Int>: MTLTexture] = [:]
    private var cacheBytes = 0
    private var sourceTime: TimeInterval = 0
    private var particlePasses: [ObjectIdentifier: ParticlePass] = [:]
    private var reportedUnsupported = Set<String>()
    private var sourceFailed = false
    /// Set when this frame has already converted as much new texture as it is
    /// allowed to. Not a failure: the frame is abandoned so the scene keeps its
    /// ordinary SpriteKit presentation for a moment, and the rest of the working
    /// set converts on the frames that follow.
    private var budgetExhausted = false
    private var convertedPixelsThisFrame = 0
    private var useTick = 0
    /// Roughly one 2048×2048 texture. The first conversion of a frame is always
    /// allowed through, however large, so a 4096×2304 area plate still lands;
    /// this only stops a *second* expensive one joining it in the same frame.
    private static let conversionPixelBudget = 4 * 1024 * 1024
    private(set) var lastPixels: Data?
    private(set) var lastViewport: IENativeViewport?
    private(set) var lastDrawCount = 0
    private(set) var lastSourcePasses = 0
    private(set) var lastMilliseconds: Double = 0

    init?() {
        guard let compositor = IENativeCompositor(), let queue = compositor.device.makeCommandQueue() else { return nil }
        self.compositor = compositor
        self.queue = queue
        sourceRenderer = SKRenderer(device: compositor.device)
        sourceScene.scaleMode = .fill // resizeFill would import Retina points!
        sourceScene.backgroundColor = .clear
        sourceScene.addChild(sourceCamera)
        sourceScene.camera = sourceCamera
        sourceRenderer.scene = sourceScene
    }

    func render(scene: BaseGameScene) -> SKTexture? {
        let start = CFAbsoluteTimeGetCurrent()
        lastPixels = nil
        lastViewport = nil
        sourceFailed = false
        budgetExhausted = false
        convertedPixelsThisFrame = 0
        useTick &+= 1
        let viewport = IENativeViewport(viewSize: scene.size, cameraCenter: scene.gameCamera.position,
                                        cameraScale: scene.gameCamera.xScale,
                                        nativeScale: OfficeInteriorScale.cameraScaleAt100Percent)
        guard viewport.width <= 8192, viewport.height <= 8192,
              viewport.width * viewport.height <= 16_777_216 else { return nil }
        var items = [Item]()
        func visit(_ node: SKNode, z: CGFloat, opacity: CGFloat) {
            guard !node.isHidden, node.alpha > 0 else { return }
            let alpha = opacity * node.alpha, depth = z + node.zPosition
            // A crop is a source-rasterizer group, so its mask continues clipping
            // its children. Ordinary containers do not create a draw-order group.
            let draws = node is SKSpriteNode || node is SKShapeNode || node is SKLabelNode
                || node is SKEmitterNode || node is SKCropNode
            if draws {
                items.append(Item(node: node, z: depth, opacity: alpha, order: items.count))
            }
            if !(node is SKCropNode) {
                for child in node.children { visit(child, z: depth, opacity: alpha) }
            }
        }
        for root in scene.nativeWorldRoots { visit(root, z: 0, opacity: 1) }
        items.sort { $0.z == $1.z ? $0.order < $1.order : $0.z < $1.z }
        let liveIDs = Set(items.map { ObjectIdentifier($0.node) })
        particlePasses = particlePasses.filter { liveIDs.contains($0.key) }
        var layers = [IENativeCompositor.Layer]()
        lastSourcePasses = 0
        for item in items {
            if let sprite = item.node as? SKSpriteNode,
               ![.alpha, .add].contains(sprite.blendMode) {
                let description = "\(sprite.name ?? "unnamed"): blend \(sprite.blendMode.rawValue)"
                if reportedUnsupported.insert(description).inserted {
                    FileHandle.standardError.write(Data("native renderer: retaining original presentation for unsupported \(description)\n".utf8))
                }
                return nil // Fail the whole frame, never silently change a blend.
            }
            if let layer = direct(item, scene: scene, viewport: viewport) {
                layers.append(layer)
            } else if !budgetExhausted,
                      let layer = rasterized(item, scene: scene, viewport: viewport) {
                layers.append(layer)
                lastSourcePasses += 1
            }
            // Never present a partially missing world. `budgetExhausted` takes
            // the same exit as a failure by design: both mean "this frame cannot
            // be composited correctly", and the caller's answer to that is
            // already to leave the original presentation up.
            if sourceFailed || budgetExhausted { return nil }
        }
        guard let pixels = compositor.render(layers, viewport: viewport),
              let image = Self.image(pixels, width: viewport.width, height: viewport.height) else { return nil }
        lastPixels = pixels
        lastViewport = viewport
        lastDrawCount = layers.count
        let texture = SKTexture(cgImage: image)
        // The ONLY play-zoom/backing-scale enlargement is the completed buffer.
        // No smoothing is reintroduced after the integer blits.
        texture.filteringMode = .nearest
        lastMilliseconds = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return texture
    }

    private func direct(_ item: Item, scene: BaseGameScene, viewport: IENativeViewport) -> IENativeCompositor.Layer? {
        guard let sprite = item.node as? SKSpriteNode, sprite.warpGeometry == nil,
              sprite.colorBlendFactor == 0,
              [.alpha, .add].contains(sprite.blendMode),
              sprite.shader == nil || sprite.shader?.source == IEBlitShader.source else { return nil }
        let origin = scene.convert(CGPoint.zero, from: sprite)
        let xPoint = scene.convert(CGPoint(x: 1, y: 0), from: sprite)
        let yPoint = scene.convert(CGPoint(x: 0, y: 1), from: sprite)
        let axisX = CGPoint(x: xPoint.x - origin.x, y: xPoint.y - origin.y)
        let axisY = CGPoint(x: yPoint.x - origin.x, y: yPoint.y - origin.y)
        guard abs(axisX.y) < 0.00001, abs(axisY.x) < 0.00001 else { return nil }
        let native = (sprite as? IEAvatarNode)?.currentFrame?.native
        var rect: CGRect
        if let native {
            let foot = viewport.pixel(origin)
            let sx = abs(axisX.x) * native.unitsPerPixel.width / viewport.unitsPerPixel
            let sy = abs(axisY.y) * native.unitsPerPixel.height / viewport.unitsPerPixel
            let w = (CGFloat(native.frame.width) * sx).rounded()
            let h = (CGFloat(native.frame.height) * sy).rounded()
            let px = (CGFloat(native.frame.origin.x) * sx).rounded()
            let py = (CGFloat(native.frame.origin.y) * sy).rounded()
            rect = CGRect(x: foot.x.rounded() - (axisX.x < 0 ? w - px : px),
                          y: foot.y.rounded() - (axisY.y < 0 ? h - py : py), width: w, height: h)
        } else {
            let a = scene.convert(CGPoint(x: -sprite.anchorPoint.x * sprite.size.width,
                                          y: -sprite.anchorPoint.y * sprite.size.height), from: sprite)
            let b = scene.convert(CGPoint(x: (1 - sprite.anchorPoint.x) * sprite.size.width,
                                          y: (1 - sprite.anchorPoint.y) * sprite.size.height), from: sprite)
            let leftTop = viewport.pixel(CGPoint(x: min(a.x, b.x), y: max(a.y, b.y)))
            rect = CGRect(x: leftTop.x.rounded(), y: leftTop.y.rounded(),
                          width: (abs(b.x - a.x) / viewport.unitsPerPixel).rounded(),
                          height: (abs(b.y - a.y) / viewport.unitsPerPixel).rounded())
        }
        guard rect.width > 0, rect.height > 0,
              rect.intersects(CGRect(x: 0, y: 0, width: viewport.width, height: viewport.height)),
              let source = sprite.texture,
              let texture = texture(source, native: native) else { return nil }
        var layer = IENativeCompositor.Layer(texture: texture, rect: rect)
        layer.linear = native == nil && source.filteringMode == .linear
        layer.premultiplied = native == nil
        layer.mirrorX = axisX.x < 0
        layer.mirrorY = axisY.y < 0
        layer.nativeClipping = native != nil && rect.width == CGFloat(texture.width)
            && rect.height == CGFloat(texture.height)
        layer.opacity = UInt32(min(255, max(0, (item.opacity * 255).rounded())))
        layer.blend = sprite.blendMode == .add ? 1 : 0
        if let shader = sprite.shader {
            if shader.uniformNamed(IEBlitShader.Uniform.colorMod)?.floatValue == 1 { layer.flags |= IEBlitFlags.colorMod.rawValue }
            if shader.uniformNamed(IEBlitShader.Uniform.grey)?.floatValue == 1 { layer.flags |= IEBlitFlags.grey.rawValue }
            if shader.uniformNamed(IEBlitShader.Uniform.sepia)?.floatValue == 1 { layer.flags |= IEBlitFlags.sepia.rawValue }
            if let tint = shader.uniformNamed(IEBlitShader.Uniform.tint)?.vectorFloat4Value {
                layer.tint = SIMD4<UInt32>(tint * 255 + 0.5)
            }
        }
        if let stencil = (sprite as? IEAvatarNode)?.nativeWallStencil {
            let key = ObjectIdentifier(stencil)
            if maskCache[key] == nil {
                let buffer = stencil.mask.rgba.withUnsafeBytes {
                    compositor.device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
                }
                if let buffer { maskCache[key] = (stencil, buffer) }
            }
            layer.stencil = maskCache[key]?.1
            layer.stencilSize = SIMD2(UInt32(stencil.mask.columns), UInt32(stencil.mask.rows))
            let r = stencil.worldFrame
            layer.stencilWorld = SIMD4(Float(r.minX), Float(r.minY), Float(r.width), Float(r.height))
        }
        return layer
    }

    private func texture(_ source: SKTexture, native: IEAvatarNativeFrame?) -> MTLTexture? {
        let key = ObjectIdentifier(source)
        if let hit = textures[key], hit.native == (native != nil) {
            textures[key]?.lastUsed = useTick
            return hit.texture
        }
        let data: Data
        let w: Int, h: Int
        if let native {
            data = native.rgba; w = native.frame.width; h = native.frame.height
        } else {
            let image = source.cgImage()
            w = image.width; h = image.height
            // Converting a texture the compositor has not seen costs a decode, a
            // redraw and two full-size copies. `office_suite_plate` is 4096×2304,
            // about 38 MB a copy, and the first frame in an area wants several of
            // these at once. Spread them: convert until the budget is spent, then
            // abandon the frame and let the ordinary SpriteKit presentation stand
            // for a moment. Always allow the first one through, whatever its size,
            // so an area whose plate alone exceeds the budget still converges.
            if convertedPixelsThisFrame > 0, convertedPixelsThisFrame >= Self.conversionPixelBudget {
                budgetExhausted = true
                return nil
            }
            convertedPixelsThisFrame += w * h
            guard let bytes = Self.rgbaBytes(of: image, width: w, height: h) else {
                sourceFailed = true
                return nil
            }
            data = bytes
        }
        guard let texture = compositor.texture(rgba: data, width: w, height: h) else {
            sourceFailed = true
            return nil
        }
        // Area paging must not turn a walk across a ward into a retained atlas of
        // every page ever seen. Evict least-recently-drawn entries until the new
        // one fits, rather than emptying the cache: at a working set near the cap
        // a wholesale clear re-decodes *everything* on the very next frame, which
        // turns a one-time cost into a permanent one.
        let limit = 192 * 1024 * 1024
        if cacheBytes + data.count > limit {
            for entry in textures.sorted(by: { $0.value.lastUsed < $1.value.lastUsed }) {
                guard cacheBytes + data.count > limit else { break }
                guard entry.value.lastUsed != useTick else { continue } // in use this frame
                cacheBytes -= entry.value.bytes
                textures.removeValue(forKey: entry.key)
            }
        }
        textures[key] = TextureEntry(source: source, native: native != nil, texture: texture,
                                     bytes: data.count, lastUsed: useTick)
        cacheBytes += data.count
        return texture
    }

    /// The image's own bytes when they are already what the compositor wants,
    /// otherwise a redraw.
    ///
    /// A `CGContext.draw` of a 4096×2304 plate is pure waste when the decoded
    /// image is already 8-bit straight-row RGBA, which the generated art is.
    /// The redraw stays for everything else — atlas-backed textures, indexed or
    /// 16-bit sources, row padding.
    private static func rgbaBytes(of image: CGImage, width w: Int, height h: Int) -> Data? {
        let alpha = image.alphaInfo
        let order = image.bitmapInfo.intersection(.byteOrderMask)
        // The redraw also colour-converts into DeviceRGB. Taking the bytes
        // directly skips that, so only do it when the conversion would be the
        // identity: an image already in DeviceRGB or sRGB. Anything else — a
        // wide-gamut export, a greyscale profile — keeps the CGContext path.
        let space = image.colorSpace
        let identityColorSpace = space.map {
            $0 == CGColorSpaceCreateDeviceRGB()
                || $0.name == CGColorSpace.sRGB
        } ?? false
        if image.bitsPerComponent == 8, image.bitsPerPixel == 32,
           image.bytesPerRow == w * 4,
           alpha == .premultipliedLast,
           order == .byteOrderDefault || order == .byteOrder32Big,
           identityColorSpace,
           let data = image.dataProvider?.data as Data?,
           data.count == w * h * 4 {
            return data
        }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8,
                                       bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Data(bytes)
    }

    private func rasterized(_ item: Item, scene: BaseGameScene, viewport: IENativeViewport) -> IENativeCompositor.Layer? {
        let node = item.node
        // An emitter/crop may have particles beyond calculateAccumulatedFrame.
        // Its authored clipping is applied by SpriteKit; capture the viewport.
        let isParticles = node is SKEmitterNode || node is SKCropNode
        let world: CGRect
        if isParticles { world = viewport.worldRect }
        else {
            guard let parent = node.parent else { return nil }
            let r = node.calculateAccumulatedFrame()
            let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                           CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)].map { scene.convert($0, from: parent) }
            world = CGRect(x: corners.map(\.x).min()!, y: corners.map(\.y).min()!,
                           width: corners.map(\.x).max()! - corners.map(\.x).min()!,
                           height: corners.map(\.y).max()! - corners.map(\.y).min()!)
                .insetBy(dx: -viewport.unitsPerPixel, dy: -viewport.unitsPerPixel).intersection(viewport.worldRect)
        }
        guard !world.isNull, !world.isEmpty else { return nil }
        let p = viewport.pixel(CGPoint(x: world.minX, y: world.maxY))
        let left = Int(floor(p.x)), top = Int(floor(p.y))
        let w = max(1, Int(ceil(world.width / viewport.unitsPerPixel + p.x - CGFloat(left))))
        let h = max(1, Int(ceil(world.height / viewport.unitsPerPixel + p.y - CGFloat(top))))
        let frame = CGRect(x: left, y: top, width: w, height: h)
        let particleKey = ObjectIdentifier(node)
        if isParticles, let pass = particlePasses[particleKey] {
            for (original, copy) in pass.transforms { transform(original, to: copy) }
            return renderSource(pass.scene, camera: pass.camera, renderer: pass.renderer,
                                frame: frame, viewport: viewport, time: particleTime(pass), blend: particleBlend(node))
        }
        guard let copy = visualCopy(node, includeChildren: node is SKCropNode) else { return nil }
        if let circle = copy as? SKShapeNode,
           node is GroundCircleNode || node.inParentHierarchy(scene.highlightOutlineLayer) {
            circle.lineWidth = viewport.unitsPerPixel
            circle.isAntialiased = false
        }
        var topNode = copy
        var transforms: [(SKNode, SKNode)] = [(node, copy)]
        var ancestor = node.parent
        while let original = ancestor, original !== scene {
            let parent = SKNode()
            transform(original, to: parent)
            parent.addChild(topNode)
            transforms.append((original, parent))
            topNode = parent
            ancestor = original.parent
        }
        if isParticles {
            // Keep a live simulation copy. Re-copying an emitter each frame
            // resets its particle ages; advancing by a tiny fake dt loses rain.
            let pass = ParticlePass(device: compositor.device)
            pass.transforms = transforms
            pass.scene.addChild(topNode)
            particlePasses[particleKey] = pass
            func warm(_ node: SKNode) {
                if let emitter = node as? SKEmitterNode { emitter.advanceSimulationTime(1.5) }
                for child in node.children { warm(child) }
            }
            warm(copy)
            return renderSource(pass.scene, camera: pass.camera, renderer: pass.renderer,
                                frame: frame, viewport: viewport, time: particleTime(pass), blend: particleBlend(node))
        }
        sourceScene.addChild(topNode)
        defer { topNode.removeFromParent() }
        sourceTime += 0.000001 // Source copies have no actions; live logic is untouched.
        let blend: UInt32 = (node as? SKSpriteNode)?.blendMode == .add ? 1 : 0
        return renderSource(sourceScene, camera: sourceCamera, renderer: sourceRenderer,
                            frame: frame, viewport: viewport, time: sourceTime, blend: blend)
    }

    private func particleTime(_ pass: ParticlePass) -> TimeInterval {
        let now = ProcessInfo.processInfo.systemUptime
        if !pass.transforms.contains(where: { $0.0.isPaused }) {
            pass.time += min(0.1, max(0, now - pass.clock))
        }
        pass.clock = now
        return pass.time
    }

    private func particleBlend(_ node: SKNode) -> UInt32 {
        if let emitter = node as? SKEmitterNode { return emitter.particleBlendMode == .add ? 1 : 0 }
        // Shipped crop groups contain only additive window rain. Alpha groups
        // stay source-over; mixed blend groups require a separate adapter.
        return !node.children.isEmpty && node.children.allSatisfy { particleBlend($0) == 1 } ? 1 : 0
    }

    private func renderSource(_ scene: SKScene, camera: SKCameraNode, renderer: SKRenderer,
                              frame: CGRect, viewport: IENativeViewport, time: TimeInterval,
                              blend: UInt32) -> IENativeCompositor.Layer? {
        let w = Int(frame.width), h = Int(frame.height)
        scene.size = frame.size
        camera.position = CGPoint(x: viewport.worldRect.minX + frame.midX * viewport.unitsPerPixel,
                                  y: viewport.worldRect.maxY - frame.midY * viewport.unitsPerPixel)
        camera.setScale(viewport.unitsPerPixel)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let target = compositor.device.makeTexture(descriptor: descriptor),
              let depthStencil = depthStencil(width: w, height: h),
              let command = queue.makeCommandBuffer() else {
            sourceFailed = true
            return nil
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        // Cleared for each pass and never stored: this is scratch space for
        // SpriteKit's own stencilling, not a buffer this renderer reads.
        pass.depthAttachment.texture = depthStencil
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        pass.stencilAttachment.texture = depthStencil
        pass.stencilAttachment.loadAction = .clear
        pass.stencilAttachment.storeAction = .dontCare
        pass.stencilAttachment.clearStencil = 0
        renderer.update(atTime: time)
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h),
                              commandBuffer: command, renderPassDescriptor: pass)
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else {
            sourceFailed = true
            return nil
        }
        return IENativeCompositor.Layer(texture: target, rect: frame, linear: false, blend: blend)
    }

    /// The `depth32Float_stencil8` attachment for a source pass of this size.
    ///
    /// `.private` rather than `.memoryless`: macOS 15 is a deployment target and
    /// Intel Macs have no memoryless storage.
    private func depthStencil(width: Int, height: Int) -> MTLTexture? {
        let key = SIMD2(width, height)
        if let hit = depthStencils[key] { return hit }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float_stencil8, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = .renderTarget
        guard let texture = compositor.device.makeTexture(descriptor: descriptor) else { return nil }
        // A live window resize walks through many sizes. Keep the working set
        // rather than every size the window has ever passed through.
        if depthStencils.count >= 8 { depthStencils.removeAll() }
        depthStencils[key] = texture
        return texture
    }

    private func transform(_ source: SKNode, to target: SKNode) {
        target.position = source.position
        target.xScale = source.xScale; target.yScale = source.yScale
        target.zRotation = source.zRotation
        target.alpha = source.alpha
        target.isHidden = source.isHidden
        // Each source pass holds one draw item, so depth is handled by the queue.
        target.zPosition = 0
    }

    private func visualCopy(_ source: SKNode, includeChildren: Bool) -> SKNode? {
        let copy: SKNode
        if let sprite = source as? SKSpriteNode {
            let node = SKSpriteNode(texture: sprite.texture, color: sprite.color, size: sprite.size)
            node.anchorPoint = sprite.anchorPoint
            node.centerRect = sprite.centerRect
            node.colorBlendFactor = sprite.colorBlendFactor
            node.shader = sprite.shader
            node.warpGeometry = sprite.warpGeometry
            node.subdivisionLevels = sprite.subdivisionLevels
            copy = node
        } else if let shape = source as? SKShapeNode {
            let node = SKShapeNode(path: shape.path ?? CGPath(rect: .zero, transform: nil))
            node.fillColor = shape.fillColor; node.strokeColor = shape.strokeColor
            node.lineWidth = shape.lineWidth; node.glowWidth = shape.glowWidth
            node.isAntialiased = shape.isAntialiased
            copy = node
        } else if let crop = source as? SKCropNode {
            let node = SKCropNode()
            node.maskNode = crop.maskNode.flatMap { visualCopy($0, includeChildren: true) }
            copy = node
        } else if source is SKLabelNode || source is SKEmitterNode {
            copy = source.copy() as! SKNode
            copy.removeAllActions()
            copy.removeAllChildren()
        } else { copy = SKNode() }
        transform(source, to: copy)
        if includeChildren {
            for child in source.children {
                if let childCopy = visualCopy(child, includeChildren: true) {
                    childCopy.zPosition = child.zPosition
                    copy.addChild(childCopy)
                }
            }
        }
        return copy
    }

    static func image(_ bytes: Data, width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: bytes as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
