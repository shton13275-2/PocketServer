import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(.tint)

                    Text("PocketServer")
                        .font(.largeTitle.bold())

                    Text("iPhoneをローカルファイルサーバーに")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 16) {
                    Label("サーバー状態", systemImage: "network")
                        .font(.headline)

                    HStack(spacing: 10) {
                        Circle()
                            .fill(.gray)
                            .frame(width: 10, height: 10)
                        Text("停止中")
                            .font(.title3.weight(.medium))
                    }

                    Text("サーバー機能は現在準備中です。次の開発段階で起動・停止機能を実装します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 12) {
                    Label("これから実装する機能", systemImage: "checklist")
                        .font(.headline)

                    FeatureRow(title: "Wi-Fi経由のファイルアップロード", icon: "arrow.up.doc")
                    FeatureRow(title: "ファイルのダウンロード", icon: "arrow.down.doc")
                    FeatureRow(title: "ファイル一覧・削除", icon: "folder")
                    FeatureRow(title: "パスワード保護", icon: "lock")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private struct FeatureRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
}
