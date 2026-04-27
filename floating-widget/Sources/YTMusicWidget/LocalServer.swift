import Foundation
import Network

/// Servidor HTTP mínimo (puerto 23567) que recibe estado de la extensión Chrome
/// y despacha comandos de regreso.
final class LocalServer {

    private var listener: NWListener?
    private var commandQueue: [String] = []
    private let lock = NSLock()

    var onStateReceived:  ((PlayerStateData, Bool) -> Void)?  // data, trackChanged
    private let serverQueue = DispatchQueue(label: "com.ytwidget.server", qos: .userInitiated)

    // MARK: – Start

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: 23567)
        } catch {
            print("[Server] Error creando listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:   print("[Server] Escuchando en :23567")
            case .failed(let e): print("[Server] Fallo: \(e)")
            default: break
            }
        }
        listener?.start(queue: serverQueue)
    }

    // MARK: – Command queue

    func enqueue(command: String) {
        lock.lock(); defer { lock.unlock() }
        commandQueue.append(command)
    }

    // MARK: – Connection handling

    private func handle(_ conn: NWConnection) {
        conn.start(queue: serverQueue)
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self, let data, !data.isEmpty, error == nil else {
                conn.cancel(); return
            }
            self.route(data: data, conn: conn)
        }
    }

    // MARK: – Routing

    private func route(data: Data, conn: NWConnection) {
        guard let raw = String(data: data, encoding: .utf8) else {
            respond(conn, status: 400, body: "Bad Request"); return
        }

        // Primera línea: "METHOD /path HTTP/1.1"
        let firstLine = raw.components(separatedBy: "\r\n").first ?? ""
        let parts     = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { respond(conn, status: 400, body: ""); return }
        let method = parts[0], path = parts[1]

        // Extraer body (después de \r\n\r\n)
        let body: String
        if let range = raw.range(of: "\r\n\r\n") {
            body = String(raw[range.upperBound...])
        } else {
            body = ""
        }

        switch (method, path) {

        // ── Ping de status ───────────────────────────────────────────────────
        case ("GET", "/ping"):
            respond(conn, status: 200, body: #"{"ok":true}"#)

        // ── Extensión envía estado del reproductor ────────────────────────────
        case ("POST", "/state"):
            if let bodyData = body.data(using: .utf8),
               let stateData = try? JSONDecoder().decode(PlayerStateData.self, from: bodyData) {
                let changed = stateData.trackId != currentTrackId && !stateData.title.isEmpty
                if changed { currentTrackId = stateData.trackId }
                onStateReceived?(stateData, changed)
            }
            respond(conn, status: 200, body: #"{"ok":true}"#)

        // ── Widget solicita comandos pendientes ───────────────────────────────
        case ("GET", "/command"):
            lock.lock()
            let cmds = commandQueue
            commandQueue.removeAll()
            lock.unlock()
            let json = #"{"commands":["# + cmds.map { "\"\($0)\"" }.joined(separator: ",") + "]}"
            respond(conn, status: 200, body: json)

        // ── CORS preflight ────────────────────────────────────────────────────
        case ("OPTIONS", _):
            respond(conn, status: 200, body: "")

        default:
            respond(conn, status: 404, body: #"{"error":"not found"}"#)
        }
    }

    // ── Track tracking ────────────────────────────────────────────────────────
    private var currentTrackId = ""

    // MARK: – HTTP response

    private func respond(_ conn: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        default:  statusText = "Unknown"
        }

        let response = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: application/json",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Content-Length: \(body.utf8.count)",
            "Connection: close",
            "",
            body
        ].joined(separator: "\r\n")

        conn.send(content: response.data(using: .utf8),
                  completion: .contentProcessed { _ in conn.cancel() })
    }
}
