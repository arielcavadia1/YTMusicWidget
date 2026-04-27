import SwiftUI

// ─── Widget View (estilo macOS Now Playing) ───────────────────────────────────

struct WidgetView: View {
    @ObservedObject var state: PlayerStateModel
    var onAction:        (String) -> Void
    var onResize:        ((CGFloat) -> Void)?
    var onHoverChanged:  ((Bool) -> Void)?
    var onSeek:          ((Double) -> Void)?

    @State private var albumImage:     NSImage? = nil
    @State private var dominantColor:  Color    = Color(red: 0.85, green: 0.1, blue: 0.25)
    @State private var dragStartWidth: CGFloat  = 0
    @State private var isResizing:     Bool     = false
    @State private var isSeeking:      Bool     = false
    @State private var seekProgress:   CGFloat  = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ── Fondo glass ───────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: SettingsManager.shared.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [dominantColor.opacity(0.18), Color.black.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: SettingsManager.shared.cornerRadius))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsManager.shared.cornerRadius)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: dominantColor.opacity(0.3), radius: 20, x: 0, y: 6)

            // ── Layout principal ──────────────────────────────────────────────
            HStack(alignment: .center, spacing: 14) {
                albumArtView
                contentColumn
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            // ── Handle resize ─────────────────────────────────────────────────
            resizeHandle.padding(5)
        }
        .environment(\.colorScheme, .dark)
        .onHover         { onHoverChanged?($0) }
        .onChange(of: state.albumArt) { _, new in loadAlbumArt(new) }
        .onAppear        { loadAlbumArt(state.albumArt) }
    }

    // MARK: – Album Art

    private var albumArtView: some View {
        Group {
            if let img = albumImage {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [dominantColor.opacity(0.7), dominantColor.opacity(0.35)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: dominantColor.opacity(0.5), radius: 8, x: 0, y: 3)
        .animation(.spring(duration: 0.45), value: albumImage)
    }

    // MARK: – Content column

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Título
            Text(state.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.3), value: state.title)

            Text(state.artist.isEmpty ? "YouTube Music" : state.artist)
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.3), value: state.artist)

            // Barra de progreso
            progressSection
                .padding(.top, 8)

            // Controles
            controlsRow
                .padding(.top, 6)
        }
    }

    // MARK: – Progress

    private var progressSection: some View {
        let displayProgress = isSeeking ? seekProgress
                              : (state.duration > 0 ? CGFloat(state.currentTime / state.duration) : 0)
        let elapsed   = state.timeText.isEmpty  ? formatTime(state.currentTime) : state.timeText
        let remaining = "-" + (state.totalText.isEmpty
                        ? formatTime(max(0, state.duration - state.currentTime))
                        : state.totalText)

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.13)).frame(height: 3)
                    Capsule()
                        .fill(LinearGradient(colors: [dominantColor, dominantColor.opacity(0.65)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, geo.size.width * displayProgress), height: 3)
                        .animation(isSeeking ? .none : .linear(duration: 0.9), value: displayProgress)
                    Circle()
                        .fill(.white)
                        .frame(width: isSeeking ? 12 : 8, height: isSeeking ? 12 : 8)
                        .shadow(color: dominantColor.opacity(0.7), radius: 3)
                        .offset(x: max(0, geo.size.width * displayProgress - (isSeeking ? 6 : 4)))
                        .animation(isSeeking ? .none : .linear(duration: 0.9), value: displayProgress)
                        .scaleEffect(isSeeking ? 1.2 : 1.0)
                        .animation(.spring(duration: 0.15), value: isSeeking)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { val in
                            isSeeking    = true
                            seekProgress = max(0, min(1, val.location.x / geo.size.width))
                        }
                        .onEnded { val in
                            let pos = max(0, min(1, val.location.x / geo.size.width))
                            seekProgress = pos
                            onSeek?(Double(pos))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                isSeeking = false
                            }
                        }
                )
            }
            .frame(height: 22) // área de toque generosa

            HStack {
                Text(elapsed)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(remaining)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: – Controls row

    private var controlsRow: some View {
        HStack(spacing: 0) {
            // Controles principales — centrados
            HStack(spacing: 6) {
                CtrlBtn(icon: "backward.fill",   tip: "Anterior",  size: 14)  { onAction("prev") }
                CtrlBtn(icon: state.isPlaying ? "pause.fill" : "play.fill",
                        tip: state.isPlaying ? "Pausar" : "Reproducir",
                        size: 20, highlight: true)                              { onAction("play_pause") }
                CtrlBtn(icon: "forward.fill",    tip: "Siguiente", size: 14)  { onAction("next") }
            }

            Spacer()

            // Controles secundarios
            HStack(spacing: 2) {
                CtrlBtn(icon: state.isLiked ? "heart.fill" : "heart",
                        tip: "Me gusta",
                        active: state.isLiked,
                        activeColor: Color(red: 1, green: 0.22, blue: 0.35)) { onAction("like") }
                CtrlBtn(icon: "repeat", tip: "Repetir",
                        active: state.repeatMode != "NONE",
                        activeColor: dominantColor)                           { onAction("repeat") }
                CtrlBtn(icon: "shuffle", tip: "Aleatorio",
                        active: state.isShuffled,
                        activeColor: dominantColor)                           { onAction("shuffle") }
            }
        }
    }

    // MARK: – Resize handle

    private var resizeHandle: some View {
        Canvas { ctx, size in
            let c = GraphicsContext.Shading.color(.white.opacity(isResizing ? 0.6 : 0.22))
            for i in 0..<3 {
                let o = CGFloat(i) * 4.5
                var p = Path(); p.move(to: CGPoint(x: size.width - o, y: 2)); p.addLine(to: CGPoint(x: 2, y: size.height - o))
                ctx.stroke(p, with: c, lineWidth: 1.2)
            }
        }
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { val in
                    if !isResizing { isResizing = true; dragStartWidth = SettingsManager.shared.widgetWidth }
                    onResize?(dragStartWidth + val.translation.width)
                }
                .onEnded { _ in isResizing = false; SettingsManager.shared.save() }
        )
        .help("Arrastra para cambiar el ancho")
    }

    // MARK: – Helpers

    private func loadAlbumArt(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { albumImage = nil; return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                withAnimation(.spring(duration: 0.5)) { self.albumImage = img }
                self.dominantColor = img.dominantSwiftUIColor()
            }
        }.resume()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// ─── Control Button ───────────────────────────────────────────────────────────

struct CtrlBtn: View {
    let icon:        String
    var tip:         String  = ""
    var size:        CGFloat = 14
    var highlight:   Bool    = false
    var active:      Bool    = false
    var activeColor: Color   = .white
    let action:      () -> Void

    @State private var hovered = false
    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(duration: 0.12)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation { pressed = false } }
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(active ? activeColor : (hovered ? .white : .white.opacity(0.72)))
                .frame(width: highlight ? 36 : 28, height: highlight ? 36 : 28)
                .background(Circle().fill(
                    highlight ? Color.white.opacity(hovered ? 0.22 : 0.12)
                              : (hovered ? Color.white.opacity(0.08) : Color.clear)
                ))
                .scaleEffect(pressed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .help(tip)
        .onHover { hovered = $0 }
    }
}

// ─── Dominant color ───────────────────────────────────────────────────────────

extension NSImage {
    func dominantSwiftUIColor() -> Color {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Color(red: 0.85, green: 0.1, blue: 0.25)
        }
        let ctx = CGContext(data: nil, width: 10, height: 10,
                            bitsPerComponent: 8, bytesPerRow: 40,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 10, height: 10))
        guard let data = ctx.data else { return Color(red: 0.85, green: 0.1, blue: 0.25) }
        let ptr = data.assumingMemoryBound(to: UInt8.self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        for i in 0..<100 { let b4 = i*4; r += CGFloat(ptr[b4])/255; g += CGFloat(ptr[b4+1])/255; b += CGFloat(ptr[b4+2])/255 }
        r /= 100; g /= 100; b /= 100
        let sat = max(r,g,b) > 0 ? (max(r,g,b) - min(r,g,b)) / max(r,g,b) : 0
        if sat < 0.18 { return Color(red: 0.85, green: 0.1, blue: 0.25) }
        return Color(red: r, green: g, blue: b)
    }
}
