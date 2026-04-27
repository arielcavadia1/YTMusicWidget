import Foundation
import Combine

// ─── Struct Codable (para decodificar JSON de la extensión) ───────────────────

struct PlayerStateData: Codable {
    var title:       String
    var artist:      String
    var albumArt:    String
    var isPlaying:   Bool
    var isLiked:     Bool
    var repeatMode:  String
    var isShuffled:  Bool
    var currentTime: Double
    var duration:    Double
    var timeText:    String
    var totalText:   String
    var trackId:     String
}

// ─── Observable model (compartido con SwiftUI) ────────────────────────────────

final class PlayerStateModel: ObservableObject {
    @Published var title:       String = "Sin reproducción"
    @Published var artist:      String = ""
    @Published var albumArt:    String = ""
    @Published var isPlaying:   Bool   = false
    @Published var isLiked:     Bool   = false
    @Published var repeatMode:  String = "NONE"
    @Published var isShuffled:  Bool   = false
    @Published var currentTime: Double = 0
    @Published var duration:    Double = 0
    @Published var timeText:    String = ""
    @Published var totalText:   String = ""
    @Published var trackId:     String = ""

    /// Devuelve true si la canción cambió
    @discardableResult
    func update(from data: PlayerStateData) -> Bool {
        let changed = data.trackId != trackId && !data.title.isEmpty
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.title       = data.title.isEmpty ? "Sin reproducción" : data.title
            self.artist      = data.artist
            self.albumArt    = data.albumArt
            self.isPlaying   = data.isPlaying
            self.isLiked     = data.isLiked
            self.repeatMode  = data.repeatMode
            self.isShuffled  = data.isShuffled
            self.currentTime = data.currentTime
            self.duration    = data.duration
            self.timeText    = data.timeText
            self.totalText   = data.totalText
            self.trackId     = data.trackId
        }
        return changed
    }
}
