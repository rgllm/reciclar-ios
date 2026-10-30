import ReciclarCore
import SwiftUI

enum WasteCategoryPresentation {
    static func title(for category: WasteCategory) -> String {
        switch RecyclingStream.classifying(name: category.name) {
        case .glass: "Vidro"
        case .paper: "Papel e cartão"
        case .packaging: "Embalagens"
        case nil: category.name
        }
    }

    static func color(for category: WasteCategory) -> Color {
        color(forID: category.id, token: nil, name: category.name)
    }

    static func color(for container: Container) -> Color {
        color(forID: container.category.id, token: container.colorToken, name: container.category.name)
    }

    static func symbol(for category: WasteCategory) -> String {
        if let stream = RecyclingStream.classifying(name: category.name) {
            return symbol(for: stream)
        }
        switch category.id.rawValue {
        case WasteCategory.sampleGlass.id.rawValue: return "wineglass"
        case WasteCategory.samplePaper.id.rawValue: return "newspaper"
        case WasteCategory.samplePackaging.id.rawValue: return "shippingbox"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    static func symbol(for chip: WasteFilterChip) -> String {
        switch chip.token {
        case .stream(let stream): symbol(for: stream)
        case .nameKey: "arrow.triangle.2.circlepath"
        }
    }

    static func symbol(for stream: RecyclingStream) -> String {
        switch stream {
        case .glass: "wineglass"
        case .paper: "newspaper.fill"
        case .packaging: "shippingbox.fill"
        }
    }

    private static func color(forID id: WasteCategory.ID, token: String?, name: String? = nil) -> Color {
        if let token, let hex = color(fromHex: token) {
            return hex
        }
        switch normalized(token) {
        case "verde": return Color(red: 0.18, green: 0.55, blue: 0.34)
        case "azul": return Color(red: 0.18, green: 0.38, blue: 0.72)
        case "amarelo": return Color(red: 0.90, green: 0.75, blue: 0.12)
        default:
            if let name, let stream = RecyclingStream.classifying(name: name) {
                return color(for: stream)
            }
            switch id.rawValue {
            case WasteCategory.sampleGlass.id.rawValue:
                return Color(red: 0.18, green: 0.55, blue: 0.34)
            case WasteCategory.samplePaper.id.rawValue:
                return Color(red: 0.18, green: 0.38, blue: 0.72)
            case WasteCategory.samplePackaging.id.rawValue:
                return Color(red: 0.90, green: 0.75, blue: 0.12)
            default:
                return Color.secondary
            }
        }
    }

    private static func color(for stream: RecyclingStream) -> Color {
        switch stream {
        case .glass: Color(red: 0.18, green: 0.55, blue: 0.34)
        case .paper: Color(red: 0.18, green: 0.38, blue: 0.72)
        case .packaging: Color(red: 0.90, green: 0.75, blue: 0.12)
        }
    }

    private static func color(fromHex token: String) -> Color? {
        var hex = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    private static func normalized(_ token: String?) -> String {
        token?.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT")) ?? ""
    }
}
