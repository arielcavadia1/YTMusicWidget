import AppKit

// Punto de entrada de la app macOS
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No aparece en el Dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
