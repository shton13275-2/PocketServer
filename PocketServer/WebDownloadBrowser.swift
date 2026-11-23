import SwiftUI
import WebKit

struct WebDownloadBrowser: UIViewRepresentable {
    @ObservedObject var server: ServerController
    let onSaved: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(server: server, onSaved: onSaved)
    }

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = web
        web.load(URLRequest(url: URL(string: "https://www.google.com")!))
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        let server: ServerController
        let onSaved: () -> Void
        weak var webView: WKWebView?
        private var downloadNames: [ObjectIdentifier: String] = [:]

        init(server: ServerController, onSaved: @escaping () -> Void) {
            self.server = server
            self.onSaved = onSaved
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + suggestedFilename)
            downloadNames[ObjectIdentifier(download)] = suggestedFilename
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let temp = downloadNames.removeValue(forKey: ObjectIdentifier(download)) else { return }
            // WKDownload saves to a UUID-prefixed temp path. Locate the matching file by
            // filename prefix in the temporary directory for the subsequent safe copy.
            let files = (try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
            guard let saved = files.first(where: { $0.lastPathComponent.contains(temp) }) else { return }
            Task { @MainActor in
                server.saveDownloadedFile(from: saved, suggestedName: temp)
                try? FileManager.default.removeItem(at: saved)
                onSaved()
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            Task { @MainActor in
                server.lastError = "ブラウザダウンロード失敗: \(error.localizedDescription)"
            }
        }
    }
}

struct InAppBrowserSheet: View {
    @ObservedObject var server: ServerController
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebDownloadBrowser(server: server, onSaved: onSaved)
                .navigationTitle("Webダウンロード")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
                }
        }
    }
}
