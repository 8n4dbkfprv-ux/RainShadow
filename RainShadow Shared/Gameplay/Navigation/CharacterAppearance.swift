import Foundation

/// Stable appearance codes, independent of a creature's name, class or faction.
/// These aliases deliberately retain the current named bundle authorities.
enum CharacterBodyCode: String, Codable, CaseIterable, Sendable {
    case humanMale01 = "HUM-M-01"
    case humanFemale01 = "HUM-F-01"
    case bearGuardian = "BEAR-01"

    var character: String {
        switch self {
        case .humanMale01: VossAnimationSet.character
        case .humanFemale01: LilaAnimationSet.character
        case .bearGuardian: BearAnimationSet.character
        }
    }

    var atlas: String {
        switch self {
        case .humanMale01: VossAnimationSet.atlas
        case .humanFemale01: LilaAnimationSet.atlas
        case .bearGuardian: BearAnimationSet.atlas
        }
    }

    func validate(_ sprite: IEIndexedSprite) throws {
        switch self {
        case .humanMale01: try VossAnimationSet.validate(sprite)
        case .humanFemale01: try LilaAnimationSet.validate(sprite)
        case .bearGuardian: try BearAnimationSet.validate(sprite)
        }
    }

    func frameCount(for action: CharacterVisualAction, facing: ActorFacing) throws -> Int {
        if self == .bearGuardian { return try BearAnimationSet.frameCount(for: action) }
        switch action {
        case .idle: return self == .humanMale01 ? VossAnimationSet.idleFrames : LilaAnimationSet.idleFrames
        case .walk: return self == .humanMale01 ? VossAnimationSet.walkFrames : LilaAnimationSet.walkFrames
        case .seatedIdle, .standUp, .sitDown:
            guard self == .humanMale01, [.southWest, .northWest, .southEast, .north].contains(facing) else {
                throw CharacterAppearanceError.unsupportedAction(self, action)
            }
            return action == .seatedIdle ? VossAnimationSet.idleFrames : VossAnimationSet.transitionFrames
        case .attack, .hit, .die, .revert:
            throw CharacterAppearanceError.unsupportedAction(self, action)
        }
    }

    func frameName(action: CharacterVisualAction, facing: ActorFacing, phase: Int) throws -> String {
        let count = try frameCount(for: action, facing: facing)
        guard (0..<count).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        let direction = self == .humanFemale01 ? LilaAnimationSet.direction(facing) : VossAnimationSet.direction(facing)
        return String(format: "%@_%@_%02d.png", action.rawValue, direction, phase)
    }
}

enum CharacterVisualAction: String, Codable, Sendable {
    case idle, walk, attack, hit, die
    case seatedIdle = "seated_idle"
    case revert
    case standUp = "stand_up"
    case sitDown = "sit_down"
}

/// Named, optional material overrides. UInt8 decoding rejects out-of-range rows.
/// Unspecified regions retain the selected body's (or equipment's) authored row.
struct CharacterColors: Codable, Hashable, Sendable {
    var metal: UInt8? = nil
    var minor: UInt8? = nil
    var major: UInt8? = nil
    var skin: UInt8? = nil
    var leather: UInt8? = nil
    var armor: UInt8? = nil
    var hair: UInt8? = nil

    func applying(to authored: [UInt32]) -> [UInt32] {
        precondition(authored.count == IEMaterialSlot.allCases.count)
        return zip([metal, minor, major, skin, leather, armor, hair], authored).map {
            $0.0.map(UInt32.init) ?? $0.1
        }
    }
}

enum CharacterPaletteCode: String, Codable, CaseIterable, Sendable {
    case authored = "PAL-AUTHORED"
    case guardUniform = "PAL-GUARD-01"
    case banditClothes = "PAL-BANDIT-01"

    var colors: CharacterColors {
        switch self {
        case .authored: .init()
        case .guardUniform: .init(minor: 46, major: 63)
        case .banditClothes: .init(minor: 49, major: 59)
        }
    }
}

enum CharacterEquipmentCode: String, Codable, CaseIterable, Sendable {
    case ironHelmet = "iron-helmet"
    case splintMail = "splint-mail"
    case lanternShortsword = "lantern-shortsword"
    case elvenCourtBow = "elven-court-bow"
    case elvenCourtArrow = "elven-court-arrow"

    var character: String {
        switch self {
        case .ironHelmet: VossArmorAppearance.ironHelmet.character
        case .splintMail: VossArmorAppearance.splintMail.character
        case .lanternShortsword: VossWeaponAppearance.lanternShortsword.character
        case .elvenCourtBow: VossWeaponAppearance.elvenCourtBow.character
        case .elvenCourtArrow: VossAmmunitionAppearance.elvenCourtArrow.character
        }
    }
    var atlas: String { character + ".atlas" }
    var layerOrder: Int {
        switch self {
        case .lanternShortsword, .elvenCourtBow, .elvenCourtArrow: 1
        case .splintMail: 2
        case .ironHelmet: 3
        }
    }
    func supports(body: CharacterBodyCode) -> Bool { body == .humanMale01 }
    func supports(action: CharacterVisualAction) -> Bool { action == .idle || action == .walk }
    func validate(_ sprite: IEIndexedSprite) throws {
        switch self {
        case .ironHelmet: try VossArmorAppearance.ironHelmet.validate(sprite)
        case .splintMail: try VossArmorAppearance.splintMail.validate(sprite)
        case .lanternShortsword: try VossWeaponAppearance.lanternShortsword.validate(sprite)
        case .elvenCourtBow: try VossWeaponAppearance.elvenCourtBow.validate(sprite)
        case .elvenCourtArrow: try VossAmmunitionAppearance.elvenCourtArrow.validate(sprite)
        }
    }
}

struct CharacterEquipmentAppearance: Codable, Equatable, Sendable {
    let item: CharacterEquipmentCode
    var colors: CharacterColors? = nil
}

struct CharacterAppearance: Codable, Equatable, Sendable {
    var body: CharacterBodyCode
    var palette: CharacterPaletteCode = .authored
    var colors: CharacterColors? = nil
    var equipment: [CharacterEquipmentAppearance] = []

    func bodyColors(authored: [UInt32]) -> [UInt32] {
        let base = palette.colors.applying(to: authored)
        return colors?.applying(to: base) ?? base
    }

    func validate() throws {
        var used = Set<CharacterEquipmentCode>()
        for layer in equipment {
            guard layer.item.supports(body: body) else {
                throw CharacterAppearanceError.incompatibleEquipment(body, layer.item)
            }
            guard used.insert(layer.item).inserted else {
                throw CharacterAppearanceError.duplicateEquipment(layer.item)
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case body, palette, colors, equipment }
    init(body: CharacterBodyCode, palette: CharacterPaletteCode = .authored,
         colors: CharacterColors? = nil, equipment: [CharacterEquipmentAppearance] = []) {
        self.body = body; self.palette = palette; self.colors = colors; self.equipment = equipment
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        body = try container.decode(CharacterBodyCode.self, forKey: .body)
        palette = try container.decodeIfPresent(CharacterPaletteCode.self, forKey: .palette) ?? .authored
        colors = try container.decodeIfPresent(CharacterColors.self, forKey: .colors)
        equipment = try container.decodeIfPresent([CharacterEquipmentAppearance].self, forKey: .equipment) ?? []
        try validate()
    }
}

/// Class/faction IDs are content identifiers, not visual selectors or combat rules.
/// Hostility is intentionally left to the gameplay relationship system.
struct CharacterDefinition: Codable, Equatable, Sendable {
    var id: String
    var classID: String?
    var factionID: String?
    var appearance: CharacterAppearance

    enum CodingKeys: String, CodingKey {
        case id, appearance
        case classID = "class"
        case factionID = "faction"
    }

    static let voss = CharacterDefinition(id: "voss", classID: nil, factionID: nil,
        appearance: .init(body: .humanMale01))
    static let lila = CharacterDefinition(id: "lila", classID: nil, factionID: nil,
        appearance: .init(body: .humanFemale01))
    static let cityGuard = CharacterDefinition(id: "city-guard", classID: "fighter", factionID: "city-watch",
        appearance: .init(body: .humanMale01, palette: .guardUniform, equipment: [
            .init(item: .ironHelmet), .init(item: .splintMail), .init(item: .lanternShortsword)
        ]))
    static let bandit = CharacterDefinition(id: "bandit", classID: "fighter", factionID: "bandits",
        appearance: .init(body: .humanMale01, palette: .banditClothes,
                          equipment: [.init(item: .lanternShortsword)]))
    static let civilian = CharacterDefinition(id: "civilian", classID: nil, factionID: "civilians",
        appearance: .init(body: .humanFemale01, palette: .guardUniform))
}

enum CharacterAppearanceError: Error, Equatable {
    case incompatibleEquipment(CharacterBodyCode, CharacterEquipmentCode)
    case duplicateEquipment(CharacterEquipmentCode)
    case unsupportedAction(CharacterBodyCode, CharacterVisualAction)
    case invalidPhase(Int)
    case missingFrame(String, String)
}
