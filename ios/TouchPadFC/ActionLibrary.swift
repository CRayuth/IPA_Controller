import SwiftUI
import UIKit

enum ActionCategory: String, CaseIterable, Identifiable {
    case passing = "PASS / CROSS"
    case shooting = "SHOOTING"
    case movement = "MOVEMENT"
    case skills = "SKILLS"
    case defending = "DEFENDING"
    case tactics = "TACTICS"
    case keeper = "GOALKEEPER"
    case setPieces = "SET PIECES"

    var id: String { rawValue }
}

enum RelativeDirection: String, CaseIterable, Identifiable {
    case forward, back, left, right, forwardLeft, forwardRight, backLeft, backRight
    var id: String { rawValue }

    var label: String {
        switch self {
        case .forward: return "Forward"
        case .back: return "Back"
        case .left: return "Left"
        case .right: return "Right"
        case .forwardLeft: return "Forward-left"
        case .forwardRight: return "Forward-right"
        case .backLeft: return "Back-left"
        case .backRight: return "Back-right"
        }
    }

    // FC skill commands are relative to the FOOTBALLER's facing direction.
    // The user sets that direction explicitly; the phone cannot observe player facing.
    func point(facing: String) -> CGPoint {
        let forward: CGPoint
        switch facing {
        case "left": forward = CGPoint(x: -1, y: 0)
        case "up": forward = CGPoint(x: 0, y: 1)
        case "down": forward = CGPoint(x: 0, y: -1)
        default: forward = CGPoint(x: 1, y: 0)
        }
        let side = CGPoint(x: forward.y, y: -forward.x)
        var f: CGFloat = 0
        var s: CGFloat = 0
        switch self {
        case .forward: f = 1
        case .back: f = -1
        case .left: s = -1
        case .right: s = 1
        case .forwardLeft: f = 1; s = -1
        case .forwardRight: f = 1; s = 1
        case .backLeft: f = -1; s = -1
        case .backRight: f = -1; s = 1
        }
        let norm = max(1, hypot(f, s))
        return CGPoint(x: (forward.x * f + side.x * s) / norm,
                       y: (forward.y * f + side.y * s) / norm)
    }
}

enum ActionKind {
    case tap([String])
    case combo([String], String)
    case double(String, [String])
    case fakeShot
    case fakePass
    case lowDriven([String])
    case hold([String])
    case holdRight(RelativeDirection, [String])
    case dpad([String])
    case rightFlick(RelativeDirection, [String])
    case rightPath([RelativeDirection], [String])
    case repeatPress([String])
    case superCancel
}

struct GameAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    let hint: String
    let category: ActionCategory
    let kind: ActionKind
    var stars: Int = 0

    var needsFacing: Bool {
        switch kind {
        case .holdRight, .rightFlick, .rightPath: return true
        default: return false
        }
    }

    var isContinuous: Bool {
        switch kind {
        case .hold, .holdRight: return true
        default: return false
        }
    }

    @MainActor func perform(on controller: ControllerModel, facing: String) {
        switch kind {
        case .tap(let keys): controller.tap(keys)
        case .combo(let modifiers, let action): controller.combo(modifiers, action)
        case .double(let action, let modifiers): controller.doubleTap(action, modifiers: modifiers)
        case .fakeShot: controller.fakeShot()
        case .fakePass: controller.fakePass()
        case .lowDriven(let modifiers): controller.lowDriven(modifiers: modifiers)
        case .dpad(let directions): controller.dPadSequence(directions)
        case .rightFlick(let direction, let modifiers):
            let p = direction.point(facing: facing)
            controller.flickRight(x: p.x, y: p.y, modifiers: modifiers)
        case .rightPath(let directions, let modifiers):
            var steps = [InputStep(modifiers, 40)]
            for dir in directions {
                steps.append(InputStep(modifiers, 80, rightStick: dir.point(facing: facing)))
            }
            steps += [InputStep(modifiers, 45), .neutral()]
            controller.playSequence(steps, channel: "skill")
        case .repeatPress(let keys):
            controller.playSequence([
                InputStep(keys, 90), .neutral(75),
                InputStep(keys, 420), .neutral()
            ], channel: "defend.press")
        case .superCancel: controller.cancelKick()
        case .hold, .holdRight: break // Handled by touch-down/up below.
        }
    }

    @MainActor func hold(on controller: ControllerModel, facing: String, down: Bool) {
        let source = "library.\(id)"
        switch kind {
        case .hold(let keys):
            controller.setHold(source: source, keys: keys, down: down)
        case .holdRight(let direction, let modifiers):
            let p = direction.point(facing: facing)
            controller.setHold(source: source, keys: modifiers, down: down)
            controller.setRightStickHold(source: source, x: p.x, y: p.y, down: down)
        default: break
        }
    }
}

// These actions use the Classic controller scheme. Some context-sensitive
// moves need specific positioning and the required player's skill rating.
enum FCActionCatalog {
    static let all: [GameAction] = [
        .init(id: "loftPass", title: "Lofted pass", detail: "× twice", hint: "Pass over a nearby leg", category: .passing, kind: .double("cross", [])),
        .init(id: "dinkThrough", title: "Dink through", detail: "△ twice", hint: "Manual aim matters", category: .passing, kind: .double("triangle", [])),
        .init(id: "lobThrough", title: "Lob through", detail: "L1 + △", hint: "Over the back line", category: .passing, kind: .combo(["l1"], "triangle")),
        .init(id: "drivenThrough", title: "Driven through", detail: "L1 + R1 + △", hint: "Fast pass into space", category: .passing, kind: .combo(["l1", "r1"], "triangle")),
        .init(id: "precisionThrough", title: "Precision through", detail: "R1 + △", hint: "More manual targeting", category: .passing, kind: .combo(["r1"], "triangle")),
        .init(id: "swerveThrough", title: "Swerve through", detail: "L2 + R1 + △", hint: "Use with deliberate aim", category: .passing, kind: .combo(["l2", "r1"], "triangle")),
        .init(id: "drivenPass", title: "Driven pass", detail: "R1 + ×", hint: "Fast ground pass", category: .passing, kind: .combo(["r1"], "cross")),
        .init(id: "passGo", title: "Pass and go", detail: "L1 + ×", hint: "Passer makes a run", category: .passing, kind: .combo(["l1"], "cross")),
        .init(id: "passFollow", title: "Pass & Follow", detail: "L1 + R1 + ×", hint: "New curved follow-up", category: .passing, kind: .combo(["l1", "r1"], "cross")),
        .init(id: "doubleSupport", title: "Double teammate support", detail: "R1 twice", hint: "Call extra support", category: .movement, kind: .double("r1", [])),
        .init(id: "dirRunLeft", title: "Run: left", detail: "L1 + RS left", hint: "Relative to player facing", category: .movement, kind: .rightFlick(.left, ["l1"])),
        .init(id: "dirRunRight", title: "Run: right", detail: "L1 + RS right", hint: "Relative to player facing", category: .movement, kind: .rightFlick(.right, ["l1"])),
        .init(id: "dirRunBack", title: "Run: back", detail: "L1 + RS back", hint: "Relative to player facing", category: .movement, kind: .rightFlick(.back, ["l1"])),
        .init(id: "flairPass", title: "Flair pass", detail: "L2 + ×", hint: "Creative passing", category: .passing, kind: .combo(["l2"], "cross")),
        .init(id: "cross", title: "Normal cross", detail: "□", hint: "Hold longer for power using main control", category: .passing, kind: .tap(["square"])),
        .init(id: "highCross", title: "High cross", detail: "L1 + □", hint: "More loft", category: .passing, kind: .combo(["l1"], "square")),
        .init(id: "drivenCross", title: "Driven cross", detail: "L1 + R1 + □", hint: "Fast delivery", category: .passing, kind: .combo(["l1", "r1"], "square")),
        .init(id: "groundCross", title: "Ground cross", detail: "□ twice", hint: "Low cross", category: .passing, kind: .double("square", [])),
        .init(id: "drivenGroundCross", title: "Driven ground cross", detail: "L1 + R1 + □ twice", hint: "Low and fast delivery", category: .passing, kind: .double("square", ["l1", "r1"])),
        .init(id: "flairCross", title: "Flair cross", detail: "L2 + □", hint: "Outside-foot or creative delivery", category: .passing, kind: .combo(["l2"], "square")),
        .init(id: "precisionLob", title: "Precision lob", detail: "R1 + □", hint: "More manual loft", category: .passing, kind: .combo(["r1"], "square")),
        .init(id: "fakePass", title: "Fake pass", detail: "□ then ×", hint: "Feint the cross", category: .passing, kind: .fakePass),

        .init(id: "finesse", title: "Curve / Finesse", detail: "R1 + ○", hint: "Curl shot toward corner", category: .shooting, kind: .combo(["r1"], "circle")),
        .init(id: "chip", title: "Chip shot", detail: "L1 + ○", hint: "Lift above the keeper", category: .shooting, kind: .combo(["l1"], "circle")),
        .init(id: "powerShot", title: "Power shot", detail: "L1 + R1 + ○", hint: "Needs time and space", category: .shooting, kind: .combo(["l1", "r1"], "circle")),
        .init(id: "flairShot", title: "Flair shot", detail: "L2 + ○", hint: "Context-dependent outside-foot", category: .shooting, kind: .combo(["l2"], "circle")),
        .init(id: "lowDriven", title: "Low driven", detail: "Charge ○, then ○", hint: "Short sequence with fixed charge", category: .shooting, kind: .lowDriven([])),
        .init(id: "lowFinesse", title: "Low finesse", detail: "R1 + ○ then ○", hint: "Low curl shot", category: .shooting, kind: .lowDriven(["r1"])),
        .init(id: "lowPower", title: "Low power", detail: "L1 + R1 + ○ then ○", hint: "Low power finish", category: .shooting, kind: .lowDriven(["l1", "r1"])),
        .init(id: "fakeShot", title: "Fake shot", detail: "○ then ×", hint: "Keep moving to exit", category: .shooting, kind: .fakeShot),
        .init(id: "superCancel", title: "Hard Super Cancel", detail: "L1 + R1 + L2 + R2", hint: "Can interrupt some actions", category: .shooting, kind: .superCancel),

        .init(id: "run", title: "Teammate run", detail: "L1", hint: "Send teammate forward", category: .movement, kind: .tap(["l1"])),
        .init(id: "support", title: "Call teammate", detail: "R1", hint: "Come short for a pass", category: .movement, kind: .tap(["r1"])),
        .init(id: "curveRun", title: "Curved run", detail: "L1 + R1", hint: "Hold left-stick direction while triggering", category: .movement, kind: .tap(["l1", "r1"])),
        .init(id: "directionRun", title: "Directional run", detail: "L1 + right stick", hint: "Uses facing selector", category: .movement, kind: .rightFlick(.forward, ["l1"])),
        .init(id: "playerLock", title: "Player Lock", detail: "L3 + R3", hint: "Switch to off-ball control", category: .movement, kind: .tap(["l3", "r3"])),
        .init(id: "strafe", title: "Strafe dribble", detail: "Hold L1", hint: "Hold and use left joystick", category: .movement, kind: .hold(["l1"])),
        .init(id: "shield", title: "Shield the ball", detail: "Hold L2", hint: "Protect against contact", category: .movement, kind: .hold(["l2"])),
        .init(id: "controlledSprint", title: "Controlled sprint", detail: "Hold R1", hint: "Keep ball closer while sprinting", category: .movement, kind: .hold(["r1"])),
        .init(id: "knockOn", title: "Knock-on", detail: "R2 + right stick", hint: "Requires correct facing", category: .movement, kind: .rightFlick(.forward, ["r2"])),
        .init(id: "effortTouch", title: "Effort touch", detail: "R1 + right stick", hint: "Requires correct facing", category: .movement, kind: .rightFlick(.forward, ["r1"])),
        .init(id: "stopFace", title: "Stop & face", detail: "L1 with neutral left stick", hint: "Release movement before tapping", category: .movement, kind: .tap(["l1"])),
        .init(id: "stopBall", title: "Stop ball", detail: "R2 with neutral left stick", hint: "Release movement before tapping", category: .movement, kind: .tap(["r2"])),

        .init(id: "rollLeft", title: "Ball Roll Left", detail: "2★ | Hold RS left", hint: "Hold to control duration", category: .skills, kind: .holdRight(.left, []), stars: 2),
        .init(id: "rollRight", title: "Ball Roll Right", detail: "2★ | Hold RS right", hint: "Hold to control duration", category: .skills, kind: .holdRight(.right, []), stars: 2),
        .init(id: "feintLeft", title: "Body Feint Left", detail: "2★ | RS flick left", hint: "Quick direction change", category: .skills, kind: .rightFlick(.left, []), stars: 2),
        .init(id: "feintRight", title: "Body Feint Right", detail: "2★ | RS flick right", hint: "Quick direction change", category: .skills, kind: .rightFlick(.right, []), stars: 2),
        .init(id: "stepLeft", title: "Stepover Left", detail: "2★ | RS forward → left", hint: "Change pace after the move", category: .skills, kind: .rightPath([.forward, .forwardLeft, .left], []), stars: 2),
        .init(id: "stepRight", title: "Stepover Right", detail: "2★ | RS forward → right", hint: "Change pace after the move", category: .skills, kind: .rightPath([.forward, .forwardRight, .right], []), stars: 2),
        .init(id: "heelFlick", title: "Heel Flick", detail: "3★ | RS forward, back", hint: "Use at running speed", category: .skills, kind: .rightPath([.forward, .back], []), stars: 3),
        .init(id: "rouletteLeft", title: "Roulette Left", detail: "3★ | RS curved sequence", hint: "Turn away from contact", category: .skills, kind: .rightPath([.back, .backLeft, .left, .forwardLeft, .forward], []), stars: 3),
        .init(id: "rouletteRight", title: "Roulette Right", detail: "3★ | RS curved sequence", hint: "Turn away from contact", category: .skills, kind: .rightPath([.back, .backRight, .right, .forwardRight, .forward], []), stars: 3),
        .init(id: "stopGo", title: "Stop and Go", detail: "2★ | L2 + RS back, forward", hint: "New move", category: .skills, kind: .rightPath([.back, .forward], ["l2"]), stars: 2),
        .init(id: "elastico", title: "Elastico", detail: "5★ | RS arc right to left", hint: "Elite dribblers only", category: .skills, kind: .rightPath([.right, .backRight, .back, .backLeft, .left], []), stars: 5),
        .init(id: "reverseElastico", title: "Reverse Elastico", detail: "5★ | RS arc left to right", hint: "Elite dribblers only", category: .skills, kind: .rightPath([.left, .backLeft, .back, .backRight, .right], []), stars: 5),
        .init(id: "nutmeg", title: "Directional Nutmeg", detail: "1★ | L1 + R1 + RS", hint: "Direction relative to player", category: .skills, kind: .rightFlick(.forward, ["l1", "r1"]), stars: 1),

        .init(id: "standTackle", title: "Standing tackle", detail: "○", hint: "Tackle when close", category: .defending, kind: .tap(["circle"])),
        .init(id: "hardTackle", title: "Hard tackle", detail: "R1 + ○", hint: "Aggressive challenge", category: .defending, kind: .combo(["r1"], "circle")),
        .init(id: "slideTackle", title: "Slide tackle", detail: "□", hint: "High risk if missed", category: .defending, kind: .tap(["square"])),
        .init(id: "hardSlide", title: "Hard slide", detail: "R1 + □", hint: "Aggressive slide", category: .defending, kind: .combo(["r1"], "square")),
        .init(id: "contain", title: "Contain / Physical", detail: "Hold ×", hint: "Depends on FC defending scheme", category: .defending, kind: .hold(["cross"])),
        .init(id: "teammateContain", title: "Teammate contain", detail: "Hold R1", hint: "Second defender presses", category: .defending, kind: .hold(["r1"])),
        .init(id: "jockey", title: "Jockey", detail: "Hold L2", hint: "Stay goal-side", category: .defending, kind: .hold(["l2"])),
        .init(id: "sprintJockey", title: "Sprint jockey", detail: "Hold L2 + R2", hint: "Defend against speed", category: .defending, kind: .hold(["l2", "r2"])),
        .init(id: "professionalFoul", title: "Professional foul", detail: "R1 + ×", hint: "May receive a card", category: .defending, kind: .combo(["r1"], "cross")),
        .init(id: "partialPress", title: "Partial team press", detail: "R1 then hold R1", hint: "Timed press request", category: .defending, kind: .repeatPress(["r1"])),
        .init(id: "iconSwitch", title: "Icon switching", detail: "R3", hint: "Select labeled defender", category: .defending, kind: .tap(["r3"])),
        .init(id: "switchLeft", title: "Switch left", detail: "Right stick left", hint: "Manual directional switch", category: .defending, kind: .rightFlick(.left, [])),
        .init(id: "switchRight", title: "Switch right", detail: "Right stick right", hint: "Manual directional switch", category: .defending, kind: .rightFlick(.right, [])),
        .init(id: "keeperRush", title: "Keeper rush", detail: "Hold △", hint: "Release to stop rushing", category: .defending, kind: .hold(["triangle"])),

        .init(id: "teamPress", title: "Team Press", detail: "D-pad ↑ then ←", hint: "Press high up the pitch", category: .tactics, kind: .dpad(["d_up", "d_left"])),
        .init(id: "offside", title: "Offside trap", detail: "D-pad ↑ then ↑", hint: "Step up with defensive line", category: .tactics, kind: .dpad(["d_up", "d_up"])),
        .init(id: "extraStriker", title: "Extra striker", detail: "D-pad ↑ then →", hint: "Commit one more attacker", category: .tactics, kind: .dpad(["d_up", "d_right"])),
        .init(id: "getInBox", title: "Get in box", detail: "D-pad ↑ then ↓", hint: "More box occupation", category: .tactics, kind: .dpad(["d_up", "d_down"])),
        .init(id: "focusAttack", title: "Attacking focus", detail: "D-pad → then →", hint: "Riskier team approach", category: .tactics, kind: .dpad(["d_right", "d_right"])),
        .init(id: "focusDefend", title: "Defending focus", detail: "D-pad → then ←", hint: "More conservative", category: .tactics, kind: .dpad(["d_right", "d_left"])),
        .init(id: "focusDefault", title: "Default focus", detail: "D-pad → then ↑", hint: "Reset tactical focus", category: .tactics, kind: .dpad(["d_right", "d_up"])),
        .init(id: "tactic1", title: "Saved tactic 1", detail: "D-pad ← then ↑", hint: "Your preconfigured tactic", category: .tactics, kind: .dpad(["d_left", "d_up"])),
        .init(id: "tactic2", title: "Saved tactic 2", detail: "D-pad ← then ←", hint: "Your preconfigured tactic", category: .tactics, kind: .dpad(["d_left", "d_left"])),
        .init(id: "tactic3", title: "Saved tactic 3", detail: "D-pad ← then →", hint: "Your preconfigured tactic", category: .tactics, kind: .dpad(["d_left", "d_right"])),
        .init(id: "tactic4", title: "Saved tactic 4", detail: "D-pad ← then ↓", hint: "Your preconfigured tactic", category: .tactics, kind: .dpad(["d_left", "d_down"])),
        .init(id: "suggestTactic1", title: "Suggested tactic 1", detail: "D-pad ↓ then ↑", hint: "Match suggestions", category: .tactics, kind: .dpad(["d_down", "d_up"])),
        .init(id: "suggestTactic2", title: "Suggested tactic 2", detail: "D-pad ↓ then ←", hint: "Match suggestions", category: .tactics, kind: .dpad(["d_down", "d_left"])),
        .init(id: "substitutions", title: "Substitutions", detail: "D-pad ↓ then ↓", hint: "Open suggested subs", category: .tactics, kind: .dpad(["d_down", "d_down"])),

        .init(id: "gkOut", title: "Rush keeper", detail: "Hold △", hint: "Bring goalkeeper forward", category: .keeper, kind: .hold(["triangle"])),
        .init(id: "gkIcon", title: "Keeper positioning", detail: "R3 + RS direction", hint: "Manual facing needed", category: .keeper, kind: .holdRight(.left, ["r3"])),
        .init(id: "gkSwitch", title: "Icon switching", detail: "R3", hint: "Selection control", category: .keeper, kind: .tap(["r3"])),
        .init(id: "gkMoveRight", title: "GK position right", detail: "Hold R3 + RS right", hint: "Manual keeper position", category: .keeper, kind: .holdRight(.right, ["r3"])),
        .init(id: "gkMoveUp", title: "GK position up", detail: "Hold R3 + RS forward", hint: "Manual keeper position", category: .keeper, kind: .holdRight(.forward, ["r3"])),
        .init(id: "gkMoveBack", title: "GK position back", detail: "Hold R3 + RS back", hint: "Manual keeper position", category: .keeper, kind: .holdRight(.back, ["r3"])),
        .init(id: "gkRushContain", title: "GK rush to contain", detail: "△ then hold △", hint: "Timed simulated hold", category: .keeper, kind: .repeatPress(["triangle"])),
        .init(id: "gkRelease", title: "GK release", detail: "○", hint: "Context-dependent distribution", category: .keeper, kind: .tap(["circle"])),

        .init(id: "spSecond", title: "Call 2nd taker", detail: "Hold L2", hint: "Free kick", category: .setPieces, kind: .hold(["l2"])),
        .init(id: "spSecondShot", title: "2nd taker shot", detail: "L2 + ○", hint: "Free kick", category: .setPieces, kind: .combo(["l2"], "circle")),
        .init(id: "spSecondLayoff", title: "2nd taker layoff", detail: "L2 + ×", hint: "Free kick", category: .setPieces, kind: .combo(["l2"], "cross")),
        .init(id: "spThird", title: "Call 3rd taker", detail: "Hold R1", hint: "Free kick", category: .setPieces, kind: .hold(["r1"])),
        .init(id: "spThirdShot", title: "3rd taker shot", detail: "R1 + ○", hint: "Free kick", category: .setPieces, kind: .combo(["r1"], "circle")),
        .init(id: "spFreeNear", title: "Free kick: near run", detail: "D-pad ↑ then ↓", hint: "New FK tactics", category: .setPieces, kind: .dpad(["d_up", "d_down"])),
        .init(id: "spFreeFar", title: "Free kick: far run", detail: "D-pad ↑ then ←", hint: "New FK tactics", category: .setPieces, kind: .dpad(["d_up", "d_left"])),
        .init(id: "spAdd", title: "Add player", detail: "D-pad ↑ then ↑", hint: "Free kick or corner", category: .setPieces, kind: .dpad(["d_up", "d_up"])),
        .init(id: "spRemove", title: "Remove player", detail: "D-pad ↑ then →", hint: "Free kick or corner", category: .setPieces, kind: .dpad(["d_up", "d_right"])),
        .init(id: "spCornerShield", title: "Corner shield", detail: "Hold L2", hint: "Position with left joystick", category: .setPieces, kind: .hold(["l2"])),
        .init(id: "spCornerAvoid", title: "Corner avoidance", detail: "Hold R1", hint: "Position with left joystick", category: .setPieces, kind: .hold(["r1"])),
        .init(id: "spShortThrow", title: "Short throw-in", detail: "×", hint: "Short target", category: .setPieces, kind: .tap(["cross"])),
        .init(id: "spLongThrow", title: "Long throw-in", detail: "□", hint: "Hold control longer from main screen", category: .setPieces, kind: .hold(["square"])),
        .init(id: "spReturn", title: "Super Cancel", detail: "L1 + R1 + L2 + R2", hint: "Not guaranteed to cancel a kick", category: .setPieces, kind: .superCancel)
    ]
}

struct ActionLibraryView: View {
    let initialCategory: ActionCategory
    @EnvironmentObject private var controller: ControllerModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("touchpadfc.attackFacing") private var facing = "right"
    @State private var category: ActionCategory
    @State private var search = ""
    @State private var showFavorites = false
    @AppStorage("touchpadfc.favoriteActions") private var favoritesRaw = "finesse,drivenCross,teamPress,rollRight"

    init(initialCategory: ActionCategory = .passing) {
        self.initialCategory = initialCategory
        _category = State(initialValue: initialCategory)
    }

    private var favorites: Set<String> {
        Set(favoritesRaw.split(separator: ",").map(String.init))
    }

    private var results: [GameAction] {
        FCActionCatalog.all.filter { action in
            let inCategory = showFavorites ? favorites.contains(action.id) : action.category == category
            return inCategory && (search.isEmpty ||
                action.title.localizedCaseInsensitiveContains(search) ||
                action.detail.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryButton("★ Favorites", selected: showFavorites) { showFavorites = true }
                        ForEach(ActionCategory.allCases) { item in
                            categoryButton(item.rawValue, selected: !showFavorites && category == item) {
                                category = item
                                showFavorites = false
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search moves or controls", text: $search)
                        .textInputAutocapitalization(.never)
                }
                .padding(9)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 12)

                if category == .skills || category == .movement || category == .keeper || showFavorites {
                    HStack(spacing: 6) {
                        Text("PLAYER FACES")
                            .font(.system(size: 10, weight: .bold))
                        ForEach(["left", "up", "right", "down"], id: \.self) { value in
                            Button(value == "left" ? "←" : value == "right" ? "→" : value == "up" ? "↑" : "↓") {
                                facing = value
                            }
                            .buttonStyle(.bordered)
                            .tint(facing == value ? .green : .gray)
                        }
                        Spacer(minLength: 2)
                        Text("Manual")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(results) { action in
                            ActionTile(action: action, facing: facing,
                                       favorite: favorites.contains(action.id),
                                       toggleFavorite: { toggleFavorite(action.id) })
                        }
                    }
                    .padding(12)
                }

                Text("Tap for one-shot • Hold for continuous • ★ to save • Skill directions need manual facing")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 7)
            }
            .background(Color(red: 0.04, green: 0.06, blue: 0.09))
            .foregroundStyle(.white)
            .navigationTitle("MORE ACTIONS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .onDisappear { controller.releaseInputs() }
        }
        .preferredColorScheme(.dark)
    }

    private func categoryButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8).frame(height: 30)
                .background(selected ? Color.green.opacity(0.45) : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite(_ id: String) {
        var items = favorites
        if items.contains(id) { items.remove(id) } else { items.insert(id) }
        favoritesRaw = items.sorted().joined(separator: ",")
    }
}

private struct ActionTile: View {
    let action: GameAction
    let facing: String
    let favorite: Bool
    let toggleFavorite: () -> Void
    @EnvironmentObject private var controller: ControllerModel
    @State private var holding = false

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Group {
                if action.isContinuous {
                    VStack(alignment: .leading, spacing: 4) { description }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !holding else { return }
                                holding = true
                                action.hold(on: controller, facing: facing, down: true)
                            }
                            .onEnded { _ in release() })
                } else {
                    Button {
                        action.perform(on: controller, facing: facing)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) { description }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(action: toggleFavorite) {
                Image(systemName: favorite ? "star.fill" : "star")
                    .foregroundStyle(favorite ? .yellow : .gray)
                    .font(.system(size: 13))
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(holding ? Color.green.opacity(0.25) : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 11))
        .onDisappear { release() }
    }

    private var description: some View {
        Group {
            Text(action.title)
                .font(.system(size: 12, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(action.detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
            Text(action.hint)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func release() {
        guard holding else { return }
        holding = false
        action.hold(on: controller, facing: facing, down: false)
    }
}

// Two configurable, always-accessible shortcuts on the simple match screen.
// Continuous actions can be held while moving with the left thumb.
struct QuickActionPad: View {
    let action: GameAction
    @EnvironmentObject private var controller: ControllerModel
    @AppStorage("touchpadfc.attackFacing") private var facing = "right"
    @State private var touching = false

    var body: some View {
        Text(action.title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .lineLimit(2).minimumScaleFactor(0.67)
            .multilineTextAlignment(.center)
            .frame(width: 92, height: 39)
            .background(touching ? Color.green.opacity(0.65) : Color.teal.opacity(0.30),
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .stroke(.teal.opacity(0.8), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !touching else { return }
                    touching = true
                    if action.isContinuous {
                        action.hold(on: controller, facing: facing, down: true)
                    }
                }
                .onEnded { _ in
                    if action.isContinuous {
                        action.hold(on: controller, facing: facing, down: false)
                    } else {
                        action.perform(on: controller, facing: facing)
                    }
                    touching = false
                })
            .onDisappear {
                if touching && action.isContinuous {
                    action.hold(on: controller, facing: facing, down: false)
                }
                touching = false
            }
    }
}
