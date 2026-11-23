import SwiftUI
import UniformTypeIdentifiers

@main
struct PocketServerShareExtension: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        ShareViewController()
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "PocketServerに共有中…"
        title.font = .preferredFont(forTextStyle: .headline)
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        processSharedItems()
    }

    private func processSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish("共有項目がありません")
            return
        }
        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            finish("共有項目がありません")
            return
        }
        let group = DispatchGroup()
        var savedCount = 0
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.jp.shton13275.PocketServer") else {
            finish("共有フォルダを利用できません")
            return
        }
        let inbox = base.appendingPathComponent("SharedInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        let file = inbox.appendingPathComponent(UUID().uuidString + ".urltxt")
                        try? url.absoluteString.write(to: file, atomically: true, encoding: .utf8)
                        savedCount += 1
                    }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, _ in
                    if let url {
                        let name = url.lastPathComponent
                        let destination = inbox.appendingPathComponent(UUID().uuidString + "-" + name)
                        try? FileManager.default.copyItem(at: url, to: destination)
                        savedCount += 1
                    }
                    group.leave()
                }
            } else if let type = provider.registeredTypeIdentifiers.first {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                    if let url {
                        let name = url.lastPathComponent.isEmpty ? "shared-file" : url.lastPathComponent
                        let destination = inbox.appendingPathComponent(UUID().uuidString + "-" + name)
                        try? FileManager.default.copyItem(at: url, to: destination)
                        savedCount += 1
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            self.finish(savedCount > 0 ? "共有を受け取りました。PocketServerを開いて「共有メニューから取り込む」を押してください。" : "共有ファイルを受け取れませんでした")
        }
    }

    private func finish(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
