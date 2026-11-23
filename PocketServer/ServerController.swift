import Foundation
import Combine
import Network

@MainActor
final class ServerController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "停止中"
    @Published private(set) var localAddress: String?
    @Published private(set) var lastError: String?

    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let queue = DispatchQueue(label: "PocketServer.HTTPServer")

    var serverURL: String? {
        guard isRunning, let localAddress else { return nil }
        return "http://\(localAddress):\(port)"
    }

    func start() {
        guard listener == nil else { return }
        lastError = nil
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.statusMessage = "起動中"
                        self?.localAddress = Self.wifiIPv4Address()
                    case .failed(let error):
                        self?.lastError = error.localizedDescription
                        self?.statusMessage = "エラー"
                        self?.isRunning = false
                        self?.listener?.cancel()
                        self?.listener = nil
                    case .cancelled:
                        self?.isRunning = false
                        self?.statusMessage = "停止中"
                        self?.localAddress = nil
                    default:
                        break
                    }
                }
            }
            listener.newConnectionHandler = { connection in
                Self.handle(connection, on: self.queue)
            }
            listener.start(queue: queue)
            statusMessage = "起動処理中"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "起動失敗"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        statusMessage = "停止中"
        localAddress = nil
    }

    nonisolated private static func handle(_ connection: NWConnection, on queue: DispatchQueue) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, error in
            guard error == nil, let data, !data.isEmpty,
                  let request = String(data: data, encoding: .utf8),
                  let requestLine = request.components(separatedBy: "\r\n").first else {
                connection.cancel()
                return
            }

            let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else {
                send(status: "400 Bad Request", body: Data("Bad request".utf8), contentType: "text/plain", on: connection)
                return
            }
            let method = String(parts[0])
            let target = String(parts[1])
            guard method == "GET" else {
                send(status: "405 Method Not Allowed", body: Data("Method not allowed".utf8), contentType: "text/plain", on: connection)
                return
            }

            if target == "/" || target == "/index.html" {
                let html = fileListHTML()
                send(status: "200 OK", body: Data(html.utf8), contentType: "text/html; charset=utf-8", on: connection)
                return
            }

            if target.hasPrefix("/download/") {
                let encodedName = String(target.dropFirst("/download/".count)).components(separatedBy: "?").first ?? ""
                guard let name = encodedName.removingPercentEncoding, isSafeFilename(name) else {
                    send(status: "400 Bad Request", body: Data("Invalid filename".utf8), contentType: "text/plain", on: connection)
                    return
                }
                let fileURL = storageURL().appendingPathComponent(name, isDirectory: false)
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true,
                      let fileData = try? Data(contentsOf: fileURL),
                      fileData.count <= 25 * 1024 * 1024 else {
                    send(status: "404 Not Found", body: Data("File not found or exceeds 25 MB limit".utf8), contentType: "text/plain", on: connection)
                    return
                }
                let mime = mimeType(for: name)
                send(status: "200 OK", body: fileData, contentType: mime, extraHeaders: "Content-Disposition: attachment; filename*=UTF-8''\(encodedName)", on: connection)
                return
            }

            send(status: "404 Not Found", body: Data("Not found".utf8), contentType: "text/plain", on: connection)
        }
    }

    nonisolated private static func fileListHTML() -> String {
        let directory = storageURL()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        let rows = files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true,
                  isSafeFilename(url.lastPathComponent) else { return nil }
            let name = htmlEscape(url.lastPathComponent)
            let encoded = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? ""
            let size = ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
            return "<li><span>\(name) <small>(\(size))</small></span><a href=\"/download/\(encoded)\">ダウンロード</a></li>"
        }.joined()
        let empty = files.isEmpty ? "<p class=\"empty\">保存ファイルはまだありません。</p>" : ""
        return """
        <!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>PocketServer ファイル一覧</title><style>
        body{font-family:system-ui,sans-serif;max-width:760px;margin:24px auto;padding:0 16px;background:#f5f6f8;color:#17202b}
        h1{font-size:1.6rem}ul{padding:0;list-style:none}li{display:flex;justify-content:space-between;gap:12px;padding:14px;margin:8px 0;background:white;border-radius:12px;overflow-wrap:anywhere}
        a{color:#0878d1;text-decoration:none;white-space:nowrap}.empty{color:#667085;padding:20px}
        small{color:#667085}.note{color:#667085;font-size:.9rem}
        </style></head><body><h1>PocketServer</h1><p>iPhone内の共有フォルダ</p>\(empty)<ul>\(rows)</ul>
        <p class="note">現在はファイル一覧とダウンロードのみ対応。アップロード・削除機能は未実装です。</p></body></html>
        """
    }

    nonisolated private static func storageURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("PocketServerFiles", isDirectory: true)
    }

    nonisolated private static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." &&
        !name.contains("/") && !name.contains("\\") &&
        !name.contains("\0") && name.utf8.count <= 240
    }

    nonisolated private static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    nonisolated private static func mimeType(for filename: String) -> String {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "txt": return "text/plain; charset=utf-8"
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4": return "video/mp4"
        case "zip": return "application/zip"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }

    nonisolated private static func send(status: String, body: Data, contentType: String, extraHeaders: String = "", on connection: NWConnection) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\n\(extraHeaders.isEmpty ? "" : extraHeaders + "\r\n")Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func wifiIPv4Address() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            guard String(cString: interface.ifa_name) == "en0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            if result == 0 {
                let address = String(cString: hostname)
                if !address.isEmpty && address != "127.0.0.1" { return address }
            }
        }
        return nil
    }
}
