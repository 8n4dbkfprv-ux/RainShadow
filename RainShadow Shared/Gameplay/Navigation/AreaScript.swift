import Foundation

/// What an area script can ask about before it acts.
///
/// Wraps `DialogueCondition` rather than replacing it: case flags, evidence,
/// knowledge and counters are already a vocabulary the shipped content speaks,
/// and a second one would mean the same question phrased two ways. The cases
/// added here are the ones dialogue has no reason to know about — an area's own
/// variables.
///
/// The combinators are repeated rather than borrowed because `.not`, `.any` and
/// `.all` have to nest *these* conditions, and reaching into
/// `DialogueCondition`'s versions would only let them nest case questions.
indirect enum AreaScriptCondition: Equatable, Sendable {
    /// An unconditional block. BG writes this as an empty trigger list.
    case always
    /// Anything the dialogue vocabulary can already ask.
    case caseCondition(DialogueCondition)
    /// A variable in the script's own area is non-zero.
    case variableIsSet(String)
    case variableAtLeast(String, Int)
    case variableEquals(String, Int)
    /// A variable in the game-wide scope, BG's `GLOBAL`.
    case globalIsSet(String)
    /// The party is standing in a named trigger region this tick.
    case regionInside(String)
    case not(AreaScriptCondition)
    case any([AreaScriptCondition])
    case all([AreaScriptCondition])

    func isSatisfied(by context: AreaScriptContext) -> Bool {
        switch self {
        case .always:
            true
        case .caseCondition(let condition):
            condition.isSatisfied(by: context.dialogue)
        case .variableIsSet(let name):
            context.variables.isSet(name, in: context.area)
        case .variableAtLeast(let name, let value):
            context.variables.integer(name, in: context.area) >= value
        case .variableEquals(let name, let value):
            context.variables.integer(name, in: context.area) == value
        case .globalIsSet(let name):
            context.variables.isSet(name, in: AreaVariables.globalScope)
        case .regionInside(let id):
            context.insideRegionIDs.contains(id)
        case .not(let condition):
            !condition.isSatisfied(by: context)
        case .any(let conditions):
            conditions.contains { $0.isSatisfied(by: context) }
        case .all(let conditions):
            conditions.allSatisfy { $0.isSatisfied(by: context) }
        }
    }
}

/// What an area script does when a block fires.
enum AreaScriptAction: Equatable, Sendable {
    /// Anything the dialogue vocabulary can already do — set a case flag, grant
    /// evidence, queue a journal fragment.
    case caseAction(DialogueAction)
    case setVariable(String, AreaVariableValue)
    case incrementVariable(String, by: Int)
    case setGlobal(String, AreaVariableValue)
    /// Hand off to the cutscene stack, which is BG's `StartCutSceneMode`.
    case startCutscene(String)
}

/// One `IF triggers THEN actions` block.
struct AreaScriptBlock: Equatable, Sendable {
    var id: String
    var condition: AreaScriptCondition
    var actions: [AreaScriptAction]

    init(id: String, when condition: AreaScriptCondition = .always, do actions: [AreaScriptAction]) {
        self.id = id
        self.condition = condition
        self.actions = actions
    }
}

/// An area's script: ordered blocks, evaluated on the logic tick.
///
/// The ordering rule is the engine's and is the whole reason a script is a list
/// rather than a set. A Baldur's Gate `BCS` is evaluated top down and **the
/// first block whose triggers are satisfied runs; the rest are skipped for that
/// tick**. That is what makes a script readable as priorities — the urgent case
/// goes at the top, the idle case at the bottom — and a runner that fired every
/// matching block would run the idle behaviour alongside the emergency.
struct AreaScript: Equatable, Sendable {
    var id: String
    var blocks: [AreaScriptBlock]

    init(id: String, blocks: [AreaScriptBlock]) {
        self.id = id
        self.blocks = blocks
    }

    /// The first block whose condition holds, or `nil` when none does.
    func firstSatisfiedBlock(in context: AreaScriptContext) -> AreaScriptBlock? {
        blocks.first { $0.condition.isSatisfied(by: context) }
    }
}

/// What a script can see.
struct AreaScriptContext: Equatable, Sendable {
    /// The scope a bare variable name resolves in.
    var area: AreaID
    var variables: AreaVariables
    var dialogue: DialogueRuntimeContext
    var insideRegionIDs: Set<String>

    init(
        area: AreaID,
        variables: AreaVariables,
        dialogue: DialogueRuntimeContext,
        insideRegionIDs: Set<String> = []
    ) {
        self.area = area
        self.variables = variables
        self.dialogue = dialogue
        self.insideRegionIDs = insideRegionIDs
    }
}

/// Runs one tick of an area script.
///
/// Pure: it decides what should happen and hands the actions back rather than
/// performing them, because everything an action touches — the save, the
/// cutscene director, the case state — lives outside this target. That also
/// makes the ordering rule testable without a running scene, which is the part
/// most likely to be got wrong.
enum AreaScriptRunner {
    struct Outcome: Equatable, Sendable {
        /// The block that fired, if any.
        var blockID: String?
        /// Actions for the caller to apply, in order.
        var actions: [AreaScriptAction]
        /// Variables after the script's own writes. Case actions are not applied
        /// here — the caller owns case state.
        var variables: AreaVariables

        var didFire: Bool { blockID != nil }
    }

    /// Evaluate one tick.
    static func tick(_ script: AreaScript, in context: AreaScriptContext) -> Outcome {
        guard let block = script.firstSatisfiedBlock(in: context) else {
            return Outcome(blockID: nil, actions: [], variables: context.variables)
        }
        var variables = context.variables
        for action in block.actions {
            switch action {
            case .setVariable(let name, let value):
                variables.set(value, name, in: context.area)
            case .incrementVariable(let name, let delta):
                variables.increment(name, in: context.area, by: delta)
            case .setGlobal(let name, let value):
                variables.set(value, name, in: AreaVariables.globalScope)
            case .caseAction, .startCutscene:
                break
            }
        }
        return Outcome(blockID: block.id, actions: block.actions, variables: variables)
    }

    /// Run a named block regardless of the first-satisfied rule, which is how a
    /// proximity trigger fires its script hook.
    static func runBlock(
        _ id: String,
        of script: AreaScript,
        in context: AreaScriptContext
    ) -> Outcome {
        guard let block = script.blocks.first(where: { $0.id == id }) else {
            return Outcome(blockID: nil, actions: [], variables: context.variables)
        }
        var variables = context.variables
        for action in block.actions {
            switch action {
            case .setVariable(let name, let value):
                variables.set(value, name, in: context.area)
            case .incrementVariable(let name, let delta):
                variables.increment(name, in: context.area, by: delta)
            case .setGlobal(let name, let value):
                variables.set(value, name, in: AreaVariables.globalScope)
            case .caseAction, .startCutscene:
                break
            }
        }
        return Outcome(blockID: block.id, actions: block.actions, variables: variables)
    }
}
