import Foundation

/// Fixed north-east facade ladder, with both hands free. Descending reverses
/// the same connected-limb cycle; the approved walking bundles stay unchanged.
enum ClimbAnimationSet {
    static let frames = 16
    static let hashes = [
        "HumanClimb": "a6eefd9a46390044b8a1642645b327797d229c7c5c36eebc32d5ffe1683fec5a",
        "HumanClimbMail": "6e333fd6dbd666ce9350e6ae92f8601f9d5af8ebeb184072a0ea4a3eee9aa05a",
        "HumanClimbHelmet": "e8331f59a8574ce451e9d90ba6bc727f6f003811c69d8b56c611658eeba38f80"
    ]
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed ladder animation")
        }
    }
}
