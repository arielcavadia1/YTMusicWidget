import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let playerState   = PlayerStateModel()
    private var floatingCtrl: FloatingWindowController!
    private var server:       LocalServer!
    private var statusItem:   NSStatusItem!
    private var settingsWin:  NSWindow?
    private var clickTimer:   Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupServer()
        floatingCtrl = FloatingWindowController(state: playerState)
        setupStatusBar()
        print("[AppDelegate] YTMusic Widget listo 🎵")
    }

    // MARK: – Server

    private func setupServer() {
        server = LocalServer()
        LocalServerBridge.shared.server = server
        server.onStateReceived = { [weak self] data, trackChanged in
            guard let self else { return }
            self.playerState.update(from: data)
            if trackChanged && SettingsManager.shared.showOnSongChange {
                DispatchQueue.main.async { self.floatingCtrl.show(trackChanged: true) }
            }
        }
        server.start()
    }

    // MARK: – Status bar
    // • Clic izquierdo SIMPLE  → mostrar / ocultar widget
    // • Clic izquierdo DOBLE   → Ajustes
    // • Clic DERECHO           → menú contextual

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let btn = statusItem.button else { return }

        btn.image = NSImage(systemSymbolName: "music.note",
                            accessibilityDescription: "YTMusic Widget")
        btn.image?.isTemplate = true
        btn.action   = #selector(handleClick(_:))
        btn.target   = self
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // Sin menu asignado → gestionamos todo manualmente
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Clic derecho → menú
        if event.type == .rightMouseUp {
            showContextMenu(); return
        }

        // Doble clic → ajustes inmediatamente
        if event.clickCount >= 2 {
            clickTimer?.invalidate(); clickTimer = nil
            openSettings(); return
        }

        // Clic simple → esperar por si viene doble clic
        clickTimer?.invalidate()
        clickTimer = Timer.scheduledTimer(
            withTimeInterval: NSEvent.doubleClickInterval,
            repeats: false) { [weak self] _ in
                self?.floatingCtrl.toggle()
        }
    }

    // MARK: – Context menu (clic derecho)

    private func showContextMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Mostrar / Ocultar widget",
                                    action: #selector(toggleWidget), keyEquivalent: "m")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Ajustes…",
                                      action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Salir",
                                   action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleWidget() { floatingCtrl.toggle() }
    @objc private func quitApp()      { NSApplication.shared.terminate(nil) }

    // MARK: – Settings window

    @objc func openSettings() {
        if let win = settingsWin { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let view = SettingsView(
            onDismiss: { [weak self] in self?.settingsWin?.close() },
            onRebuild: { [weak self] in self?.floatingCtrl.rebuild() }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        win.title                      = "Ajustes — YTMusic Widget"
        win.titlebarAppearsTransparent = true
        win.contentView                = NSHostingView(rootView: view)
        win.isReleasedWhenClosed       = false
        win.delegate                   = self
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWin = win
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWin { settingsWin = nil }
    }
}
