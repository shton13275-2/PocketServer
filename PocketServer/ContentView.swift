import SwiftUI

struct ContentView: View {
    @StateObject private var server = ServerController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundStyle(Color.accentColor)
                        Text("PocketServer").font(.largeTitle.bold())
                        Text("iPhoneをローカルファイルサーバーに")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 24)

                    VStack(alignment: .leading, spacing: 18) {
                        Label("サーバー状態", systemImage: "network").font(.headline)
                        HStack(spacing: 10) {
                            Circle().fill(server.isRunning ? .green : .gray).frame(width: 10, height: 10)
                            Text(server.statusMessage).font(.title3.weight(.medium))
                        }
                        if let url = server.serverURL {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("接続アドレス").font(.subheadline).foregroundStyle(.secondary)
                                Text(url).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                ShareLink(item: url) { Label("URLを共有", systemImage: "square.and.arrow.up") }
                            }
                        } else if server.isRunning {
                            Text("IPアドレスを取得できません。Wi-Fiに接続しているか確認してください。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let error = server.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
                        Button {
                            if server.isRunning || server.statusMessage == "起動処理中" { server.stop() } else { server.start() }
                        } label: {
                            Text(server.isRunning || server.statusMessage == "起動処理中" ? "サーバーを停止" : "サーバーを起動")
                                .frame(maxWidth: .infinity).padding(.vertical, 5)
                        }.buttonStyle(.borderedProminent).tint(server.isRunning ? .red : .blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("ファイル管理の進捗", systemImage: "checklist").font(.headline)
                        FeatureRow(title: "ブラウザでファイル一覧", icon: "folder", completed: true)
                        FeatureRow(title: "ファイルダウンロード", icon: "arrow.down.doc", completed: true)
                        FeatureRow(title: "ファイルアップロード", icon: "arrow.up.doc", completed: false)
                        FeatureRow(title: "ファイル削除", icon: "trash", completed: false)
                        FeatureRow(title: "パスワード保護", icon: "lock", completed: false)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                    Text("注意：現段階では認証機能がありません。信頼できるWi-Fi内でのみ使用し、使用後はサーバーを停止してください。")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 20)
            }.navigationTitle("ホーム").navigationBarTitleDisplayMode(.inline)
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct FeatureRow: View {
    let title: String
    let icon: String
    let completed: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(completed ? Color.green : Color.accentColor).frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: completed ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(completed ? Color.green : Color.secondary)
        }.font(.subheadline)
    }
}

#Preview { ContentView() }
