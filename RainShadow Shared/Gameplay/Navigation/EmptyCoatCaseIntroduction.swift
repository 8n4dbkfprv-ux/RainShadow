import Foundation

/// Shipped **Empty Coat** office case-intro graph: Voss noir monologue → Lila March triad dialogue.
///
/// Portrait asset filenames keep retired working-name IDs until a later art migration.
/// On-screen speaker strings are GDD canon: Harlan Voss / Lila March.
///
/// Long beats are split across **Continue** pages so each panel fits the dialogue well
/// without stacking multi-paragraph prose against triad choices.
///
/// **Classic Baldur’s Gate / Infinity Engine roles (frozen — GDD §7.5):**
/// - NPC speech = node body; multi-page NPC beats may use `nextNodeID` / Continue.
/// - PC (Voss) speech during the conversation = `CaseDialogueChoice` text the player selects
///   (even a single option). Do **not** reintroduce mid-convo Voss speaker nodes with empty
///   choices + `nextNodeID` (former `voss.accept` anti-pattern).
/// - Exception: pre-Lila `voss.monologue.*` interior monologue may be Continue-only.
enum EmptyCoatCaseIntroduction {
    static let startNodeID = "voss.monologue.1"
    static let caseOpenedNodeID = "case.opened"
    /// First spoken Lila beat after the monologue chain.
    static let lilaConversationStartNodeID = "lila.entrance"

    /// Late monologue beat that narratively introduces arrival (hallway / heels).
    /// Baldur’s Gate style: the player reads this page fully, then Continue starts the
    /// door-fall / client entrance cinematic with **no** dialogue panel; dialogue
    /// resumes on the next monologue page after the walk.
    static let clientEntranceCueNodeID = "voss.monologue.4"

    /// Shipped Grok Voice openers (full monologue + Lila graph use per-node `voiceAssetName`).
    static let monologueOpenerVoiceAsset = "vo_voss_monologue_1.m4a"
    static let lilaEntranceVoiceAsset = "vo_lila_entrance.m4a"

    /// Baseline of the short pre-rewrite graph (8 nodes). New content must exceed this floor.
    static let legacyNodeCountFloor = 8
    /// Baseline body-character total of the short pre-rewrite graph (~450). New prose must clear this.
    static let legacyBodyCharacterFloor = 450

    static let vossSpeaker = "Harlan Voss"
    static let lilaSpeaker = "Lila March"
    static let caseOpenedSpeaker = "Case opened"

    /// Portrait masters still use retired pipeline names.
    static let vossPortrait = "dialogue_portrait_harlan_voss_v01"
    static let lilaPortrait = "dialogue_portrait_lila_march_v02"

    /// The exact node list the office scene presents. Tests must call this same source.
    static var nodes: [CaseDialogueNode] {
        monologueNodes + lilaConversationNodes + closingNodes
    }

    /// Entrance is **not** armed on show — the cue page must remain fully readable.
    static func shouldStartClientEntrance(whenShowing nodeID: String) -> Bool {
        false
    }

    /// Whether Continue *from* this node should start the entrance cinematic (BG cutscene).
    /// Only the authored late-monologue cue; early monologue pages and Lila speech do not.
    static func shouldStartClientEntrance(whenLeaving nodeID: String) -> Bool {
        nodeID == clientEntranceCueNodeID
    }

    /// Voice-over resource for a node, read from the shipped graph (nil when silent).
    static func voiceAssetName(for nodeID: String) -> String? {
        nodes.first(where: { $0.id == nodeID })?.voiceAssetName
    }

    /// Grok Voice bundle filename for a dialogue node id (`voss.monologue.1` → `vo_voss_monologue_1.m4a`).
    static func bundledVoiceFileName(for nodeID: String) -> String {
        "vo_\(nodeID.replacingOccurrences(of: ".", with: "_")).m4a"
    }


    // MARK: - Noir monologue (what is about to happen)

    private static var monologueNodes: [CaseDialogueNode] {
        [
            CaseDialogueNode(
                id: "voss.monologue.1",
                speaker: vossSpeaker,
                text: """
                Rain had been working Harborpoint like a debt collector—steady, patient, and not interested in excuses. It erased footsteps on Sable Row, turned the streetlamps into wet coins, and made every window look like someone else's bad decision.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.monologue.2",
                isInteriorMonologue: true,
                voiceAssetName: "vo_voss_monologue_1.m4a"
            ),
            CaseDialogueNode(
                id: "voss.monologue.2",
                speaker: vossSpeaker,
                text: """
                I sat with a cold mug and three unpaid notices that had learned my name better than any client ever had. The phone stayed quiet. That should have been a blessing. In this city, quiet is usually just the moment before somebody kicks your door in with a story.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.monologue.3",
                isInteriorMonologue: true,
                voiceAssetName: "vo_voss_monologue_2.m4a"
            ),
            CaseDialogueNode(
                id: "voss.monologue.3",
                speaker: vossSpeaker,
                text: """
                You learn the soundtrack after a while: radiator ticks, pipes arguing in the walls, rain rehearsing the same confession on the glass. Outside, Harborpoint kept its books in two ledgers—one for the papers, one for the men who never get wet.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.monologue.4",
                isInteriorMonologue: true,
                voiceAssetName: "vo_voss_monologue_3.m4a"
            ),
            CaseDialogueNode(
                id: "voss.monologue.4",
                speaker: vossSpeaker,
                text: """
                I told myself I was done with missing persons. Missing persons find you when the rent is late. Missing persons arrive with perfume, a half-truth, and a problem that already has a municipal stamp on it.

                Then the hallway breathed. Heels on tired boards. A pause outside like someone counting the cost of coming in.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.monologue.5",
                isInteriorMonologue: true,
                voiceAssetName: "vo_voss_monologue_4.m4a"
            ),
            CaseDialogueNode(
                id: "voss.monologue.5",
                speaker: vossSpeaker,
                text: """
                That was the shape of what was about to happen: a dame out of the rain, a case that smelled like river water and official patience, and me—broke enough to listen, stubborn enough to keep listening after I should have stopped.

                The door would open. The coat would come up. And once a coat has no body left inside it, every answer is the kind that costs.
                """,
                portraitName: vossPortrait,
                nextNodeID: "lila.entrance",
                isInteriorMonologue: true,
                voiceAssetName: "vo_voss_monologue_5.m4a"
            )
        ]
    }

    // MARK: - Lila conversation (triad choices; long beats use Continue)

    /// Classic BG transition: PC acceptance as selectable reply text (not a speaker-state Continue page).
    /// Destination reconverges all triad-3 paths onto Lila's plea, then case opened.
    private static let caseAcceptanceChoice = CaseDialogueChoice(
        text: """
        All right, Miss March. The key stays on this desk until it opens something that can answer back. Harborpoint likes endings that fit in a paper bag. We're going to give it a longer sentence. If the river has Lillian, I'll make it say so in a language the police can't file under "finished." If it doesn't, somebody in a dry office is about to learn what wet shoes sound like in a hallway.
        """,
        destinationID: "lila.plea"
    )

    private static var lilaConversationNodes: [CaseDialogueNode] {
        [
            // Entrance — page 1 (matches the long panel that was overflowing).
            CaseDialogueNode(
                id: "lila.entrance",
                speaker: lilaSpeaker,
                text: """
                Mr. Voss? Forgive the hour. The rain made a liar of my schedule—and of everyone who told me to wait until morning.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.entrance.case",
                voiceAssetName: "vo_lila_entrance.m4a"
            ),
            CaseDialogueNode(
                id: "lila.entrance.case",
                speaker: lilaSpeaker,
                text: """
                My sister Lillian vanished Tuesday night. Not "went away." Not "took a room by the docks." Vanished. The kind of gone that leaves the apartment lights still on and the kettle still warm enough to insult you.
                """,
                portraitName: lilaPortrait,
                choices: [
                    CaseDialogueChoice(
                        text: "Come in out of the wet. Tell me everything you know, and I'll treat it like it matters—because it does.",
                        destinationID: "lila.reply.good1",
                        tone: .goodHeroic
                    ),
                    CaseDialogueChoice(
                        text: "Sit down. Start with Tuesday night: last place, last call, last person who saw her breathing.",
                        destinationID: "lila.reply.neutral1",
                        tone: .neutralPragmatic
                    ),
                    CaseDialogueChoice(
                        text: "Vanished is a word people buy when 'ran off' won't pay the detective. Convince me this isn't a family argument with a taxi receipt.",
                        destinationID: "lila.reply.cynical1",
                        tone: .cynicalSarcasm,
                        // P1: hard push unlocks a later Press option on the key triad.
                        grantsConversationFlags: [EmptyCoatDialogueKeys.pressedHardOnStory]
                    )
                ],
                voiceAssetName: "vo_lila_entrance_case.m4a"
            ),

            CaseDialogueNode(
                id: "lila.reply.good1",
                speaker: lilaSpeaker,
                text: """
                Thank you. Most men in this city offer umbrellas or excuses. You offered a chair and a spine.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.good1.b",
                voiceAssetName: "vo_lila_reply_good1.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.good1.b",
                speaker: lilaSpeaker,
                text: """
                Lillian worked late at the shipping office near Wharf Ladder—ledgers, manifests, the dull ink that keeps cargo honest until it isn't. She never missed a tram. She never left a kettle half-boiled. Tuesday she left work at nine. By midnight, her coat was the only thing the river was willing to return.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.police.story",
                voiceAssetName: "vo_lila_reply_good1_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral1",
                speaker: lilaSpeaker,
                text: """
                Good. Facts first—I can cry later if the rain leaves me any privacy.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.neutral1.b",
                voiceAssetName: "vo_lila_reply_neutral1.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral1.b",
                speaker: lilaSpeaker,
                text: """
                Last confirmed: Wharf Ladder shipping office, Tuesday, nine o'clock. She told a clerk she had one more errand uptown. No name for the errand. No cab called from the desk phone. Midnight, the river watch found her coat on the stones below the old iron stairs—empty, arranged, and too convenient for anyone who likes tidy endings.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.police.story",
                voiceAssetName: "vo_lila_reply_neutral1_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical1",
                speaker: lilaSpeaker,
                text: """
                If this were a taxi receipt, Mr. Voss, I would have spent my money on a better coat and a worse conscience.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.cynical1.b",
                voiceAssetName: "vo_lila_reply_cynical1.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical1.b",
                speaker: lilaSpeaker,
                text: """
                Lillian hated the river. She hated unfinished books more. The police found her coat and called it an answer. I call it a prop. Someone wanted the search to end at the waterline—and they almost got their wish, until I put my hands in the lining.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.police.story",
                voiceAssetName: "vo_lila_reply_cynical1_b.m4a"
            ),

            CaseDialogueNode(
                id: "lila.police.story",
                speaker: lilaSpeaker,
                text: """
                Harborpoint PD filed it soft: missing adult, no signs of struggle, coat recovered, probable drowning, case cooling before the ink dried. They were polite. Polite is how this city closes a door without slamming it.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.police.story.b",
                voiceAssetName: "vo_lila_police_story.m4a"
            ),
            CaseDialogueNode(
                id: "lila.police.story.b",
                speaker: lilaSpeaker,
                text: """
                I asked for the night sergeant's notes. He offered coffee and a speech about tides. I asked who benefited if Lillian stopped reading manifests. That was when the politeness developed teeth.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.triad.police",
                voiceAssetName: "vo_lila_police_story_b.m4a"
            ),

            CaseDialogueNode(
                id: "lila.triad.police",
                speaker: lilaSpeaker,
                text: """
                So here is the fork in the road, Mr. Voss. The police have a coat. I have a sister. You have an office that smells like rain and unpaid courage.

                What do you do with a city that would rather be finished than right?
                """,
                portraitName: lilaPortrait,
                choices: [
                    CaseDialogueChoice(
                        text: "I dig until the truth has nowhere left to hide—even if it embarrasses men with badges and better coats.",
                        destinationID: "lila.reply.good2",
                        tone: .goodHeroic
                    ),
                    CaseDialogueChoice(
                        text: "I pull the file they won't show you, re-check the river stones, and find the gap between their story and the weather.",
                        destinationID: "lila.reply.neutral2",
                        tone: .neutralPragmatic
                    ),
                    CaseDialogueChoice(
                        text: "I bill by the hour and assume every official sentence is missing a clause written in someone else's ink.",
                        destinationID: "lila.reply.cynical2",
                        tone: .cynicalSarcasm
                    )
                ],
                voiceAssetName: "vo_lila_triad_police.m4a"
            ),

            CaseDialogueNode(
                id: "lila.reply.good2",
                speaker: lilaSpeaker,
                text: """
                Then we understand each other. Lillian used to say courage was just stubbornness with better lighting. Tonight I'll take either.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.good2.b",
                voiceAssetName: "vo_lila_reply_good2.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.good2.b",
                speaker: lilaSpeaker,
                text: """
                There's more. The coat wasn't only empty—it was prepared. The pockets were turned like someone wanted the world to see there was nothing left to steal. Except there was.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.key.reveal",
                voiceAssetName: "vo_lila_reply_good2_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral2",
                speaker: lilaSpeaker,
                text: """
                That's the work I came to buy: not speeches, measurements. The river stones, the duty roster, the shipping office clock that runs three minutes fast when the night crew wants an alibi.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.neutral2.b",
                voiceAssetName: "vo_lila_reply_neutral2.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral2.b",
                speaker: lilaSpeaker,
                text: """
                And the coat. Always the coat. They handed it back in a paper bag like laundry. I took it home and found what they were too finished to feel for.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.key.reveal",
                voiceAssetName: "vo_lila_reply_neutral2_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical2",
                speaker: lilaSpeaker,
                text: """
                At least you're honest about the ink. Harborpoint prints truth on the cheap stock and saves the good paper for denials.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.cynical2.b",
                voiceAssetName: "vo_lila_reply_cynical2.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical2.b",
                speaker: lilaSpeaker,
                text: """
                Fine. Bill your hours. But look at the coat first—really look. Whoever emptied it left me one insult they didn't mean to leave.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.key.reveal",
                voiceAssetName: "vo_lila_reply_cynical2_b.m4a"
            ),

            CaseDialogueNode(
                id: "lila.key.reveal",
                speaker: lilaSpeaker,
                text: """
                Sewn into the lining—not dropped in a pocket where a night watchman might "find" it and lose it again—was a brass key. Small. Old teeth. No hotel tag. No landlord's number. Just brass that still smelled faintly of machine oil and river fog.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.key.reveal.b",
                voiceAssetName: "vo_lila_key_reveal.m4a"
            ),
            CaseDialogueNode(
                id: "lila.key.reveal.b",
                speaker: lilaSpeaker,
                text: """
                Since I found it, a man has been following me. Gray overcoat. Black gloves. He waits across the street from my boarding house and turns away the moment my eyes get brave enough to meet his. He doesn't wave. Men who wave want something polite. Men who turn away already have what they want: your fear, on a schedule.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.triad.key",
                voiceAssetName: "vo_lila_key_reveal_b.m4a"
            ),

            CaseDialogueNode(
                id: "lila.triad.key",
                speaker: lilaSpeaker,
                text: """
                I'm leaving the key with you if you'll take the case. I can pay some now and the rest when Harborpoint remembers how to be ashamed.

                Tell me how you want to play this, Mr. Voss—before that gray overcoat decides the conversation for us.
                """,
                portraitName: lilaPortrait,
                choices: [
                    CaseDialogueChoice(
                        text: "Leave the key. I'll keep you safe and find Lillian—or find the people who think a coat is a eulogy.",
                        destinationID: "lila.reply.good3",
                        tone: .goodHeroic
                    ),
                    CaseDialogueChoice(
                        text: "Leave the key. Describe the follower once more, then go somewhere with locks that aren't theater props.",
                        destinationID: "lila.reply.neutral3",
                        tone: .neutralPragmatic
                    ),
                    CaseDialogueChoice(
                        text: "Leave the key. If it opens a coffin or a vault, I'll send you the postcard. Try not to die before the retainer clears.",
                        destinationID: "lila.reply.cynical3",
                        tone: .cynicalSarcasm
                    ),
                    // Phase 1 gated Press: only after Voss already pushed hard (cynical triad-1).
                    CaseDialogueChoice(
                        text: "Leave the key—and tell me what you're still not saying. The police were too finished, the coat too empty, and that gray overcoat too professional for a simple river story. What did Lillian find that makes polite men grow teeth?",
                        destinationID: "lila.reply.press.gated",
                        conditions: [.hasFlag(EmptyCoatDialogueKeys.pressedHardOnStory)],
                        gateDisclosure: "Press"
                    )
                ],
                voiceAssetName: "vo_lila_triad_key.m4a"
            ),

            CaseDialogueNode(
                id: "lila.reply.press.gated",
                speaker: lilaSpeaker,
                text: """
                You push when you want the soft version to crack. Fine. Lillian was reading manifests that named men who prefer their cargo—and their sisters—anonymous. I don't have the names clean enough for a courtroom. I have a sister, a key, and a city that files people under finished.
                """,
                portraitName: lilaPortrait,
                choices: [caseAcceptanceChoice]
            ),

            CaseDialogueNode(
                id: "lila.reply.good3",
                speaker: lilaSpeaker,
                text: """
                Safe is a luxury in this weather—but I'll take the promise and walk carefully.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.good3.b",
                voiceAssetName: "vo_lila_reply_good3.m4a"
            ),
            // Classic BG: PC acceptance is a selectable reply on the NPC state (transition),
            // not a main-speaker Continue page. Merged former voss.accept + voss.accept.b prose.
            CaseDialogueNode(
                id: "lila.reply.good3.b",
                speaker: lilaSpeaker,
                text: """
                The follower: tall enough to make a doorway look narrow, hat brim low, gloves that never leave his hands even when he lights a cigarette for a man who isn't there. He never crosses the street. He only makes sure I know the street is already his.
                """,
                portraitName: lilaPortrait,
                choices: [caseAcceptanceChoice],
                voiceAssetName: "vo_lila_reply_good3_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral3",
                speaker: lilaSpeaker,
                text: """
                Gray overcoat, black gloves, no limp, no flash of a badge. He favors the bakery doorway across from my stairs between eleven and one. When a streetcar passes, he uses the noise to shift position. Professional habits. Ugly ones.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.neutral3.b",
                voiceAssetName: "vo_lila_reply_neutral3.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.neutral3.b",
                speaker: lilaSpeaker,
                text: """
                I'll stay with a friend on Printers' Quarter tonight. Real locks. Fewer witnesses who owe the docks a favor.
                """,
                portraitName: lilaPortrait,
                choices: [caseAcceptanceChoice],
                voiceAssetName: "vo_lila_reply_neutral3_b.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical3",
                speaker: lilaSpeaker,
                text: """
                Charming. If I wanted poetry about coffins I could have hired a priest.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.reply.cynical3.b",
                voiceAssetName: "vo_lila_reply_cynical3.m4a"
            ),
            CaseDialogueNode(
                id: "lila.reply.cynical3.b",
                speaker: lilaSpeaker,
                text: """
                Still—you'll take it. That's enough. The follower can have my shadow; you get the key. If the postcard arrives, make sure it's written in a hand that still shakes.
                """,
                portraitName: lilaPortrait,
                choices: [caseAcceptanceChoice],
                voiceAssetName: "vo_lila_reply_cynical3_b.m4a"
            ),

            CaseDialogueNode(
                id: "lila.plea",
                speaker: lilaSpeaker,
                text: """
                Please find her, Mr. Voss. Find the sister—not the coat's alibi.
                """,
                portraitName: lilaPortrait,
                nextNodeID: "lila.plea.b",
                voiceAssetName: "vo_lila_plea.m4a"
            ),
            CaseDialogueNode(
                id: "lila.plea.b",
                speaker: lilaSpeaker,
                text: """
                And if the gray overcoat comes looking for the key… tell him the rain already knows his name. I only hired you to teach him the rest.
                """,
                portraitName: lilaPortrait,
                nextNodeID: caseOpenedNodeID,
                voiceAssetName: "vo_lila_plea_b.m4a"
            )
        ]
    }

    private static var closingNodes: [CaseDialogueNode] {
        [
            CaseDialogueNode(
                id: caseOpenedNodeID,
                speaker: caseOpenedSpeaker,
                text: "THE EMPTY COAT",
                portraitName: vossPortrait,
                endsDialogue: true
            )
        ]
    }
}
