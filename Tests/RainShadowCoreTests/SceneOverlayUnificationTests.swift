import Foundation
import Testing
@testable import RainShadowCore

/// The four full-screen windows are one surface, owned by `BaseGameScene`.
///
/// They were not. The office and the city each declared the same player node,
/// the same six HUD nodes, the same four flags and the same four setters, and
/// the copies had drifted: the city let you open a window mid-conversation,
/// never refreshed a bag that was already open, and reported itself non-modal
/// while dialogue held the screen. These are source-text assertions because the
/// property under test is that the *declaration* exists once — a behavioural
/// test would pass just as happily against two copies that happened to agree
/// today.
struct SceneOverlayUnificationTests {
    private static let scenePaths = [
        "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift",
        "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
    ]

    @Test func overlayStateIsDeclaredOnceOnTheSceneBase() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        for declaration in [
            "lazy var detective = DetectiveActorNode()",
            "static let detectiveActorID",
            "let portraitBar = PortraitBarNode()",
            "let actionBar = ActionBarNode()",
            "let inventoryOverlay = InventoryOverlay()",
            "lazy var areaMapOverlay = AreaMapOverlay(",
            "let worldMapOverlay = WorldMapOverlay()",
            "let journalOverlay = JournalOverlay()",
            "private(set) var inventoryIsPresented",
            "private(set) var mapIsPresented",
            "private(set) var worldMapIsPresented",
            "private(set) var journalIsPresented",
            "var anyOverlayIsPresented: Bool"
        ] {
            #expect(base.contains(declaration), "BaseGameScene should declare \(declaration)")
        }

        for path in Self.scenePaths {
            let scene = try read(path)
            for redeclaration in [
                "let detective = DetectiveActorNode()",
                "detectiveActorID = \"detective.voss\"",
                "portraitBar = PortraitBarNode()",
                "actionBar = ActionBarNode()",
                "inventoryOverlay = InventoryOverlay()",
                "worldMapOverlay = WorldMapOverlay()",
                "journalOverlay = JournalOverlay()",
                "var inventoryIsPresented",
                "var mapIsPresented",
                "var worldMapIsPresented",
                "var journalIsPresented",
                "var anyOverlayIsPresented"
            ] {
                #expect(!scene.contains(redeclaration), "\(path) still redeclares \(redeclaration)")
            }
        }
    }

    @Test func everySceneOpensAndClosesAWindowThroughOneTemplate() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")

        // The five steps, in order, and the three seams a scene may fill.
        #expect(base.contains("private func setOverlay("))
        #expect(base.contains("func willPresentOverlay(_ overlay: GameOverlay) {}"))
        #expect(base.contains("func clearHoverHighlight() {"))
        #expect(base.contains("refreshObjectHighlights()"))
        #expect(base.contains("func overlayPresentationDidChange()"))
        for setter in [
            "func setInventoryPresented(",
            "func setMapPresented(",
            "func setWorldMapPresented(",
            "func setJournalPresented("
        ] {
            #expect(base.contains(setter))
            for path in Self.scenePaths {
                let scene = try read(path)
                #expect(!scene.contains(setter), "\(path) still defines its own \(setter)")
            }
        }
    }

    /// A window never opens over a conversation. The city's copy of these three
    /// handlers omitted the dialogue guard, so I / M / J opened the bag on top of
    /// an open dialogue panel.
    @Test func aWindowNeverOpensWhileDialogueHoldsTheScreen() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")

        for handler in ["handleInventoryInput", "handleMapInput", "handleJournalInput"] {
            let start = try #require(base.range(of: "func \(handler)() {"))
            let end = try #require(base.range(of: "\n    }\n", range: start.upperBound..<base.endIndex))
            let body = base[start.upperBound..<end.lowerBound]
            #expect(body.contains("!dialogueIsActive"), "\(handler) should refuse to open over dialogue")
        }

        // Same reason, from the other direction: Space means Continue while the
        // panel is up, not pause. The city reported only its overlays here.
        #expect(base.contains("var isModalInputActive: Bool { dialogueIsActive || anyOverlayIsPresented }"))
        for path in Self.scenePaths {
            #expect(!(try read(path)).contains("var isModalInputActive"))
        }
    }

    /// Opening the bag from the portrait bar and then from the action bar has to
    /// redraw it, not return having done nothing — otherwise the wallet shown is
    /// whatever it was when the window first opened. Only the bag does this; the
    /// map and journal toggle shut instead.
    @Test func reopeningTheBagRedrawsItFromLiveSessionState() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")

        #expect(base.contains("refreshesWhenAlreadyPresented: Bool = false"))
        #expect(base.contains("setOverlay(.inventory, presented: presented, refreshesWhenAlreadyPresented: true)"))
        for other in [
            "setOverlay(.areaMap, presented: presented)",
            "setOverlay(.worldMap, presented: presented)",
            "setOverlay(.journal, presented: presented)"
        ] {
            #expect(base.contains(other))
        }
    }

    private func read(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
