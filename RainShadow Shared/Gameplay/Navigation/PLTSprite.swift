import Foundation

enum PLTError: Error, CustomStringConvertible {
    case badSignature
    case truncated(expected: Int, got: Int)

    var description: String {
        switch self {
        case .badSignature: return "not a PLT V1 file"
        case let .truncated(expected, got): return "PLT pixel plane is \(got) bytes, expected \(expected)"
        }
    }
}

/// A paperdoll image in the engine's own encoding (GemRB
/// `plugins/PLTImporter/PLTImporter.cpp`).
///
/// PLT is the closest thing the Infinity Engine has to the *output* of a
/// pre-render pipeline: a figure stored not as colour but as two bytes per
/// pixel — an **intensity** and a **material-range index**. Colour arrives only
/// at draw time, when the range picks a gradient and the intensity picks a
/// shade along it. That is why an IE paperdoll can be recoloured without
/// touching the art, and it is the model this project's character bake now
/// follows instead of quantising finished RGB.
struct PLTSprite: Sendable {
    /// `if (memcmp(Signature, "PLT V1  ", 8) != 0)`
    static let signature = Array("PLT V1  ".utf8)

    /// `static int pperm[8] = { 3, 6, 0, 5, 4, 1, 2, 7 };`
    ///
    /// The eight range slots are not stored in the order a creature's colour
    /// array holds them; this permutation is the mapping, and it is data, not a
    /// derivation.
    static let pperm = [3, 6, 0, 5, 4, 1, 2, 7]

    let width: Int
    let height: Int
    /// `Width * Height * 2` bytes, `(intensity, palette index)` per pixel,
    /// stored bottom-up exactly as the file holds them.
    let plane: [UInt8]

    /// `PLTImporter::Import` — 8-byte signature, 8 unknown bytes, then the
    /// dimensions and the pixel plane.
    init(data: Data) throws {
        guard data.count >= 24, Array(data.prefix(8)) == Self.signature else {
            throw PLTError.badSignature
        }
        let bytes = [UInt8](data)
        func dword(_ offset: Int) -> Int {
            Int(UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24)
        }
        width = dword(16)
        height = dword(20)

        let expected = width * height * 2
        guard bytes.count - 24 >= expected else {
            throw PLTError.truncated(expected: expected, got: bytes.count - 24)
        }
        plane = Array(bytes[24..<(24 + expected)])
    }

    /// `Holder<Sprite2D> PLTImporter::GetSprite2D(unsigned int type, ieDword paletteIndex[8])`.
    ///
    /// ```cpp
    /// static int pperm[8] = { 3, 6, 0, 5, 4, 1, 2, 7 };
    /// ColorPal<256> Palettes[8];
    /// for (int i = 0; i < 8; i++) {
    ///     Palettes[i] = core->GetPalette256(paletteIndex[pperm[i]] >> (8 * type));
    /// }
    /// ...
    /// for (int y = Height - 1; y >= 0; y--) {
    ///     src = (unsigned char*) pixels + (y * Width * 2);
    ///     for (unsigned int x = 0; x < Width; x++) {
    ///         unsigned char intensity = *src++;
    ///         unsigned char palindex = *src++;
    ///         *dest++ = Palettes[palindex][intensity].b;
    ///         *dest++ = Palettes[palindex][intensity].g;
    ///         *dest++ = Palettes[palindex][intensity].r;
    ///         if (intensity == 0xff)
    ///             *dest++ = 0x00;
    ///         else
    ///             *dest++ = 0xff;
    ///     }
    /// }
    /// ```
    ///
    /// Two things upstream does that are easy to lose. The row walk counts
    /// **down**, because PLT stores rows bottom-up; and transparency is decided
    /// by intensity alone (`0xff`), not by a mask or an alpha channel — there
    /// isn't one to consult.
    ///
    /// Returns top-down RGBA, which is what every consumer here wants; GemRB
    /// writes BGR into a buffer it then describes with channel masks, and the
    /// net result is the same pixel.
    func rgba(paletteIndex: [UInt32], type: Int = 0, tables: IEGradientTables) -> [UInt8] {
        precondition(paletteIndex.count >= 8, "PLT needs eight range indices")

        let palettes: [[IEColor]] = (0..<8).map { i in
            Array(tables.palette256(Int((paletteIndex[Self.pperm[i]] >> UInt32(8 * type)) & 0xFF)))
        }

        var destination = [UInt8](repeating: 0, count: width * height * 4)
        var cursor = 0
        for y in stride(from: height - 1, through: 0, by: -1) {
            var source = y * width * 2
            for _ in 0..<width {
                let intensity = Int(plane[source])
                // GemRB indexes an eight-element array with this byte unguarded;
                // a malformed file would read past it. Masking is the one place
                // this port declines to reproduce upstream, because in Swift the
                // alternative is a trap rather than stray memory.
                let palindex = Int(plane[source + 1]) & 0x07
                source += 2

                let color = palettes[palindex][intensity]
                destination[cursor] = color.r
                destination[cursor + 1] = color.g
                destination[cursor + 2] = color.b
                destination[cursor + 3] = intensity == 0xFF ? 0x00 : 0xFF
                cursor += 4
            }
        }
        return destination
    }
}
