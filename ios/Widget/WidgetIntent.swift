import AppIntents
import MinehutKit
import WidgetKit

enum ListKindOption: String, AppEnum {
    case rising
    case top

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "List" }
    static var caseDisplayRepresentations: [ListKindOption: DisplayRepresentation] {
        [.rising: "Rising", .top: "Top"]
    }

    var kind: WidgetListKind { self == .top ? .top : .rising }
}

enum WindowOption: String, AppEnum {
    case oneHour = "1h"
    case sixHours = "6h"
    case day = "24h"

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Window" }
    static var caseDisplayRepresentations: [WindowOption: DisplayRepresentation] {
        [.oneHour: "1 hour", .sixHours: "6 hours", .day: "24 hours"]
    }

    var risingWindow: RisingWindow {
        switch self {
        case .oneHour: return .oneHour
        case .sixHours: return .sixHours
        case .day: return .day
        }
    }
}

struct MinehutWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Minehut Analytics" }
    static var description: IntentDescription { "Rising or top Minehut servers." }

    @Parameter(title: "List", default: .rising)
    var list: ListKindOption

    @Parameter(title: "Window", description: "Only used for Rising.", default: .day)
    var window: WindowOption
}
