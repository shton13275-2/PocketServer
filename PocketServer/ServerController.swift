import Foundation
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
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
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

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, error in
            guard error == nil, let data, !data.isEmpty else {
                connection.cancel()
                return
            }
            let body = """
            <!doctype html><html lang="ja"><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>PocketServer</title>
            <body style="font-family:system-ui;padding:2rem">
            <h1>PocketServer</h1><p>HTTPサーバーは正常に応答しています。</p>
            <p>ファイル管理機能は次の開発段階で実装します。</p></body></html>
            """
            let responseBody = body.data(using: .utf8) ?? Data()
            let header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n"
            var response = header.data(using: .utf8) ?? Data()
            response.append(responseBody)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
            _ = self
        }
    }

    private static func wifiIPv4Address() -> String? {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            if result == 0 {
                let value = String(cString: hostname)
                if !value.isEmpty && value != "127.0.0.1" { addresses.append(value) }
            }
        }
        return addresses.first
    }
}
