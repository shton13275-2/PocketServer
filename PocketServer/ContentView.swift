import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var server = ServerController()
    @State private var showingImporter = false
    @State private var showingBrowser = false
    @State private var downloadURL = ""
    @State private var files: [URL] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)
                        Text("PocketServer").font(.largeTitle.bold())
                        Text("iPhoneをローカルファイルサーバーに")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 20)
                    serverCard
                    nativeFileTools
                    fileListCard
                    progressCard
                    Text("注意：認証機能は未実装です。信頼できるWi-Fi内でのみ使用し、使用後はサーバーを停止してください。")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }
            .navigationTitle("PocketServer").navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
            .task { await server.importSharedInbox(); refreshFiles() }
            .sheet(isPresented: $showingBrowser) {
                InAppBrowserSheet(server: server, onSaved: refreshFiles)
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let selectedURLs):
                    server.importFiles(selectedURLs)
                    refreshFiles()
                case .failure:
                    break
                }
            }
        }
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("サーバー", systemImage: "network").font(.headline)
            HStack(spacing: 8) {
                Circle().fill(server.isRunning ? .green : .gray).frame(width: 10, height: 10)
                Text(server.statusMessage).font(.headline)
            }
            if let url = server.serverURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("接続アドレス").font(.caption).foregroundStyle(.secondary)
                    Text(url).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    ShareLink(item: url) { Label("URLを共有", systemImage: "square.and.arrow.up") }
                }
            } else if server.isRunning {
                Text("IPアドレスを取得できません。Wi-Fi接続を確認してください。").font(.footnote).foregroundStyle(.secondary)
            }
            if let error = server.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
            Button {
                if server.isRunning || server.statusMessage == "起動処理中" { server.stop() } else { server.start() }
            } label: {
                Text(server.isRunning || server.statusMessage == "起動処理中" ? "サーバーを停止" : "サーバーを起動")
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }.pocketGlassButton(prominent: true).tint(server.isRunning ? .red : .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .pocketGlassCard(cornerRadius: 18)
    }

    private var nativeFileTools: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("ダウンロード・取り込み", systemImage: "folder.badge.plus").font(.headline)
            Button { showingImporter = true } label: {
                Label("「ファイル」から直接取り込む", systemImage: "folder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.pocketGlassButton()
            Button {
                Task { await server.importSharedInbox(); refreshFiles() }
            } label: {
                Label("共有メニューから取り込む", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.pocketGlassButton()
            Button { showingBrowser = true } label: {
                Label("アプリ内ブラウザでダウンロード", systemImage: "globe")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.pocketGlassButton(prominent: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("URLを直接入力").font(.subheadline.weight(.medium))
                TextField("https://example.com/file.zip", text: $downloadURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL).textFieldStyle(.roundedBorder)
                Button {
                    let input = downloadURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await server.downloadFromURL(input); refreshFiles() }
                } label: {
                    Label("URLからダウンロード", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }.pocketGlassButton()
                    .disabled(downloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("共有メニューからのファイルやURLも取り込めます。各ファイル最大25 MB。重複名は番号付きで保存します。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .pocketGlassCard(cornerRadius: 18)
    }

    private var fileListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("PocketServer内のファイル", systemImage: "folder").font(.headline)
                Spacer()
                Button(action: refreshFiles) { Image(systemName: "arrow.clockwise") }.accessibilityLabel("再読み込み")
            }
            if files.isEmpty {
                Text("保存ファイルはありません").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(files, id: \.self) { file in
                    HStack(spacing: 10) {
                        Image(systemName: "doc").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.lastPathComponent).lineLimit(2).textSelection(.enabled)
                            Text(fileSize(file)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShareLink(item: file) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .pocketGlassIconButton()
                        .accessibilityLabel("ファイルを書き出す・ダウンロード")

                        Button(role: .destructive) {
                            server.deleteLocalFile(file)
                            refreshFiles()
                        } label: { Image(systemName: "trash") }
                            .pocketGlassIconButton().accessibilityLabel("削除")
                    }
                    if file != files.last { Divider() }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .pocketGlassCard(cornerRadius: 18)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("機能", systemImage: "checklist").font(.headline)
            FeatureRow(title: "ブラウザでファイル一覧・ダウンロード", icon: "folder", completed: true)
            FeatureRow(title: "ブラウザからアップロード", icon: "arrow.up.doc", completed: true)
            FeatureRow(title: "ブラウザから削除", icon: "trash", completed: true)
            FeatureRow(title: "「ファイル」から取り込み", icon: "square.and.arrow.down", completed: true)
            FeatureRow(title: "URLダウンロード・アプリ内ブラウザ", icon: "link", completed: true)
            FeatureRow(title: "共有メニューから取り込み", icon: "square.and.arrow.down", completed: true)
            FeatureRow(title: "パスワード保護", icon: "lock", completed: false)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .pocketGlassCard(cornerRadius: 18)
    }

    private func refreshFiles() { files = server.filesInStorage() }
    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct FeatureRow: View {
    let title: String
    let icon: String
    let completed: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(completed ? Color.green : Color.accentColor).frame(width: 22)
            Text(title)
            Spacer()
            Image(systemName: completed ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(completed ? Color.green : Color.secondary)
        }.font(.subheadline)
    }
}
#Preview { ContentView() }


private extension View {
    @ViewBuilder
    func pocketGlassCard(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func pocketGlassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    func pocketGlassIconButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.borderless)
        }
    }
}
