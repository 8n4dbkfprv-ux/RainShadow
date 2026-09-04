import CoreGraphics
import Foundation
import Metal

/// Shared native framebuffer. Metal is only the executor: normal source-over is
/// Pixels.h ShaderBlend<true>'s integer arithmetic, not fixed-function blending.
/// Buffers are byte RGBA, so sRGB render-target conversion cannot change a step.
/// See IESoftwareBlit and the independent pinned-C++ differential gate.
@MainActor
final class IENativeCompositor {
    struct Layer {
        var texture: MTLTexture
        var rect: CGRect
        var source = CGRect(x: 0, y: 0, width: 1, height: 1)
        var linear = true
        var premultiplied = true
        var mirrorX = false
        var mirrorY = false
        /// SDL1 clips native source/destination together, then mirrors the
        /// clipped source. Only valid for unscaled integer native frames.
        var nativeClipping = false
        var tint = SIMD4<UInt32>(255, 255, 255, 255)
        var flags: UInt32 = 0
        var opacity: UInt32 = 255
        var blend: UInt32 = 0
        var stencil: MTLBuffer?
        var stencilSize = SIMD2<UInt32>(0, 0)
        var stencilWorld = SIMD4<Float>(0, 0, 1, 1)
    }

    // All fields occupy complete 16-byte slots, mirrored explicitly in Metal.
    private struct Parameters {
        var rect: SIMD4<Float>
        var uv: SIMD4<Float>
        var clip: SIMD4<UInt32>
        var tint: SIMD4<UInt32>
        var mode: SIMD4<UInt32>
        var dimensions: SIMD4<UInt32>
        var viewport: SIMD4<Float>
        var stencilWorld: SIMD4<Float>
    }

    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let zeroMask: MTLBuffer
    private var framebuffer: MTLBuffer?
    private(set) var width = 0
    private(set) var height = 0

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let blank = device.makeBuffer(length: 4, options: .storageModeShared),
              let library = try? AreaLoadTrace.measure("native.makeLibrary", body: {
                  try? device.makeLibrary(source: Self.source, options: nil)
              }),
              let function = library.makeFunction(name: "ieComposite"),
              let pipeline = try? device.makeComputePipelineState(function: function) else { return nil }
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        zeroMask = blank
        memset(blank.contents(), 0, 4)
    }

    func texture(rgba: Data, width: Int, height: Int) -> MTLTexture? {
        guard width > 0, height > 0, rgba.count == width * height * 4 else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                  width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        rgba.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                            withBytes: $0.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }

    func render(_ layers: [Layer], viewport: IENativeViewport) -> Data? {
        let w = viewport.width, h = viewport.height
        guard w <= 8192, h <= 8192, w * h <= 16_777_216 else { return nil }
        let length = w * h * 4
        if w != width || h != height {
            framebuffer = device.makeBuffer(length: length, options: .storageModeShared)
            width = w; height = h
        }
        guard let framebuffer, let command = queue.makeCommandBuffer() else { return nil }
        // Opaque black outside the painted area; not scene.backgroundColor's grade.
        let bytes = framebuffer.contents().bindMemory(to: UInt32.self, capacity: w * h)
        bytes.update(repeating: 0xff00_0000, count: w * h)
        for layer in layers {
            let clipped = layer.rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))
            guard !clipped.isNull, !clipped.isEmpty else { continue }
            let x = max(0, Int(floor(clipped.minX))), y = max(0, Int(floor(clipped.minY)))
            let right = min(w, Int(ceil(clipped.maxX))), bottom = min(h, Int(ceil(clipped.maxY)))
            guard right > x, bottom > y, let encoder = command.makeComputeCommandEncoder() else { continue }
            var parameters = Parameters(
                rect: SIMD4(Float(layer.rect.minX), Float(layer.rect.minY), Float(layer.rect.width), Float(layer.rect.height)),
                uv: SIMD4(Float(layer.source.minX), Float(layer.source.minY), Float(layer.source.width), Float(layer.source.height)),
                clip: SIMD4(UInt32(x), UInt32(y), UInt32(right - x), UInt32(bottom - y)),
                tint: layer.tint,
                mode: SIMD4(layer.flags, layer.opacity, layer.blend,
                            (layer.linear ? 1 : 0) | (layer.premultiplied ? 2 : 0)
                                | (layer.mirrorX ? 4 : 0) | (layer.mirrorY ? 8 : 0)
                                | (layer.nativeClipping ? 16 : 0)),
                dimensions: SIMD4(UInt32(w), UInt32(h), layer.stencilSize.x, layer.stencilSize.y),
                viewport: SIMD4(Float(viewport.worldRect.minX), Float(viewport.worldRect.maxY),
                                Float(viewport.unitsPerPixel), 0),
                stencilWorld: layer.stencilWorld)
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(framebuffer, offset: 0, index: 0)
            encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 1)
            encoder.setBuffer(layer.stencil ?? zeroMask, offset: 0, index: 2)
            encoder.setTexture(layer.texture, index: 0)
            encoder.dispatchThreads(MTLSize(width: right - x, height: bottom - y, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: 16, height: 8, depth: 1))
            // Separate encoders give resource-tracked ordering between draws.
            // No same-texture read/write sampling or framebuffer-fetch extension.
            encoder.endEncoding()
        }
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else { return nil }
        return Data(bytes: framebuffer.contents(), count: length)
    }

    static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct Params {
        float4 rect, uv;
        uint4 clip, tint, mode, dimensions;
        float4 viewport, stencilWorld;
    };
    uint3 div255(uint3 x) { return (x + 1u + (x >> 8u)) >> 8u; }
    kernel void ieComposite(device uchar4* target [[buffer(0)]], constant Params& p [[buffer(1)]],
                            device const uchar4* stencil [[buffer(2)]],
                            texture2d<float> source [[texture(0)]], uint2 tid [[thread_position_in_grid]]) {
        if (any(tid >= p.clip.zw)) return;
        uint2 pixel = p.clip.xy + tid;
        float2 local = (float2(pixel) + 0.5f - p.rect.xy) / p.rect.zw;
        if (any(local < 0.0f) || any(local >= 1.0f)) return;
        if (p.mode.w & 4u) local.x = 1.0f - local.x;
        if (p.mode.w & 8u) local.y = 1.0f - local.y;
        float2 uv = p.uv.xy + local * p.uv.zw;
        if (p.mode.w & 16u) {
            // SDLVideo::BlitSpriteClipped: trim = dst.w - dclipped.w;
            // src.w -= trim; if (dclipped.x > dst.x) src.x += trim;
            float2 trim = p.rect.zw - float2(p.clip.zw);
            float2 start = select(float2(0), trim, float2(p.clip.xy) > p.rect.xy);
            uint2 cell = tid;
            if (p.mode.w & 4u) cell.x = p.clip.z - 1u - cell.x;
            if (p.mode.w & 8u) cell.y = p.clip.w - 1u - cell.y;
            uv = (start + float2(cell) + 0.5f) / p.rect.zw;
        }
        constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
        constexpr sampler pointSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 texel = (p.mode.w & 1u) ? source.sample(linearSampler, uv) : source.sample(pointSampler, uv);
        if (texel.a <= 0.0f) return;
        float3 straight = (p.mode.w & 2u) ? texel.rgb / texel.a : texel.rgb;
        uint3 c = uint3(clamp(floor(straight * 255.0f + 0.5f), 0.0f, 255.0f));
        uint alpha = uint(clamp(floor(texel.a * float(p.mode.y) + 0.5f), 0.0f, 255.0f));
        // Existing area-cover adaptation, on the NATIVE viewport pixel grid.
        // The baked flag map is y-up. Do not mirror its channels with the actor.
        if (p.dimensions.z > 0u) {
            float2 world = float2(p.viewport.x + (float(pixel.x) + 0.5f) * p.viewport.z,
                                  p.viewport.y - (float(pixel.y) + 0.5f) * p.viewport.z);
            float2 st = (world - p.stencilWorld.xy) / p.stencilWorld.zw;
            if (all(st >= 0.0f) && all(st < 1.0f)) {
                uint2 cell = uint2(st * float2(p.dimensions.zw));
                uchar4 m = stencil[cell.y * p.dimensions.z + cell.x];
                if (m.g > 0 && (m.r > 192 || ((pixel.x + pixel.y) & 1u))) return;
            }
        }
        if (p.mode.x & 0x1000u) c = (c * p.tint.rgb) >> 8u;
        if (p.mode.x & 0x80000u) { c >>= 2u; c = uint3(c.r + c.g + c.b); }
        else if (p.mode.x & 0x2000000u) {
            c >>= 2u; uint avg = c.r + c.g + c.b;
            c = uint3(avg + 21u, avg, avg < 32u ? 0u : avg - 32u);
        }
        uint at = pixel.y * p.dimensions.x + pixel.x;
        uint3 d = uint3(target[at].rgb);
        // ShaderBlend<true>, two separate truncations, opaque destination.
        uint3 out = div255(alpha * c) + div255((255u - alpha) * d);
        // Authored light casts are additive art, not the engine's ADD flag.
        // Retain saturating, alpha-weighted addition rather than importing the
        // unrelated Pixels.h ShaderAdditive's uint8 wrap into those paintings.
        if (p.mode.z == 1u) out = min(uint3(255u), d + div255(alpha * c));
        else if (p.mode.z == 2u) out = c; // opaque replacement layer
        target[at] = uchar4(uchar3(out), 255);
    }
    """
}
