import SwiftUI
import WebKit

struct WebDownloadBrowser: UIViewRepresentable {
    @ObservedObject var server: ServerController
    let url: URL
    let onSaved: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(server: server, onSaved: onSaved) }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = web
        context.coordinator.load(url)
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        let server: ServerController
        let onSaved: () -> Void
        weak var webView: WKWebView?
        private var lastURL: URL?
        private var downloadDestinations: [ObjectIdentifier: (URL, String)] = [:]

        init(server: ServerController, onSaved: @escaping () -> Void) {
            self.server = server
            self.onSaved = onSaved
        }

        func load(_ url: URL) {
            guard lastURL != url else { return }
            lastURL = url
            webView?.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let safeName = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + safeName)
            downloadDestinations[ObjectIdentifier(download)] = (destination, safeName)
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let (savedURL, filename) = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
            Task { @MainActor in
                server.saveDownloadedFile(from: savedURL, suggestedName: filename)
                try? FileManager.default.removeItem(at: savedURL)
                onSaved()
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
            Task { @MainActor in server.reportDownloadError("ブラウザダウンロード失敗: \(error.localizedDescription)") }
        }
    }
}

struct InAppBrowserSheet: View {
    @ObservedObject var server: ServerController
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = "https://www.google.com"
    @State private var currentURL = URL(string: "https://www.google.com")!

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack {
                    TextField("URLまたは検索語", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)
                    Button("移動") { navigate() }.buttonStyle(.borderedProminent)
                }.padding(.horizontal)
                WebDownloadBrowser(server: server, url: currentURL, onSaved: onSaved)
            }
            .navigationTitle("Webダウンロード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
            }
        }
    }

    private func navigate() {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let parsed = URL(string: text), let host = parsed.host, !host.isEmpty {
            currentURL = parsed.scheme == nil ? URL(string: "https://" + text)! : parsed
            address = currentURL.absoluteString
        } else {
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: text)]
            if let searchURL = components?.url { currentURL = searchURL }
        }
    }
}
