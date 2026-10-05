import CryptoKit
import Foundation
import Testing
@testable import RainShadowCore

struct CharacterRuntimeIdentityTests {
    /// The September package had the same VossCHMF name, frame count and palette
    /// layout. Those checks alone accepted the wrong model after a Git reset.
    @Test func aValidButDifferentPayloadCannotImpersonateCurrentCharacterArt() throws {
        let tables = try IEGradientTables.load()
        let validators: [(String, (IEIndexedSprite) throws -> Void)] =
            CharacterBodyCode.allCases.map { body in (body.character, { try body.validate($0) }) }
            + VossArmorAppearance.allCases.map { armor in (armor.character, { try armor.validate($0) }) }
        for (character, validate) in validators {
            let directory = IEGradientTables.developmentDirectory.appendingPathComponent("Avatars/\(character)")
            let manifestData = try Data(contentsOf: directory.appendingPathComponent("avatar-v02.json"))
            var manifest = try #require(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
            var indices = try Data(contentsOf: directory.appendingPathComponent("avatar-v02.indices"))
            var records = try #require(manifest["frames"] as? [[String: Any]])
            let first = try #require(records.firstIndex { ($0["length"] as? Int ?? 0) > 0 })
            let offset = try #require(records[first]["offset"] as? Int)
            let length = try #require(records[first]["length"] as? Int)
            let pixel = try #require((offset..<offset+length).first { indices[$0] >= 4 && indices[$0] < 87 })
            indices[pixel] += 1
            func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
            records[first]["sha256"] = hash(indices.subdata(in: offset..<offset+length))
            manifest["frames"] = records
            manifest["blob_sha256"] = hash(indices)
            let stale = try IEIndexedSprite(manifestData: JSONSerialization.data(withJSONObject: manifest),
                                            indicesData: indices, tables: tables)
            #expect(stale.character == character)
            #expect(throws: IEIndexedSpriteError.self) { try validate(stale) }
        }
    }
}
