import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: PresentationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ApplePencilSettingsSection()

                Section("外部ディスプレイ") {
                    Picker("外部画面", selection: $store.externalDisplayMode) {
                        ForEach(ExternalDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Text(store.externalDisplayActive ? "外部ディスプレイ接続中" : "外部ディスプレイ未接続")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("原稿表示") {
                    Picker("原稿モード", selection: $store.noteDisplayMode) {
                        ForEach(NoteDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("文字サイズ")
                            Spacer()
                            Text("\(Int(store.noteFontSize)) pt")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $store.noteFontSize, in: 16...44, step: 1)
                    }

                    Text("OFFでは原稿欄を閉じ、Now/Nextのスライドプレビューを大きく表示します。Markdown表示では見出しや強調を反映します。TXT表示ではMarkdown記法を軽く落としてプレーンテキストとして表示します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("システムのPencil設定") {
                    LabeledContent("ダブルタップ設定", value: String(describing: UIPencilInteraction.preferredTapAction))
                    LabeledContent("スクイーズ設定", value: "Apple Pencil Pro / 対応OS依存")
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ApplePencilSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ApplePencilSettingsSection()

                Section("システムのPencil設定") {
                    LabeledContent("ダブルタップ設定", value: String(describing: UIPencilInteraction.preferredTapAction))
                    LabeledContent("スクイーズ設定", value: "Apple Pencil Pro / 対応OS依存")
                }
            }
            .navigationTitle("Apple Pencil設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ApplePencilSettingsSection: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        Section("Apple Pencil") {
            Picker("ダブルタップ", selection: $store.doubleTapAction) {
                ForEach(NexlideAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }

            Picker("スクイーズ", selection: $store.squeezeAction) {
                ForEach(NexlideAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }

            Toggle("スクイーズ長押しで連続実行", isOn: $store.squeezeHoldRepeatEnabled)

            Text("初期値はOFFです。ONにすると、Apple Pencil Proのスクイーズを押し続けている間、スクイーズに割り当てたページ操作を繰り返します。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("検出状態")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.lastDetectedPencilDescription)
            }

            Text("Apple Pencilの機種名そのものは公開APIで取得できないため、ダブルタップ/スクイーズの検出状況から対応機能を扱います。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
