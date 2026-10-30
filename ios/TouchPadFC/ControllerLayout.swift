
import Foundation
import SwiftUI

struct PadPlacement: Codable, Equatable {
    var x: Double
    var y: Double
    var scale: Double
}

enum PadItem: String, CaseIterable, Identifiable {
    case move, through, shoot, pass, dash
    case cross, finesse, chip, slide, skill
    case l1, l2, r1, r2, options

    var id: String { rawValue }

    var title: String {
        switch self {
        case .move: return "Move joystick"
        case .through: return "Through / Dash + Press"
        case .shoot: return "Shoot / Tackle"
        case .pass: return "Pass / Switch"
        case .dash: return "Dash / Match-up"
        case .cross: return "Cross / Slide"
        case .finesse: return "Finesse / GK Rush"
        case .chip: return "Chip / Sprint Jockey"
        case .slide: return "Extra action"
        case .skill: return "Skill joystick"
        case .l1: return "L1"
        case .l2: return "L2"
        case .r1: return "R1"
        case .r2: return "R2"
        case .options: return "Options"
        }
    }

    var size: CGSize {
        switch self {
        case .move: return CGSize(width: 132, height: 132)
        case .through, .shoot, .pass, .dash:
            return CGSize(width: 82, height: 82)
        case .skill: return CGSize(width: 80, height: 80)
        case .l1, .l2, .r1, .r2:
            return CGSize(width: 62, height: 32)
        case .options: return CGSize(width: 64, height: 30)
        default: return CGSize(width: 86, height: 34)
        }
    }

    var defaultPlacement: PadPlacement {
        switch self {
        case .move: return .init(x: 0.15, y: 0.67, scale: 1)
        case .through: return .init(x: 0.79, y: 0.40, scale: 1)
        case .shoot: return .init(x: 0.93, y: 0.30, scale: 1)
        case .pass: return .init(x: 0.79, y: 0.79, scale: 1)
        case .dash: return .init(x: 0.93, y: 0.71, scale: 1)
        case .cross: return .init(x: 0.47, y: 0.35, scale: 1)
        case .finesse: return .init(x: 0.60, y: 0.35, scale: 1)
        case .chip: return .init(x: 0.47, y: 0.52, scale: 1)
        case .slide: return .init(x: 0.60, y: 0.52, scale: 1)
        case .skill: return .init(x: 0.58, y: 0.78, scale: 1)
        case .l2: return .init(x: 0.06, y: 0.08, scale: 1)
        case .l1: return .init(x: 0.16, y: 0.08, scale: 1)
        case .r1: return .init(x: 0.75, y: 0.08, scale: 1)
        case .r2: return .init(x: 0.86, y: 0.08, scale: 1)
        case .options: return .init(x: 0.47, y: 0.90, scale: 1)
        }
    }
}

@MainActor
final class ControllerLayoutStore: ObservableObject {
    @Published private var custom: [String: PadPlacement] = [:]
    @Published var editing = false
    @Published var selected: PadItem?

    let minScale = 0.65
    let maxScale = 1.45
    private let key = "touchpadfc.pes.layout.v4"

    init() {
        if let bytes = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(
                [String: PadPlacement].self, from: bytes
           ) {
            custom = saved.filter {
                PadItem(rawValue: $0.key) != nil &&
                $0.value.x.isFinite &&
                $0.value.y.isFinite &&
                $0.value.scale.isFinite
            }
        }
    }

    func placement(_ item: PadItem) -> PadPlacement {
        let p = custom[item.rawValue] ?? item.defaultPlacement
        return .init(
            x: p.x.clamped(to: 0...1),
            y: p.y.clamped(to: 0...1),
            scale: p.scale.clamped(to: minScale...maxScale)
        )
    }

    func center(
        _ item: PadItem,
        in canvas: CGSize,
        adaptation: CGFloat
    ) -> CGPoint {
        let p = placement(item)
        let halfWidth = min(
            canvas.width / 2,
            item.size.width * adaptation * p.scale / 2
        )
        let halfHeight = min(
            canvas.height / 2,
            item.size.height * adaptation * p.scale / 2
        )
        return CGPoint(
            x: (canvas.width * p.x).clamped(
                to: halfWidth...(canvas.width - halfWidth)
            ),
            y: (canvas.height * p.y).clamped(
                to: halfHeight...(canvas.height - halfHeight)
            )
        )
    }

    func move(
        _ item: PadItem,
        to point: CGPoint,
        in canvas: CGSize,
        adaptation: CGFloat
    ) {
        guard canvas.width > 0 && canvas.height > 0 else { return }
        let p = placement(item)
        let hw = min(
            canvas.width / 2,
            item.size.width * adaptation * p.scale / 2
        )
        let hh = min(
            canvas.height / 2,
            item.size.height * adaptation * p.scale / 2
        )
        custom[item.rawValue] = .init(
            x: Double(
                point.x.clamped(to: hw...(canvas.width - hw))
                / canvas.width
            ),
            y: Double(
                point.y.clamped(to: hh...(canvas.height - hh))
                / canvas.height
            ),
            scale: p.scale
        )
    }

    func resize(_ item: PadItem, to scale: Double) {
        var p = placement(item)
        p.scale = scale.clamped(to: minScale...maxScale)
        custom[item.rawValue] = p
        save()
    }

    func resetSelected() {
        guard let selected else { return }
        custom.removeValue(forKey: selected.rawValue)
        save()
    }

    func resetAll() {
        custom.removeAll()
        selected = nil
        save()
    }

    func save() {
        if let bytes = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(bytes, forKey: key)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
