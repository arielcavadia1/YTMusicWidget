import Foundation
import ServiceManagement

enum WidgetPosition: String, CaseIterable {
    case topLeft      = "top-left"
    case topCenter    = "top-center"
    case topRight     = "top-right"
    case centerLeft   = "center-left"
    case center       = "center"
    case centerRight  = "center-right"
    case bottomLeft   = "bottom-left"
    case bottomCenter = "bottom-center"
    case bottomRight  = "bottom-right"

    var label: String {
        switch self {
        case .topLeft:      return "Arriba izq."
        case .topCenter:    return "Arriba"
        case .topRight:     return "Arriba der."
        case .centerLeft:   return "Izquierda"
        case .center:       return "Centro"
        case .centerRight:  return "Derecha"
        case .bottomLeft:   return "Abajo izq."
        case .bottomCenter: return "Abajo"
        case .bottomRight:  return "Abajo der."
        }
    }

    var sfSymbol: String {
        switch self {
        case .topLeft:      return "arrow.up.left"
        case .topCenter:    return "arrow.up"
        case .topRight:     return "arrow.up.right"
        case .centerLeft:   return "arrow.left"
        case .center:       return "circle.fill"
        case .centerRight:  return "arrow.right"
        case .bottomLeft:   return "arrow.down.left"
        case .bottomCenter: return "arrow.down"
        case .bottomRight:  return "arrow.down.right"
        }
    }

    static var rows: [[WidgetPosition]] {
        [[.topLeft,    .topCenter,    .topRight],
         [.centerLeft, .center,       .centerRight],
         [.bottomLeft, .bottomCenter, .bottomRight]]
    }
}

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var widgetWidth:      CGFloat = 380
    @Published var widgetHeight:     CGFloat = 110
    @Published var displayDuration:  Double  = 5.0
    @Published var position:         WidgetPosition = .topRight
    @Published var showOnSongChange: Bool    = true
    @Published var cornerRadius:     CGFloat = 22
    @Published var launchAtLogin:    Bool    = false

    private let defaults = UserDefaults.standard
    private init() { load() }

    func load() {
        widgetWidth     = CGFloat(defaults.double(forKey: "widgetWidth").nonZero  ?? 380)
        widgetHeight    = CGFloat(defaults.double(forKey: "widgetHeight").nonZero ?? 110)
        displayDuration = defaults.double(forKey: "displayDuration").nonZero      ?? 5.0
        cornerRadius    = CGFloat(defaults.double(forKey: "cornerRadius").nonZero ?? 22)
        showOnSongChange = defaults.object(forKey: "showOnSongChange") as? Bool   ?? true
        if let raw = defaults.string(forKey: "position"),
           let pos = WidgetPosition(rawValue: raw) { position = pos }
        // Leer estado real del sistema, no solo UserDefaults
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func save() {
        defaults.set(Double(widgetWidth),  forKey: "widgetWidth")
        defaults.set(Double(widgetHeight), forKey: "widgetHeight")
        defaults.set(displayDuration,      forKey: "displayDuration")
        defaults.set(Double(cornerRadius), forKey: "cornerRadius")
        defaults.set(showOnSongChange,     forKey: "showOnSongChange")
        defaults.set(position.rawValue,    forKey: "position")
    }

    /// Registra o desregistra la app como Login Item del sistema
    func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            print("[SettingsManager] LaunchAtLogin error: \(error)")
        }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
