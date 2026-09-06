import Foundation
import Testing
@testable import RainShadowCore

struct DialogueIntentionTests {
    @Test func taxonomyCoversGDDSevenPointFive() {
        let labels = Set(DialogueIntention.allCases.map(\.displayLabel))
        #expect(labels == ["Open", "Press", "Feign", "Trade", "Observe", "Leave"])
    }

    @Test func emptyCoatTriadsAuthorIntentions() {
        let graph = EmptyCoatCaseIntroduction.graph

        func intentions(on nodeID: String) -> [DialogueIntention?] {
            graph.node(id: nodeID)?.choices.map(\.intention) ?? []
        }

        #expect(intentions(on: "lila.entrance.case") == [.open, .open, .press])
        #expect(intentions(on: "lila.triad.police") == [.press, .observe, .feign])
        #expect(intentions(on: "lila.triad.key") == [.trade, .open, .feign, .press])

        for nodeID in ["lila.reply.good3.b", "lila.reply.neutral3.b", "lila.reply.cynical3.b", "lila.reply.press.gated"] {
            let choices = graph.node(id: nodeID)?.choices ?? []
            #expect(choices.count == 1)
            #expect(choices[0].intention == .trade)
        }
    }

    @Test func emptyCoatPressChoiceDoesNotPaintIntentionPrefix() {
        let key = EmptyCoatCaseIntroduction.graph.node(id: "lila.triad.key")
        let press = key?.choices.first { $0.intention == .press }
        #expect(press != nil)
        #expect(press?.intention == .press)
        #expect(press?.labeledBodyText.hasPrefix("[Press]") == false)
        #expect(press?.rowPrefixLabels.contains("Press") != true)
    }

    @Test func emptyCoatOpenChoiceDoesNotPaintOpenPrefix() {
        let entrance = EmptyCoatCaseIntroduction.graph.node(id: "lila.entrance.case")
        let open = entrance?.choices.first { $0.intention == .open }
        #expect(open?.intention == .open)
        #expect(open?.labeledBodyText.hasPrefix("[Open]") == false)
    }

    @Test func intentionDecodesFromAuthoredJSON() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "fixture.intention",
          "startNodeID": "n",
          "nodes": [
            {
              "id": "n",
              "speaker": "S",
              "text": "Well?",
              "choices": [
                { "text": "Go on.", "destinationID": "end", "intention": "open" },
                { "text": "Leave.", "destinationID": "end", "intention": "leave" }
              ]
            },
            { "id": "end", "speaker": "S", "text": "Done", "endsDialogue": true }
          ]
        }
        """
        let graph = try DialogueGraphLoader.decode(Data(json.utf8), stringTable: .empty)
        #expect(graph.node(id: "n")?.choices.map(\.intention) == [.open, .leave])
        #expect(graph.node(id: "n")?.choices[0].labeledBodyText == "Go on.")
        #expect(graph.node(id: "n")?.choices[1].labeledBodyText == "Leave.")
    }
}
