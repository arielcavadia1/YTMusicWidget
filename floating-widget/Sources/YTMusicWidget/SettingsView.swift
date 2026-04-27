import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    var onDismiss: () -> Void
    var onRebuild: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    dimensionsSection
                    behaviorSection
                    positionSection
                }
                .padding(20)
            }
            Divider().background(Color.white.opacity(0.08))
            footer
        }
        .frame(width: 500, alignment: .center)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .dark)
    }

    // MARK: – Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color(red:1,green:0.1,blue:0.35), Color(red:1,green:0.45,blue:0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: "music.note.tv.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("YTMusic Widget")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Ajustes del reproductor flotante")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: – Sections

    private var dimensionsSection: some View {
        SectionCard(title: "Dimensiones", icon: "rectangle.expand.vertical") {
            SliderRow(label: "Ancho del widget", value: $settings.widgetWidth,
                      range: 280...800, unit: "px")
            Divider().background(Color.white.opacity(0.06))
            SliderRow(label: "Alto del widget",  value: $settings.widgetHeight,
                      range: 90...600, unit: "px")
            Divider().background(Color.white.opacity(0.06))
            SliderRow(label: "Radio de esquinas", value: $settings.cornerRadius,
                      range: 8...40, unit: "pt")
        }
    }

    private var behaviorSection: some View {
        SectionCard(title: "Comportamiento", icon: "timer") {
            SliderRow(label: "Duración visible",
                      value: Binding(get: { CGFloat(settings.displayDuration) },
                                     set: { settings.displayDuration = Double($0) }),
                      range: 2...20, unit: "s")
            Divider().background(Color.white.opacity(0.06))
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary).frame(width: 18)
                Text("Mostrar al cambiar canción").font(.callout)
                Spacer()
                Toggle("", isOn: $settings.showOnSongChange)
                    .toggleStyle(.switch).labelsHidden()
            }.padding(.vertical, 2)
            Divider().background(Color.white.opacity(0.06))
            // Launch at login
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundColor(.secondary).frame(width: 18)
                Text("Iniciar al encender el Mac")
                    .font(.callout)
                Spacer()
                Toggle("", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch).labelsHidden()
                    .onChange(of: settings.launchAtLogin) { _, enabled in
                        settings.applyLaunchAtLogin(enabled)
                    }
            }
            .padding(.vertical, 2)
        }
    }

    private var positionSection: some View {
        SectionCard(title: "Posición en pantalla", icon: "macwindow.on.rectangle") {
            VStack(spacing: 4) {
                ForEach(WidgetPosition.rows, id: \.first) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { pos in
                            PosCell(pos: pos, selected: settings.position == pos) {
                                withAnimation(.spring(duration: 0.2)) { settings.position = pos }
                            }
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: – Footer

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("Restablecer") {
                    settings.widgetWidth      = 380
                    settings.widgetHeight     = 110
                    settings.displayDuration  = 5
                    settings.cornerRadius     = 22
                    settings.position         = .topRight
                    settings.showOnSongChange = true
                    settings.save(); onRebuild()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button("Aplicar cambios") {
                    settings.save(); onRebuild(); onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1, green: 0.1, blue: 0.35))
                .controlSize(.regular)
            }

            // Crédito
            Text("Desarrollado por: @ariel.cavadia1")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: – SectionCard ─────────────────────────────────────────────────────────

struct SectionCard<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Encabezado de sección
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

            // Contenido
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: – SliderRow ───────────────────────────────────────────────────────────

struct SliderRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let unit:  String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundColor(.primary)
                .frame(minWidth: 140, alignment: .leading)

            Slider(value: $value, in: range)
                .accentColor(Color(red: 1, green: 0.1, blue: 0.35))

            Text("\(Int(value)) \(unit)")
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: – PosCell (celda del grid 3x3) ──────────────────────────────────────

struct PosCell: View {
    let pos:      WidgetPosition
    let selected: Bool
    let action:   () -> Void

    @State private var hovered = false

    private let accent = Color(red: 1, green: 0.1, blue: 0.35)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: pos.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(pos.label)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? accent.opacity(0.22)
                          : (hovered ? Color.white.opacity(0.08) : Color.white.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? accent.opacity(0.6) : Color.white.opacity(0.06),
                                  lineWidth: 1)
            )
            .foregroundColor(selected ? accent : (hovered ? .white : .secondary))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
