import Foundation

/// The engine's seven material slots (GemRB `core/CharAnimations.cpp`,
/// `SetupPaperdollColours`'s `enum PALETTES`).
///
/// The order is not free to change: it is the order the seven 12-shade runs are
/// written into the palette, and it is also the order of a creature's `colors[]`
/// array in the CRE file.
enum IEMaterialSlot: Int, CaseIterable, Sendable {
    case metal = 0
    case minor
    case major
    case skin
    case leather
    case armor
    case hair

    /// `0x04 + idx * 12` — where this slot's run of shades begins.
    var paletteOffset: Int { 0x04 + rawValue * IEPaperdollColours.numCols }
}

/// `Palette SetupPaperdollColours(const ieDword* colors, unsigned int type)`
/// (GemRB `core/CharAnimations.cpp`).
///
/// This is the whole of how the Infinity Engine colours a character. Seven
/// gradient indices become seven 12-shade runs at `0x04 + idx * 12`, a set of
/// 8-colour aliases lets one gradient serve several BAM index ranges, and index
/// 1 is set to black for the shadow. There is no clustering, no median cut and
/// no per-clip fitting anywhere in it — the palette belongs to the avatar, so
/// no frame of an animation can drift off it by construction.
///
/// GemRB carries an open question about the `0x04`:
///
/// ```cpp
/// // FIXME: is this 0x04 an error? sizeof Color is 4, so that only skips the
/// // transparency color the shadow color we manually reset below, but doesn't
/// // this offset all the palettes by 1 slot?
/// ```
///
/// It is not an error, and `ArtSource/Processing/qa_ie_palette_port.py` check 2
/// settles it from shipped data: BG:EE's creature BAMs carry a false-colour
/// marker palette — one saturated ramp per slot — and its runs sit at exactly
/// `0x04`, `0x10`, `0x1c`, `0x28`, `0x34`, `0x40`, `0x4c`, ending at `0x57`
/// where the alias region begins. The FIXME is kept above because a port
/// records upstream as written; the answer lives in the QA tool.
enum IEPaperdollColours {
    /// `constexpr uint8_t numCols = 12;`
    static let numCols = 12

    /// `Palette SetupPaperdollColours(const ieDword* colors, unsigned int type)`.
    ///
    /// - Parameters:
    ///   - colors: seven gradient indices, in ``IEMaterialSlot`` order.
    ///   - type: which byte of each colour dword to read. `Clamp`ed to a shift
    ///     of at most 31, as upstream does.
    static func setup(
        colors: [UInt32],
        type: Int = 0,
        tables: IEGradientTables
    ) -> IEPalette {
        precondition(colors.count >= IEMaterialSlot.allCases.count, "need seven gradient indices")

        // `unsigned int s = Clamp<ieDword>(8 * type, 0, 8 * sizeof(ieDword) - 1);`
        let s = min(max(8 * type, 0), 8 * MemoryLayout<UInt32>.size - 1)
        var buffer = Array(repeating: IEColor.transparentBlack, count: 256)

        for slot in IEMaterialSlot.allCases {
            // `core->GetPalette16(colors[idx] >> s)` — the parameter is a
            // uint8_t, so the shifted dword truncates to its low byte.
            let index = Int((colors[slot.rawValue] >> UInt32(s)) & 0xFF)
            let run = tables.palette16(index)
            let start = slot.paletteOffset
            buffer.replaceSubrange(start..<(start + numCols), with: run.prefix(numCols))
        }

        /// `memcpy(&buffer[dest], &buffer[src], 8 * sizeof(Color));`
        func alias(_ destination: Int, _ source: Int) {
            let run = Array(buffer[source..<(source + 8)])
            buffer.replaceSubrange(destination..<(destination + 8), with: run)
        }

        alias(0x58, 0x11) // minor
        alias(0x60, 0x1D) // major
        alias(0x68, 0x11) // minor
        alias(0x70, 0x05) // metal
        alias(0x78, 0x35) // leather
        alias(0x80, 0x35) // leather
        alias(0x88, 0x11) // minor

        for i in stride(from: 0x90, to: 0xA8, by: 0x08) {
            alias(i, 0x35) // leather
        }

        alias(0xB0, 0x29) // skin

        // `for (int i = 0xB8; i < 0xFF; i += 0x08)` — the bound is 0xFF, not
        // 0x100, so the last run starts at 0xF8 and still fills through 0xFF.
        for i in stride(from: 0xB8, to: 0xFF, by: 0x08) {
            alias(i, 0x35) // leather
        }

        // shadows, will be half-trans'ed when required
        buffer[IEPalette.shadowIndex] = IEColor(0, 0, 0, 255)

        var palette = IEPalette()
        palette.copyColors(buffer)
        return palette
    }
}
