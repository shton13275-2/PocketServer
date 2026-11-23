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
            listener.newConnectionHandler = { connection in Self.handle(connection, on: self.queue) }
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

    func filesInStorage() -> [URL] {
        let folder = Self.storageURL()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { !$0.hasDirectoryPath }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func importFiles(_ urls: [URL]) {
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
                guard (attributes[.type] as? FileAttributeType) == .typeRegular else {
                    lastError = "\(source.lastPathComponent): 通常のファイルのみ取り込めます"
                    continue
                }
                let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
                guard fileSize <= 25 * 1024 * 1024 else {
                    lastError = "\(source.lastPathComponent): 25 MBを超えるファイルは取り込めません"
                    continue
                }
                guard Self.isSafeFilename(source.lastPathComponent) else {
                    lastError = "\(source.lastPathComponent): 使用できないファイル名です"
                    continue
                }
                let destination = uniqueDestination(for: source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: destination)
                statusMessage = "取り込み完了: \(source.lastPathComponent)"
                lastError = nil
            } catch {
                lastError = "取り込み失敗: \(error.localizedDescription)"
            }
        }
    }

    func downloadFromURL(_ rawURL: String) async {
        guard let url = URL(string: rawURL), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else {
            lastError = "有効なHTTPまたはHTTPS URLを入力してください"
            statusMessage = "失敗"
            return
        }
        statusMessage = "ダウンロード中…"
        lastError = nil
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastError = "ダウンロード先がエラーを返しました (HTTP \(code))"
                statusMessage = "失敗"
                return
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard fileSize <= 25 * 1024 * 1024 else {
                lastError = "25 MBを超えるファイルは保存できません"
                statusMessage = "失敗"
                return
            }
            let rawSuggestedName = httpResponse.suggestedFilename ?? url.lastPathComponent
            let candidate = URL(fileURLWithPath: rawSuggestedName).lastPathComponent
            let suggestedName = candidate.isEmpty ? "download" : candidate
            let destination = uniqueDestination(for: suggestedName)
            try FileManager.default.copyItem(at: temporaryURL, to: destination)
            statusMessage = "ダウンロード完了: \(destination.lastPathComponent)"
        } catch {
            lastError = "ダウンロード失敗: \(error.localizedDescription)"
            statusMessage = "失敗"
        }
    }

    func reportDownloadError(_ message: String) {
        lastError = message
        statusMessage = "失敗"
    }

    func saveDownloadedFile(from temporaryURL: URL, suggestedName: String) {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            guard size <= 25 * 1024 * 1024 else {
                lastError = "25 MBを超えるファイルは保存できません"
                statusMessage = "失敗"
                return
            }
            let candidate = URL(fileURLWithPath: suggestedName).lastPathComponent
            let safeName = candidate.isEmpty ? "download" : candidate
            let destination = uniqueDestination(for: safeName)
            try FileManager.default.copyItem(at: temporaryURL, to: destination)
            statusMessage = "ダウンロード完了: \(destination.lastPathComponent)"
            lastError = nil
        } catch {
            lastError = "保存失敗: \(error.localizedDescription)"
            statusMessage = "失敗"
        }
    }

    func importSharedInbox() async {
        guard let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.jp.shton13275.pocketserver") else { return }
        let inbox = shared.appendingPathComponent("SharedInbox", isDirectory: true)
        guard let items = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }
        for item in items {
            if item.pathExtension.lowercased() == "urltxt" {
                let attrs = try? FileManager.default.attributesOfItem(atPath: item.path)
                let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                if size <= 4096, let raw = try? String(contentsOf: item, encoding: .utf8) {
                    await downloadFromURL(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    lastError = "共有URLが大きすぎるか読み取れません"
                }
                try? FileManager.default.removeItem(at: item)
                continue
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: item.path)
            let fileType = attrs?[.type] as? FileAttributeType
            let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
            guard fileType == .typeRegular, size <= 25 * 1024 * 1024, Self.isSafeFilename(item.lastPathComponent) else {
                lastError = "\(item.lastPathComponent): 25 MB超過または無効なファイル"
                try? FileManager.default.removeItem(at: item)
                continue
            }
            let prefixedName = item.lastPathComponent
            let originalName: String
            if prefixedName.count > 37, let _ = UUID(uuidString: String(prefixedName.prefix(36))), prefixedName.dropFirst(36).first == "-" {
                originalName = String(prefixedName.dropFirst(37))
            } else {
                originalName = prefixedName
            }
            guard Self.isSafeFilename(originalName) else {
                lastError = "共有ファイルの名前が無効です"
                try? FileManager.default.removeItem(at: item)
                continue
            }
            do {
                let dest = uniqueDestination(for: originalName)
                try FileManager.default.copyItem(at: item, to: dest)
                try FileManager.default.removeItem(at: item)
                statusMessage = "共有ファイルを取り込みました"
                lastError = nil
            } catch {
                lastError = "共有ファイル取り込み失敗: \(error.localizedDescription)"
            }
        }
    }

    func deleteLocalFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            lastError = nil
            statusMessage = "削除しました"
        } catch {
            lastError = "削除失敗: \(error.localizedDescription)"
        }
    }

    private func uniqueDestination(for originalName: String) -> URL {
        let safeName = originalName.isEmpty ? "file" : originalName
        let folder = Self.storageURL()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var destination = folder.appendingPathComponent(safeName)
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let nameURL = URL(fileURLWithPath: safeName)
            let base = nameURL.deletingPathExtension().lastPathComponent
            let ext = nameURL.pathExtension
            let nextName = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            destination = folder.appendingPathComponent(nextName)
            index += 1
        }
        return destination
    }

    nonisolated private static func handle(_ connection: NWConnection, on queue: DispatchQueue) {
        connection.start(queue: queue)
        receiveRequest(connection, accumulated: Data(), on: queue)
    }

    nonisolated private static func receiveRequest(_ connection: NWConnection, accumulated: Data, on queue: DispatchQueue) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            guard error == nil, let data, !data.isEmpty else {
                if isComplete { connection.cancel() }
                return
            }
            var all = accumulated
            all.append(data)
            guard all.count <= 27 * 1024 * 1024 else {
                send(status: "413 Payload Too Large", body: Data("Request too large".utf8), contentType: "text/plain", on: connection)
                return
            }
            guard let headerEnd = all.range(of: Data("\r
\r
".utf8)) else {
                receiveRequest(connection, accumulated: all, on: queue)
                return
            }
            let headerData = all.subdata(in: 0..<headerEnd.lowerBound)
            guard let headerText = String(data: headerData, encoding: .utf8) else {
                send(status: "400 Bad Request", body: Data("Bad headers".utf8), contentType: "text/plain", on: connection)
                return
            }
            let headerLines = headerText.components(separatedBy: "\r
")
            guard let requestLine = headerLines.first else {
                send(status: "400 Bad Request", body: Data("Bad request".utf8), contentType: "text/plain", on: connection)
                return
            }
            let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
            guard requestParts.count >= 2 else {
                send(status: "400 Bad Request", body: Data("Bad request".utf8), contentType: "text/plain", on: connection)
                return
            }
            let method = String(requestParts[0])
            let target = String(requestParts[1])
            let contentLength = headerLines.compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, parts[0].lowercased() == "content-length" else { return nil }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }.first ?? 0
            guard contentLength >= 0, contentLength <= 26 * 1024 * 1024 else {
                send(status: "413 Payload Too Large", body: Data("Request too large".utf8), contentType: "text/plain", on: connection)
                return
            }
            let bodyStart = headerEnd.upperBound
            let receivedBody = all.count - bodyStart
            if receivedBody < contentLength {
                receiveRequest(connection, accumulated: all, on: queue)
                return
            }
            let body = all.subdata(in: bodyStart..<bodyStart + contentLength)
            route(method: method, target: target, headers: headerLines, body: body, on: connection)
        }
    }

    nonisolated private static func route(method: String, target: String, headers: [String], body: Data, on connection: NWConnection) {
        if method == "GET", target == "/" || target == "/index.html" {
            send(status: "200 OK", body: Data(fileListHTML().utf8), contentType: "text/html; charset=utf-8", on: connection)
            return
        }

        if method == "GET", target.hasPrefix("/download/") {
            let encodedName = String(target.dropFirst("/download/".count)).components(separatedBy: "?").first ?? ""
            guard let name = encodedName.removingPercentEncoding, isSafeFilename(name) else {
                send(status: "400 Bad Request", body: Data("Invalid filename".utf8), contentType: "text/plain", on: connection)
                return
            }
            let fileURL = storageURL().appendingPathComponent(name, isDirectory: false)
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true, let fileData = try? Data(contentsOf: fileURL),
                  fileData.count <= 25 * 1024 * 1024 else {
                send(status: "404 Not Found", body: Data("File not found or exceeds 25 MB limit".utf8), contentType: "text/plain", on: connection)
                return
            }
            let mime = mimeType(for: name)
            send(status: "200 OK", body: fileData, contentType: mime, extraHeaders: "Content-Disposition: attachment; filename*=UTF-8''\(encodedName)", on: connection)
            return
        }

        if method == "POST", target == "/upload" {
            guard let contentType = headers.first(where: { $0.lowercased().hasPrefix("content-type:") })?.components(separatedBy: ":").dropFirst().joined().trimmingCharacters(in: .whitespaces),
                  let boundaryRange = contentType.range(of: "boundary=") else {
                send(status: "400 Bad Request", body: Data("Missing multipart boundary".utf8), contentType: "text/plain", on: connection)
                return
            }
            let boundary = String(contentType[boundaryRange.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard let upload = parseMultipart(body, boundary: boundary), isSafeFilename(upload.name), upload.data.count <= 25 * 1024 * 1024 else {
                send(status: "400 Bad Request", body: Data("Invalid upload or file exceeds 25 MB limit".utf8), contentType: "text/plain", on: connection)
                return
            }
            let folder = storageURL()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(upload.name)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                send(status: "409 Conflict", body: Data("File already exists. Rename it and retry.".utf8), contentType: "text/plain", on: connection)
                return
            }
            do {
                try upload.data.write(to: destination, options: .atomic)
                send(status: "303 See Other", body: Data("Uploaded".utf8), contentType: "text/plain", extraHeaders: "Location: /", on: connection)
            } catch {
                send(status: "500 Internal Server Error", body: Data("Could not save file".utf8), contentType: "text/plain", on: connection)
            }
            return
        }

        if method == "POST", target.hasPrefix("/delete/") {
            let encodedName = String(target.dropFirst("/delete/".count)).components(separatedBy: "?").first ?? ""
            guard let name = encodedName.removingPercentEncoding, isSafeFilename(name) else {
                send(status: "400 Bad Request", body: Data("Invalid filename".utf8), contentType: "text/plain", on: connection)
                return
            }
            let fileURL = storageURL().appendingPathComponent(name)
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true else {
                send(status: "404 Not Found", body: Data("File not found".utf8), contentType: "text/plain", on: connection)
                return
            }
            do {
                try FileManager.default.removeItem(at: fileURL)
                send(status: "303 See Other", body: Data("Deleted".utf8), contentType: "text/plain", extraHeaders: "Location: /", on: connection)
            } catch {
                send(status: "500 Internal Server Error", body: Data("Delete failed".utf8), contentType: "text/plain", on: connection)
            }
            return
        }

        send(status: (method == "GET" || method == "POST") ? "404 Not Found" : "405 Method Not Allowed", body: Data("Not found".utf8), contentType: "text/plain", on: connection)
    }

    private struct MultipartFile {
        let name: String
        let data: Data
    }

    nonisolated private static func parseMultipart(_ body: Data, boundary: String) -> MultipartFile? {
        guard !boundary.isEmpty else { return nil }
        let headerSeparator = Data("\r
\r
".utf8)
        let bodyBoundary = Data("\r
--\(boundary)".utf8)
        guard let separator = body.range(of: headerSeparator),
              let nextBoundary = body.range(of: bodyBoundary, in: separator.upperBound..<body.count) else { return nil }
        let headerText = String(data: body.subdata(in: 0..<separator.lowerBound), encoding: .utf8) ?? ""
        guard let disposition = headerText.components(separatedBy: "\r
").first(where: { $0.lowercased().hasPrefix("content-disposition:") }),
              let fileNameToken = disposition.range(of: "filename=\""),
              let endQuote = disposition[fileNameToken.upperBound...].firstIndex(of: "\"") else { return nil }
        let rawName = String(disposition[fileNameToken.upperBound..<endQuote])
        let decodedName = rawName.removingPercentEncoding ?? rawName
        let fileData = body.subdata(in: separator.upperBound..<nextBoundary.lowerBound)
        return MultipartFile(name: decodedName, data: fileData)
    }

    nonisolated private static func fileListHTML() -> String {
        let folder = storageURL()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        let rows = files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true, isSafeFilename(url.lastPathComponent) else { return nil }
            let safeName = htmlEscape(url.lastPathComponent)
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            let encoded = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let size = ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
            return "<li><span>\(safeName) <small>(\(size))</small></span><div class=\"actions\"><a href=\"/download/\(encoded)\">ダウンロード</a><form method=\"post\" action=\"/delete/\(encoded)\" onsubmit=\"return confirm('このファイルを削除しますか？')\"><button type=\"submit\">削除</button></form></div></li>"
        }.joined()
        let empty = files.isEmpty ? "<p class=\"empty\">保存ファイルはまだありません。</p>" : ""
        return """
        <!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>PocketServer ファイル一覧</title><style>
        body{font-family:system-ui,sans-serif;max-width:760px;margin:24px auto;padding:0 16px;background:#f5f6f8;color:#17202b}
        h1{font-size:1.6rem}ul{padding:0;list-style:none}li{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px;margin:8px 0;background:white;border-radius:12px;overflow-wrap:anywhere}
        a{color:#0878d1;text-decoration:none;white-space:nowrap}.actions{display:flex;align-items:center;gap:12px}button{border:0;background:#fff0f0;color:#c22;padding:8px 12px;border-radius:8px;font:inherit;cursor:pointer}
        .empty{color:#667085;padding:20px}small{color:#667085}.note{color:#667085;font-size:.9rem}
        .upload{background:white;border-radius:12px;padding:16px;margin:18px 0}.upload input{max-width:100%;margin:10px 0}.upload button{background:#0878d1;color:white}
        </style></head><body><h1>PocketServer</h1><p>iPhone内の共有フォルダ</p>
        <section class="upload"><h2>ファイルをアップロード</h2><form method="post" action="/upload" enctype="multipart/form-data"><input type="file" name="file" required><br><button type="submit">アップロード</button><p class="note">最大25 MB。重複するファイル名は上書きしません。</p></form></section>
        \(empty)<ul>\(rows)</ul><p class="note">同じWi-Fi内で利用してください。認証機能は未実装です。</p></body></html>
        """
    }

    nonisolated private static func storageURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("PocketServerFiles", isDirectory: true)
    }

    nonisolated private static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.contains("\0") && name.utf8.count <= 240
    }

    nonisolated private static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
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
        let header = "HTTP/1.1 \(status)\r
Content-Type: \(contentType)\r
Content-Length: \(body.count)\r
\(extraHeaders.isEmpty ? "" : extraHeaders + "\r
")Connection: close\r
\r
"
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
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET), String(cString: interface.ifa_name) == "en0" else { continue }
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
