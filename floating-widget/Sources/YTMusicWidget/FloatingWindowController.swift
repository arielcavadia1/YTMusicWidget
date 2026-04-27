import AppKit
import SwiftUI

final class FloatingWindowController {

    private var panel:           NSPanel?
    private var hideTimer:       Timer?
    private var isHovered:       Bool    = false
    private let settings       = SettingsManager.shared
    private let state:           PlayerStateModel

    init(state: PlayerStateModel) { self.state = state }

    // MARK: – Build panel

    private func makePanel() -> NSPanel {
        let s     = settings
        let frame = frameFor(s.position, w: s.widgetWidth, h: s.widgetHeight)

        let p = NSPanel(contentRect: frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level               = .floating
        p.backgroundColor     = .clear
        p.isOpaque            = false
        p.hasShadow           = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior  = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.alphaValue          = 0

        let root = WidgetView(
            state:          state,
            onAction:       { [weak self] a   in self?.handleAction(a) },
            onResize:       { [weak self] w   in self?.resizeTo(width: w) },
            onHoverChanged: { [weak self] h   in self?.handleHover(h) },
            onSeek:         { [weak self] pos in self?.handleSeek(pos) }
        )
        p.contentView = NSHostingView(rootView: root)
        return p
    }

    // MARK: – Show / Hide / Toggle

    func show(trackChanged: Bool = false) {
        if panel == nil { panel = makePanel() }

        let frame = frameFor(settings.position, w: settings.widgetWidth, h: settings.widgetHeight)
        panel?.setFrame(frame, display: false)

        guard let panel else { return }
        if panel.alphaValue > 0 { scheduleHide(); return }

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        scheduleHide()
    }

    func hide(animated: Bool = true) {
        hideTimer?.invalidate(); hideTimer = nil
        guard let panel, panel.alphaValue > 0 else { return }
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: { panel.orderOut(nil) })
        } else {
            panel.alphaValue = 0; panel.orderOut(nil)
        }
    }

    func toggle() {
        if let p = panel, p.alphaValue > 0 { hide() } else { show() }
    }

    func rebuild() { hide(animated: false); panel = nil }

    // MARK: – Hover: pausar/reanudar el timer

    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        if hovering {
            // Mientras el cursor está encima, cancela el auto-hide
            hideTimer?.invalidate()
            hideTimer = nil
        } else {
            // Cuando el cursor sale, reinicia el countdown
            scheduleHide()
        }
    }

    // MARK: – Visual resize (solo ancho → alto se adapta)

    func resizeTo(width newWidth: CGFloat) {
        guard let panel else { return }

        // Límites de ancho
        let w = max(280, min(800, newWidth))

        // 1. Ajustar ancho del panel
        var frame  = panel.frame
        let topY   = frame.maxY
        frame.size.width = w
        panel.setFrame(frame, display: true, animate: false)

        // 2. Dejar que SwiftUI calcule el alto natural para ese ancho
        let naturalH: CGFloat
        if let cv = panel.contentView {
            let fitting = cv.fittingSize
            naturalH = fitting.height > 0 ? fitting.height : settings.widgetHeight
        } else {
            naturalH = settings.widgetHeight
        }

        // Límites de alto
        let h = max(90, min(600, naturalH))

        // 3. Aplicar alto calculado
        frame.size.height = h
        frame.origin.y    = topY - h
        panel.setFrame(frame, display: true, animate: false)

        settings.widgetWidth  = w
        settings.widgetHeight = h
    }

    // MARK: – Auto-hide timer

    private func scheduleHide() {
        guard !isHovered else { return }  // no programar si cursor encima
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: settings.displayDuration,
                                          repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    // MARK: – Actions

    private func handleAction(_ action: String) {
        scheduleHide()
        LocalServerBridge.shared.enqueue(action)
    }

    private func handleSeek(_ position: Double) {
        scheduleHide()
        LocalServerBridge.shared.enqueue(String(format: "seek:%.4f", position))
    }

    // MARK: – Frame calculation (9 posiciones)

    func frameFor(_ pos: WidgetPosition, w: CGFloat, h: CGFloat) -> NSRect {
        guard let sf = NSScreen.main?.visibleFrame else {
            return NSRect(x: 100, y: 100, width: w, height: h)
        }
        let m: CGFloat = 20
        let x: CGFloat
        let y: CGFloat

        switch pos {
        case .topLeft:      x = sf.minX + m;     y = sf.maxY - h - m
        case .topCenter:    x = sf.midX - w / 2; y = sf.maxY - h - m
        case .topRight:     x = sf.maxX - w - m; y = sf.maxY - h - m
        case .centerLeft:   x = sf.minX + m;     y = sf.midY - h / 2
        case .center:       x = sf.midX - w / 2; y = sf.midY - h / 2
        case .centerRight:  x = sf.maxX - w - m; y = sf.midY - h / 2
        case .bottomLeft:   x = sf.minX + m;     y = sf.minY + m
        case .bottomCenter: x = sf.midX - w / 2; y = sf.minY + m
        case .bottomRight:  x = sf.maxX - w - m; y = sf.minY + m
        }
        return NSRect(x: x, y: y, width: w, height: h)
    }
}

// Singleton bridge
final class LocalServerBridge {
    static let shared = LocalServerBridge()
    private init() {}
    var server: LocalServer?
    func enqueue(_ cmd: String) { server?.enqueue(command: cmd) }
}
