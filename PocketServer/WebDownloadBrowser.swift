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
        private var downloadDestinations: [ObjectIdentifier: (URL, String)] = [:]

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
            guard let (savedURL, suggestedName) = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
            Task { @MainActor in
                server.saveDownloadedFile(from: savedURL, suggestedName: suggestedName)
                try? FileManager.default.removeItem(at: savedURL)
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
