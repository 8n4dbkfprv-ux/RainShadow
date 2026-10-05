import Foundation
import Testing
@testable import RainShadowCore

struct CharacterAppearanceTests {
    @Test func characterRecordsRoundTripAndDoNotTieClassToBody() throws {
        let json = #"{"id":"guard-014","class":"fighter","faction":"city-watch","appearance":{"body":"HUM-M-01","palette":"PAL-GUARD-01","colors":{"hair":1},"equipment":[{"item":"splint-mail"}]}}"#
        var record = try JSONDecoder().decode(CharacterDefinition.self, from: Data(json.utf8))
        let appearance = record.appearance
        record.classID = "thief"
        record.factionID = "bandits"
        #expect(record.appearance == appearance)
        #expect(try JSONDecoder().decode(CharacterDefinition.self, from: JSONEncoder().encode(record)) == record)
        let minimal = try JSONDecoder().decode(CharacterDefinition.self,
            from: Data(#"{"id":"lila-copy","appearance":{"body":"HUM-F-01"}}"#.utf8))
        #expect(minimal.appearance == CharacterDefinition.lila.appearance)
        #expect(minimal.classID == nil && minimal.factionID == nil)
    }

    @Test func invalidCodesColorsAndEquipmentFailAtTheContentBoundary() throws {
        for json in [
            #"{"body":"unknown"}"#,
            #"{"body":"HUM-M-01","palette":"unknown"}"#,
            #"{"body":"HUM-M-01","colors":{"skin":256}}"#,
            #"{"body":"HUM-M-01","colors":{"major":-1}}"#,
            #"{"body":"HUM-F-01","equipment":[{"item":"splint-mail"}]}"#,
            #"{"body":"HUM-M-01","equipment":[{"item":"iron-helmet"},{"item":"iron-helmet"}]}"#
        ] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(CharacterAppearance.self, from: Data(json.utf8))
            }
        }
    }

    @Test func currentAuthoritiesAndDefaultsArePreserved() throws {
        for definition in [CharacterDefinition.voss, .lila] {
            let appearance = definition.appearance
            let sprite = try IEIndexedSprite.load(character: appearance.body.character)
            try appearance.body.validate(sprite)
            #expect(appearance.bodyColors(authored: sprite.colors) == sprite.colors)
            for facing in ActorFacing.allCases {
                for action in [CharacterVisualAction.idle, .walk] {
                    let count = try appearance.body.frameCount(for: action, facing: facing)
                    for phase in 0..<count {
                        let name = try appearance.body.frameName(action: action, facing: facing, phase: phase)
                        #expect(sprite.frame(atlas: appearance.body.atlas, name: name) != nil)
                    }
                }
            }
        }
        #expect(CharacterBodyCode.humanMale01.character == "VossCHMF")
        #expect(CharacterBodyCode.humanFemale01.character == "LilaSentinel")
    }

    @Test func palettesChangeOnlyTheirMaterialsAndNeverMoveTheSilhouette() throws {
        for body in CharacterBodyCode.allCases {
            let sprite = try IEIndexedSprite.load(character: body.character)
            let appearance = CharacterAppearance(body: body, palette: .guardUniform, colors: .init(hair: 1))
            let colors = appearance.bodyColors(authored: sprite.colors)
            #expect(colors[3] == sprite.colors[3])
            #expect(colors[6] == 1)
            var changed = 0
            for facing in ActorFacing.allCases {
                let name = try body.frameName(action: .walk, facing: facing, phase: 0)
                let frame = try #require(sprite.frame(atlas: body.atlas, name: name))
                let before = sprite.rgba(for: frame)
                let after = sprite.rgba(for: frame, colors: colors)
                for (i, index) in frame.indices.enumerated() {
                    #expect(before[i * 4 + 3] == after[i * 4 + 3])
                    let materials = sprite.paletteLayout.materials(for: index)
                    if materials.allSatisfy({ ![IEMaterialSlot.minor, .major, .hair].contains($0) }) {
                        #expect(Array(before[i*4..<i*4+4]) == Array(after[i*4..<i*4+4]))
                    }
                }
                if before != after { changed += 1 }
            }
            #expect(changed == 16)
        }
    }

    @Test func equipmentMatchesBodyFramesAndHasItsOwnColors() throws {
        let definition = CharacterDefinition.cityGuard
        try definition.appearance.validate()
        for layer in definition.appearance.equipment {
            let sprite = try IEIndexedSprite.load(character: layer.item.character)
            try layer.item.validate(sprite)
            #expect(layer.colors == nil)
            for facing in ActorFacing.allCases {
                let name = try definition.appearance.body.frameName(action: .walk, facing: facing, phase: 9)
                #expect(sprite.frame(atlas: layer.item.atlas, name: name) != nil)
            }
            #expect(!layer.item.supports(action: .seatedIdle))
            #expect(!layer.item.supports(body: .humanFemale01))
        }
    }

    @Test func missingAnimationCannotSilentlyFallBackToIdleOrAnotherBody() throws {
        for body in CharacterBodyCode.allCases {
            for action in [CharacterVisualAction.attack, .hit, .die] {
                #expect(throws: CharacterAppearanceError.unsupportedAction(body, action)) {
                    try body.frameCount(for: action, facing: .south)
                }
            }
            #expect(throws: CharacterAppearanceError.invalidPhase(10)) {
                try body.frameName(action: .walk, facing: .south, phase: 10)
            }
        }
        #expect(throws: (any Error).self) {
            try CharacterBodyCode.humanFemale01.frameCount(for: .seatedIdle, facing: .southWest)
        }
        #expect(try CharacterBodyCode.humanMale01.frameCount(for: .seatedIdle, facing: .northWest) == 65)
    }
}
