import Foundation

/// Super xBR and Lanczos resampling (Near Infinity
/// `gui/converter/bam/BamFilterTransformResize.java`, LGPL-2.1).
///
/// A 64-row native craft has to reach the 200px registered body. Enlarging the
/// *index plane* with nearest is exact but freezes every native pixel into a
/// hard 3.125x block; enlarging the resolved render with Super xBR is what the
/// sprite actually looks like on screen.
///
/// This is the same transliteration as `ArtSource/Processing/ie_resample.py`,
/// and the two must agree byte-for-byte —
/// `VossWardrobeColorTests.everyVossFrameRoundTripsExactlyToItsCompatibilityAtlasCell`
/// compares a bundle resolved and scaled here against a PNG produced there.
/// `IEResampleTests` pins them to a shared vector.
///
/// **The loops are sequential on purpose.** All three Super xBR passes read the
/// destination buffer they are writing, so raster order is part of the result.
enum IEResample {
    /// `private static final int LANCZOS_KERNEL_SIZE = 3;`
    static let lanczosKernelSize = 3

    /// `Misc.clamp`.
    @inline(__always)
    static func clamp(_ value: Int, _ minimum: Int, _ maximum: Int) -> Int {
        value < minimum ? minimum : (value > maximum ? maximum : value)
    }

    /// Java's `(int)` cast on a float: truncation toward zero, not floor. The
    /// Super xBR weights include negatives, so this is not the same as `floor`.
    @inline(__always)
    static func truncate(_ value: Double) -> Int { Int(value) }

    // MARK: - Lanczos

    /// `private static double lanczos(double x, int kernelSize)`.
    ///
    /// Note the asymmetric bound upstream uses — `x <= -kernelSize || x > kernelSize`.
    static func lanczos(_ x: Double, _ kernelSize: Int) -> Double {
        if x == 0.0 { return 1.0 }
        if x <= Double(-kernelSize) || x > Double(kernelSize) { return 0.0 }
        let scaled = x * Double.pi
        return (Double(kernelSize) * sin(scaled) * sin(scaled / Double(kernelSize)))
            / (scaled * scaled)
    }

    /// `scaleLanczosSample` — one destination pixel, ARGB packed.
    static func lanczosSample(
        _ pixels: [UInt32], _ width: Int, _ height: Int,
        _ x: Double, _ y: Double, _ kernelSize: Int
    ) -> UInt32 {
        var a = 0.0, r = 0.0, g = 0.0, b = 0.0, total = 0.0
        let centerX = Int(x.rounded(.down))
        let centerY = Int(y.rounded(.down))

        for j in (-kernelSize + 1)...kernelSize {
            let sourceY = min(max(centerY + j, 0), height - 1)
            let weightY = lanczos(y - Double(sourceY), kernelSize)
            for i in (-kernelSize + 1)...kernelSize {
                let sourceX = min(max(centerX + i, 0), width - 1)
                let colour = pixels[sourceY * width + sourceX]
                let weight = lanczos(x - Double(sourceX), kernelSize) * weightY

                a += Double((colour >> 24) & 0xFF) * weight
                r += Double((colour >> 16) & 0xFF) * weight
                g += Double((colour >> 8) & 0xFF) * weight
                b += Double(colour & 0xFF) * weight
                total += weight
            }
        }

        let alpha = min(max(truncate(a / total), 0), 255)
        let red = min(max(truncate(r / total), 0), 255)
        let green = min(max(truncate(g / total), 0), 255)
        let blue = min(max(truncate(b / total), 0), 255)
        return UInt32(alpha) << 24 | UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
    }

    /// `scaleLanczos` with the output size given rather than derived.
    ///
    /// Upstream computes `newWidth = (int)(width * factorX)`, which truncates,
    /// while `crunch_avatar` *rounds* the texture size — for some native widths
    /// those disagree by a pixel. Splitting the target out lets both languages
    /// settle on the same canvas without either inventing a rounding rule.
    static func scaleLanczosTo(
        _ pixels: [UInt32], _ width: Int, _ height: Int,
        _ newWidth: Int, _ newHeight: Int, _ kernelSize: Int = lanczosKernelSize
    ) -> (pixels: [UInt32], width: Int, height: Int) {
        let outWidth = max(1, newWidth)
        let outHeight = max(1, newHeight)
        let scaleX = Double(width) / Double(outWidth)
        let scaleY = Double(height) / Double(outHeight)

        var out = [UInt32](repeating: 0, count: outWidth * outHeight)
        for y in 0..<outHeight {
            let sourceY = Double(y) * scaleY
            for x in 0..<outWidth {
                out[y * outWidth + x] = lanczosSample(
                    pixels, width, height, Double(x) * scaleX, sourceY, kernelSize
                )
            }
        }
        return (out, outWidth, outHeight)
    }

    /// Bring the Super xBR schedule's output onto the exact requested canvas.
    ///
    /// Upstream never needs this: its caller takes whatever size the loop lands
    /// on. Ours cannot, so the remainder goes through `scaleLanczosTo` — one more
    /// of the same ported filter, reproducible on both sides.
    static func settle(
        _ pixels: [UInt32], _ width: Int, _ height: Int,
        _ targetWidth: Int, _ targetHeight: Int
    ) -> [UInt32] {
        if width == targetWidth && height == targetHeight { return pixels }
        return scaleLanczosTo(pixels, width, height, targetWidth, targetHeight).pixels
    }

    /// `scaleLanczos`.
    static func scaleLanczos(
        _ pixels: [UInt32], _ width: Int, _ height: Int,
        _ factorX: Double, _ factorY: Double, _ kernelSize: Int = lanczosKernelSize
    ) -> (pixels: [UInt32], width: Int, height: Int) {
        let newWidth = max(1, Int(Double(width) * factorX))
        let newHeight = max(1, Int(Double(height) * factorY))
        let scaleX = Double(width) / Double(newWidth)
        let scaleY = Double(height) / Double(newHeight)

        var out = [UInt32](repeating: 0, count: newWidth * newHeight)
        for y in 0..<newHeight {
            let sourceY = Double(y) * scaleY
            for x in 0..<newWidth {
                out[y * newWidth + x] = lanczosSample(
                    pixels, width, height, Double(x) * scaleX, sourceY, kernelSize
                )
            }
        }
        return (out, newWidth, newHeight)
    }

    // MARK: - Super xBR

    /// `private static int diagonalEdge(int[][] mat, int[] wp)`.
    ///
    /// `mat[i][j]`'s first index is the *x* offset and the second is *y* — that
    /// is how the sampling loops fill it (`Y[sx + 1][sy + 1]`).
    static func diagonalEdge(_ mat: [[Int]], _ wp: [Int]) -> Int {
        let dw1 =
            wp[0] * (abs(mat[0][2] - mat[1][1]) + abs(mat[1][1] - mat[2][0])
                     + abs(mat[1][3] - mat[2][2]) + abs(mat[2][2] - mat[3][1]))
            + wp[1] * (abs(mat[0][3] - mat[1][2]) + abs(mat[2][1] - mat[3][0]))
            + wp[2] * (abs(mat[0][3] - mat[2][1]) + abs(mat[1][2] - mat[3][0]))
            + wp[3] * abs(mat[1][2] - mat[2][1])
            + wp[4] * (abs(mat[0][2] - mat[2][0]) + abs(mat[1][3] - mat[3][1]))
            + wp[5] * (abs(mat[0][1] - mat[1][0]) + abs(mat[2][3] - mat[3][2]))
        let dw2 =
            wp[0] * (abs(mat[0][1] - mat[1][2]) + abs(mat[1][2] - mat[2][3])
                     + abs(mat[1][0] - mat[2][1]) + abs(mat[2][1] - mat[3][2]))
            + wp[1] * (abs(mat[0][0] - mat[1][1]) + abs(mat[2][2] - mat[3][3]))
            + wp[2] * (abs(mat[0][0] - mat[2][2]) + abs(mat[1][1] - mat[3][3]))
            + wp[3] * abs(mat[1][1] - mat[2][2])
            + wp[4] * (abs(mat[1][0] - mat[3][2]) + abs(mat[0][1] - mat[2][3]))
            + wp[5] * (abs(mat[0][2] - mat[1][3]) + abs(mat[2][0] - mat[3][1]))
        return dw1 - dw2
    }

    private static let wgt1 = 0.129633
    private static let wgt2 = 0.175068
    private static let w1 = -wgt1
    private static let w2 = wgt1 + 0.5
    private static let w3 = -wgt2
    private static let w4 = wgt2 + 0.5

    /// `(int)(0.2126f * r + 0.7152f * g + 0.0722f * b)` — Rec. 709, truncated.
    @inline(__always)
    private static func luma(_ r: Int, _ g: Int, _ b: Int) -> Int {
        truncate(0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b))
    }

    /// `scaleSuperXBR2x` — the fixed 2x scaler, three passes.
    static func scaleSuperXBR2x(
        _ pixels: [UInt32], _ width: Int, _ height: Int
    ) -> (pixels: [UInt32], width: Int, height: Int) {
        let factor = 2
        let dstWidth = max(1, width * factor)
        let dstHeight = max(1, height * factor)
        let src = pixels
        var dst = [UInt32](repeating: 0, count: dstWidth * dstHeight)

        var a = [[Int]](repeating: [Int](repeating: 0, count: 4), count: 4)
        var r = a, g = a, b = a, lum = a

        /// Fill the 4x4 windows; `offset` maps (sx, sy) to a source location.
        func sample(
            _ source: [UInt32], _ stride: Int, _ baseY: Int, _ baseX: Int,
            _ yLimit: Int, _ xLimit: Int, lower: Int,
            _ offset: (Int, Int, Int, Int) -> (Int, Int)
        ) {
            for sx in lower...(lower + 3) {
                for sy in lower...(lower + 3) {
                    let (rawY, rawX) = offset(sx, sy, baseY, baseX)
                    let csy = clamp(rawY, 0, yLimit)
                    let csx = clamp(rawX, 0, xLimit)
                    let value = source[csy * stride + csx]
                    let ix = sx - lower, iy = sy - lower
                    a[ix][iy] = Int(value >> 24)
                    r[ix][iy] = Int((value >> 16) & 0xFF)
                    g[ix][iy] = Int((value >> 8) & 0xFF)
                    b[ix][iy] = Int(value & 0xFF)
                    lum[ix][iy] = luma(r[ix][iy], g[ix][iy], b[ix][iy])
                }
            }
        }

        /// The anti-ringing bounds, from the four central samples.
        func limits() -> (Int, Int, Int, Int, Int, Int, Int, Int) {
            (
                max(0, min(a[1][1], a[2][1], a[1][2], a[2][2])),
                max(0, min(r[1][1], r[2][1], r[1][2], r[2][2])),
                max(0, min(g[1][1], g[2][1], g[1][2], g[2][2])),
                max(0, min(b[1][1], b[2][1], b[1][2], b[2][2])),
                min(255, max(a[1][1], a[2][1], a[1][2], a[2][2])),
                min(255, max(r[1][1], r[2][1], r[1][2], r[2][2])),
                min(255, max(g[1][1], g[2][1], g[1][2], g[2][2])),
                min(255, max(b[1][1], b[2][1], b[1][2], b[2][2]))
            )
        }

        func blend(_ diagEdge: Int, _ wa: Double, _ wb: Double) -> (Int, Int, Int, Int) {
            if diagEdge <= 0 {
                return (
                    truncate(wa * Double(a[0][3] + a[3][0]) + wb * Double(a[1][2] + a[2][1])),
                    truncate(wa * Double(r[0][3] + r[3][0]) + wb * Double(r[1][2] + r[2][1])),
                    truncate(wa * Double(g[0][3] + g[3][0]) + wb * Double(g[1][2] + g[2][1])),
                    truncate(wa * Double(b[0][3] + b[3][0]) + wb * Double(b[1][2] + b[2][1]))
                )
            }
            return (
                truncate(wa * Double(a[0][0] + a[3][3]) + wb * Double(a[1][1] + a[2][2])),
                truncate(wa * Double(r[0][0] + r[3][3]) + wb * Double(r[1][1] + r[2][2])),
                truncate(wa * Double(g[0][0] + g[3][3]) + wb * Double(g[1][1] + g[2][2])),
                truncate(wa * Double(b[0][0] + b[3][3]) + wb * Double(b[1][1] + b[2][2]))
            )
        }

        func pack(
            _ ai: Int, _ ri: Int, _ gi: Int, _ bi: Int,
            _ bounds: (Int, Int, Int, Int, Int, Int, Int, Int)
        ) -> UInt32 {
            let alpha = clamp(ai, bounds.0, bounds.4)
            let red = clamp(ri, bounds.1, bounds.5)
            let green = clamp(gi, bounds.2, bounds.6)
            let blue = clamp(bi, bounds.3, bounds.7)
            return UInt32(alpha) << 24 | UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue)
        }

        // --- first pass: replicate the source pixel, interpolate the diagonal ---
        var wp = [2, 1, -1, 4, -1, 1]
        for y in stride(from: 0, to: dstHeight, by: 2) {
            for x in stride(from: 0, to: dstWidth, by: 2) {
                let cx = x >> 1, cy = y >> 1
                sample(src, width, cy, cx, height - 1, width - 1, lower: -1) {
                    sx, sy, by, bx in (sy + by, sx + bx)
                }
                let bounds = limits()
                let (ai, ri, gi, bi) = blend(diagonalEdge(lum, wp), w1, w2)
                let centre = src[cy * width + cx]
                dst[y * dstWidth + x] = centre
                dst[y * dstWidth + x + 1] = centre
                dst[(y + 1) * dstWidth + x] = centre
                dst[(y + 1) * dstWidth + x + 1] = pack(ai, ri, gi, bi, bounds)
            }
        }

        // --- second pass: the two remaining half-pixels, sampled diagonally ---
        wp = [2, 0, 0, 0, 0, 0]
        let yLimit = factor * height - 1
        let xLimit = factor * width - 1
        for y in stride(from: 0, to: dstHeight, by: 2) {
            for x in stride(from: 0, to: dstWidth, by: 2) {
                sample(dst, dstWidth, y, x, yLimit, xLimit, lower: -1) {
                    sx, sy, by, bx in (sx - sy + by, sx + sy + bx)
                }
                let bounds = limits()
                var (ai, ri, gi, bi) = blend(diagonalEdge(lum, wp), w3, w4)
                dst[y * dstWidth + x + 1] = pack(ai, ri, gi, bi, bounds)

                // The second half re-samples *after* the write above, so it can
                // see it. Upstream's behaviour, and why this is not vectorised.
                sample(dst, dstWidth, y, x, yLimit, xLimit, lower: -1) {
                    sx, sy, by, bx in (sx - sy + 1 + by, sx + sy - 1 + bx)
                }
                (ai, ri, gi, bi) = blend(diagonalEdge(lum, wp), w3, w4)
                dst[(y + 1) * dstWidth + x] = pack(ai, ri, gi, bi, bounds)
            }
        }

        // --- third pass: every pixel, in reverse raster order ---
        wp = [2, 1, -1, 4, -1, 1]
        for y in stride(from: dstHeight - 1, through: 0, by: -1) {
            for x in stride(from: dstWidth - 1, through: 0, by: -1) {
                // The window shifts to -2..1 here, so `a[sx + 2][sy + 2]`.
                sample(dst, dstWidth, y, x, yLimit, xLimit, lower: -2) {
                    sx, sy, by, bx in (sy + by, sx + bx)
                }
                let bounds = limits()
                let (ai, ri, gi, bi) = blend(diagonalEdge(lum, wp), w1, w2)
                dst[y * dstWidth + x] = pack(ai, ri, gi, bi, bounds)
            }
        }

        return (dst, dstWidth, dstHeight)
    }

    /// `scaleSuperXBR` — the driver that supports a non-integer factor.
    ///
    /// For our 3.125 this doubles twice — 64 rows to 128 to 256 — and then
    /// Lanczos *downsamples* to 200. `maxDoublings` caps the xBR passes and is
    /// **not** upstream; `nil` is upstream's schedule.
    static func scaleSuperXBR(
        _ pixels: [UInt32], _ width: Int, _ height: Int,
        _ factorX: Double, _ factorY: Double, maxDoublings: Int? = nil
    ) -> (pixels: [UInt32], width: Int, height: Int) {
        guard factorX > 0.0, factorY > 0.0 else { return (pixels, width, height) }

        var buffer = pixels
        var currentWidth = width
        var currentHeight = height
        let epsilonX = 1.0 / Double(width)
        let epsilonY = 1.0 / Double(height)
        var currentX = factorX
        var currentY = factorY
        var doublings = 0

        while abs(currentX - 1.0) > epsilonX || abs(currentY - 1.0) > epsilonY {
            if (currentX > 1.0 || currentY > 1.0)
                && (maxDoublings == nil || doublings < maxDoublings!) {
                (buffer, currentWidth, currentHeight) =
                    scaleSuperXBR2x(buffer, currentWidth, currentHeight)
                doublings += 1
                currentX /= 2.0
                currentY /= 2.0
            } else if maxDoublings != nil && doublings >= maxDoublings!
                        && (currentX != 1.0 || currentY != 1.0) {
                (buffer, currentWidth, currentHeight) = scaleLanczos(
                    buffer, currentWidth, currentHeight, currentX, currentY
                )
                currentX = 1.0
                currentY = 1.0
            } else if currentX < 1.0 && currentY < 1.0 {
                (buffer, currentWidth, currentHeight) = scaleLanczos(
                    buffer, currentWidth, currentHeight, currentX, currentY
                )
                // `curFactorX /= curFactorX` upstream, which means `= 1.0`.
                currentX = 1.0
                currentY = 1.0
            } else {
                break  // upstream would spin here; refuse to instead
            }
        }
        return (buffer, currentWidth, currentHeight)
    }
}
