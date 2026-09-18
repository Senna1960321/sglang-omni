// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

// Use the property wrapper explicitly; some Command Line Tools SDKs expose an unavailable State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

private let brandGreen = Color(red: 0.13, green: 0.46, blue: 0.36)
private let accent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.40, green: 0.78, blue: 0.64, alpha: 1)
        : NSColor(red: 0.13, green: 0.46, blue: 0.36, alpha: 1)
})
private let cardBackground = Color(nsColor: .controlBackgroundColor)
private let styles = ["clean", "verbatim", "casual", "formal", "concise"]
private let languages = ["English", "Chinese", "Japanese", "Korean", "French", "German", "Spanish", "Portuguese", "Italian", "Russian", "Arabic", "Hindi", "Cantonese"]

enum Page: String, CaseIterable {
    case home = "Home", history = "History", dictionary = "Dictionary", rules = "Writing style", settings = "Settings"
    var title: String { L("nav." + rawValue.replacingOccurrences(of: " ", with: "")) }
    var icon: String {
        switch self { case .home: return "square.grid.2x2"; case .history: return "clock.arrow.circlepath"
        case .dictionary: return "book.closed"; case .rules: return "slider.horizontal.3"; case .settings: return "gearshape" }
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: AppStore
    @ViewState private var page: Page = .home
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(page.title).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Label(L("app.badge"), systemImage: "lock.shield")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    Circle().fill(accent).frame(width: 6, height: 6)
                }.padding(.horizontal, 32).frame(height: 60)
                Divider().opacity(0.5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !store.storageError.isEmpty { message(store.storageError, error: true) }
                        if !model.error.isEmpty {
                            message(model.error, error: true)
                            if model.canRetry { Button(L("app.retryLast")) { model.retryLast() } }
                        }
                        if !model.notice.isEmpty { message(model.notice, error: false) }
                        if model.phase == .preparing { PreparationCard(model: model, worker: model.worker) }
                        switch page {
                        case .home: HomeView(model: model, store: store)
                        case .history: HistoryView(model: model, store: store)
                        case .dictionary: DictionaryView(store: store)
                        case .rules: RulesView(store: store)
                        case .settings: PreferencesView(model: model, store: store)
                        }
                    }.padding(32).frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .preferredColorScheme(store.preferences.appearance == "light" ? .light : store.preferences.appearance == "dark" ? .dark : nil)
        .onChange(of: model.resultText) { _, _ in page = .home }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.white).frame(width: 40, height: 40)
                    .background(brandGreen, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text("OmniTyper").font(.system(size: 16, weight: .semibold))
                    Text(L("app.tagline")).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.top, 35).padding(.horizontal, 18)
            VStack(spacing: 6) {
                ForEach(Page.allCases, id: \.self) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).frame(width: 20)
                            Text(item.title).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                            Spacer()
                            if item == .history && !store.history.isEmpty {
                                Text("\(store.history.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 12)
                            .background(page == item ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(page == item ? accent : .primary)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12)
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label(L("app.privacyTitle"), systemImage: "desktopcomputer").font(.system(size: 11, weight: .medium))
                Text(L("app.privacyBody"))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                HStack {
                    Text("SGLang-Omni + MLX").font(.system(size: 9, weight: .medium, design: .monospaced))
                    Spacer()
                    Text("0.1").font(.system(size: 9, design: .monospaced))
                }.foregroundStyle(.tertiary)
            }.padding(18)
        }.frame(width: 218).background(cardBackground.opacity(0.48))
    }

    private func message(_ text: String, error: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: error ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundStyle(error ? .orange : accent)
            Text(text).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            Button { if error { model.error = "" } else { model.notice = "" } } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel(L("app.dismiss"))
        }.padding(14).background((error ? Color.orange : accent).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.055), lineWidth: 1))
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text(L("home.eyebrow")).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(accent)
                Text(L("home.title")).font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(L("home.subtitle")).font(.system(size: 14)).foregroundStyle(.secondary)
            }.padding(.bottom, 4)
            if !model.microphoneAllowed || !model.accessibilityAllowed {
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(L("home.permissions.title"), systemImage: "hand.wave").font(.system(size: 16, weight: .semibold))
                        Text(L("home.permissions.body")).font(.system(size: 12)).foregroundStyle(.secondary)
                        permission(L("settings.microphone"), subtitle: L("home.permissions.mic"), ready: model.microphoneAllowed, action: model.requestMicrophone)
                        permission(L("settings.accessibility"), subtitle: L("home.permissions.ax"), ready: model.accessibilityAllowed, action: model.requestAccessibility)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(model.mode.title).font(.system(size: 23, weight: .semibold))
                            Text(model.mode.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: model.mode.icon).font(.system(size: 30)).foregroundStyle(accent)
                            .frame(width: 64, height: 64).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    }
                    Picker(L("home.voiceMode"), selection: $model.mode) {
                        ForEach(VoiceMode.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().disabled(model.isBusy)
                    HStack(spacing: 12) {
                        Button { model.toggle() } label: {
                            Label(model.phase == .recording ? L("home.finish") : model.phase == .processing ? L("home.working") : model.phase == .starting ? L("home.loadingSpeech") : L("home.start"),
                                  systemImage: model.phase == .recording ? "stop.fill" : "mic.fill")
                                .frame(minWidth: 142).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(model.isBusy && model.phase != .recording)
                        if model.isBusy { Button(L("action.cancel"), role: .cancel) { model.cancel() } }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(model.shortcutLabel).font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10).padding(.vertical, 6).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                            Text(store.preferences.holdToTalk ? L("home.holdHint") : L("home.pressHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    if model.mode == .translate {
                        HStack {
                            Text(L("home.writeIn")).foregroundStyle(.secondary)
                            Picker(L("home.translationLanguage"), selection: $store.preferences.targetLanguage) { ForEach(languages, id: \.self) { Text(L("language." + $0)).tag($0) } }
                                .labelsHidden().frame(width: 160)
                        }.font(.system(size: 12))
                    }
                    if model.mode == .ask {
                        Text(L("home.askNote")).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            if model.phase == .starting || model.phase == .recording || model.phase == .processing {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("home.liveTranscript"), systemImage: "waveform").font(.system(size: 13, weight: .semibold))
                        Text(model.liveStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(model.liveText.isEmpty ? L("home.livePlaceholder") : model.liveText)
                            .font(.system(size: 15)).lineSpacing(4).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !model.resultText.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(L("home.resultTitle"), systemImage: "text.alignleft").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Button { model.copyResult() } label: { Label(L("action.copy"), systemImage: "doc.on.doc") }
                        }
                        Text(model.resultText).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled)
                        if model.rawText != model.resultText && !model.rawText.isEmpty {
                            DisclosureGroup(L("home.originalTranscript")) { Text(model.rawText).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled).padding(.top, 6) }
                                .font(.system(size: 11))
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                stat(L("home.stat.words"), value: "\(store.history.reduce(0) { $0 + $1.units })", icon: "text.word.spacing")
                stat(L("home.stat.time"), value: L("home.stat.minutes", String(Int(store.history.reduce(0) { $0 + $1.duration } / 60))), icon: "waveform")
                stat(L("home.stat.vocabulary"), value: L("home.stat.wordCount", String(store.dictionary.count)), icon: "book.closed")
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb").foregroundStyle(accent)
                Text(L("home.tip"))
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(.horizontal, 4)
        }
    }
    private func permission(_ title: String, subtitle: String, ready: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle").foregroundStyle(ready ? accent : .secondary)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .medium)); Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer()
            if ready { Text(L("action.ready")).font(.system(size: 11)).foregroundStyle(accent) }
            else { Button(L("action.allow"), action: action).controlSize(.small) }
        }
    }
    private func stat(_ title: String, value: String, icon: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).foregroundStyle(accent)
                Text(value).font(.system(size: 21, weight: .semibold, design: .rounded))
                Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PreparationCard: View {
    @ObservedObject var model: AppModel
    @ObservedObject var worker: WorkerClient
    var body: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 5) {
                Text(L("prepare.title")).font(.system(size: 13, weight: .semibold))
                Text(worker.status.isEmpty ? L("prepare.body") : worker.status).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(); Button(L("action.cancel")) { model.cancel() }
        }.padding(20).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct VoicePanel: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var worker: WorkerClient
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                if model.phase == .recording {
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(0..<9) { index in
                            Capsule().fill(accent).frame(width: 3, height: 5 + 30 * recorder.level * (index % 2 == 0 ? 1 : 0.55))
                        }
                    }.frame(width: 45, height: 38).animation(.easeOut(duration: 0.1), value: recorder.level)
                } else { ProgressView().controlSize(.small).frame(width: 45) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.phase == .recording ? L("panel.listening", model.mode.title) : model.phase == .starting ? L("status.loadingModel") : model.liveStatus)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(model.phase == .recording ? String(format: L("panel.elapsed"), Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60) : worker.status)
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if model.phase == .recording {
                    Button { model.finish() } label: { Image(systemName: "stop.fill").foregroundStyle(accent) }.buttonStyle(.plain).accessibilityLabel(L("home.finish"))
                }
                Button { model.cancel() } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(L("panel.cancelRecording"))
            }
            Divider()
            Text(model.liveText.isEmpty ? (model.phase == .starting ? L("panel.waitListening") : L("panel.placeholder")) : String(model.liveText.suffix(600)))
                .font(.system(size: 14)).lineSpacing(3).lineLimit(3).truncationMode(.head)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(model.phase == .recording ? model.liveStatus : L("panel.insertNote"))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(18).frame(width: 460, height: 190).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: AppStore
    @ViewState private var query = ""
    @ViewState private var filter = "all"
    @ViewState private var editing: HistoryEntry?
    @ViewState private var confirmDelete = false
    private var entries: [HistoryEntry] {
        store.history.filter { (filter == "all" || $0.mode.rawValue == filter) && (query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) || $0.appName.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle(L("history.title"), detail: L("history.subtitle"))
            HStack {
                TextField(L("history.search"), text: $query).textFieldStyle(.roundedBorder)
                Picker(L("history.filter"), selection: $filter) {
                    Text(L("history.allModes")).tag("all")
                    ForEach(VoiceMode.allCases) { Text($0.title).tag($0.rawValue) }
                }.labelsHidden().frame(width: 135)
                Menu {
                    Button(L("history.export")) { FileActions.exportHistory(store.history) }
                    Button(L("history.deleteAll"), role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 28)
            }
            if entries.isEmpty {
                ContentUnavailableView(query.isEmpty ? L("history.emptyTitle") : L("history.emptySearch"), systemImage: "text.bubble", description: Text(query.isEmpty ? L("history.emptyBody") : L("history.emptySearchBody")))
                    .frame(maxWidth: .infinity, minHeight: 230)
            }
            LazyVStack(spacing: 14) {
                ForEach(entries) { entry in
                    Card {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Label(entry.mode.title, systemImage: entry.mode.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                                Text(L("history.appSuffix", entry.appName)).font(.system(size: 11)).foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Text(entry.text).font(.system(size: 14)).lineSpacing(4).textSelection(.enabled)
                            if let warning = entry.warning, !warning.isEmpty { Text(warning).font(.system(size: 11)).foregroundStyle(.orange) }
                            HStack {
                                Text(L("history.meta", String(entry.units), String(Int(entry.duration)))).font(.system(size: 10)).foregroundStyle(.tertiary)
                                Spacer()
                                Button { TextInsertion.copy(entry.text) } label: { Label(L("action.copy"), systemImage: "doc.on.doc") }
                                Menu {
                                    Button(L("history.correct")) { editing = entry }
                                    if store.audioURL(for: entry) != nil {
                                        Button(L("history.retryAudio")) { model.retry(entry) }.disabled(model.isBusy)
                                        Button(L("history.exportAudio")) { if let url = store.audioURL(for: entry) { FileActions.exportAudio(url) } }
                                    }
                                    Button(L("action.delete"), role: .destructive) { store.delete([entry.id]) }
                                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 20)
                            }.controlSize(.small)
                            if entry.rawText != entry.text {
                                DisclosureGroup(L("home.originalTranscript")) { Text(entry.rawText).textSelection(.enabled).padding(.top, 6) }.font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.sheet(item: $editing) { entry in CorrectionView(store: store, entry: entry) }
            .confirmationDialog(L("history.confirmDelete"), isPresented: $confirmDelete) {
                Button(L("history.deleteAllConfirm"), role: .destructive) { store.delete(Set(store.history.map(\.id))) }
            }
    }
}

private struct CorrectionView: View {
    @ObservedObject var store: AppStore
    let entry: HistoryEntry
    @Environment(\.dismiss) var dismiss
    @ViewState private var corrected = ""
    @ViewState private var spoken = ""
    @ViewState private var written = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("correct.title")).font(.title2.bold())
            TextEditor(text: $corrected).font(.body).frame(height: 150).border(.secondary.opacity(0.2))
            Text(L("correct.remember")).font(.subheadline)
            HStack { TextField(L("correct.heard"), text: $spoken); Image(systemName: "arrow.right"); TextField(L("correct.written"), text: $written) }.textFieldStyle(.roundedBorder)
            Text(L("correct.note")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer(); Button(L("action.cancel")) { dismiss() }
                Button(L("correct.save")) {
                    if let index = store.history.firstIndex(where: { $0.id == entry.id }) { store.history[index].text = corrected }
                    store.addWord(spoken: spoken, written: written, learned: true); dismiss()
                }.buttonStyle(.borderedProminent).disabled(corrected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 520).onAppear { corrected = entry.text }
    }
}

struct DictionaryView: View {
    @ObservedObject var store: AppStore
    @ViewState private var spoken = ""
    @ViewState private var written = ""
    @ViewState private var query = ""
    @ViewState private var importMessage = ""
    @ViewState private var editingID: UUID?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle(L("dict.title"), detail: L("dict.subtitle"))
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(editingID == nil ? L("dict.add") : L("dict.editEntry")).font(.headline)
                    HStack {
                        TextField(L("dict.spoken"), text: $spoken)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        TextField(L("dict.written"), text: $written)
                        Button(editingID == nil ? L("dict.addWord") : L("dict.saveWord")) {
                            guard store.addWord(spoken: spoken, written: written.isEmpty ? spoken : written, replacing: editingID) else {
                                importMessage = L("dict.saveError")
                                return
                            }
                            spoken = ""; written = ""; editingID = nil; importMessage = ""
                        }.buttonStyle(.borderedProminent)
                            .disabled(!DictionaryEntry.isValidPhrase(spoken) || (!written.isEmpty && !DictionaryEntry.isValidPhrase(written)))
                        if editingID != nil { Button(L("action.cancel")) { spoken = ""; written = ""; editingID = nil } }
                    }.textFieldStyle(.roundedBorder)
                    Text(L("dict.hint")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            HStack {
                TextField(L("dict.find"), text: $query).textFieldStyle(.roundedBorder)
                Button(L("dict.import")) {
                    do { if let text = try FileActions.importText() { importMessage = L("dict.imported", String(try store.importWords(text))) } }
                    catch { importMessage = error.localizedDescription }
                }
                Button(L("dict.exportAction")) { FileActions.exportDictionary(store.dictionary) }
            }
            if !importMessage.isEmpty { Text(importMessage).font(.caption).foregroundStyle(.secondary) }
            if store.dictionary.isEmpty {
                ContentUnavailableView(L("dict.emptyTitle"), systemImage: "book.closed", description: Text(L("dict.emptyBody")))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            LazyVStack(spacing: 8) {
                ForEach(store.dictionary.filter { query.isEmpty || $0.spoken.localizedCaseInsensitiveContains(query) || $0.written.localizedCaseInsensitiveContains(query) }) { entry in
                    HStack(spacing: 12) {
                        Text(entry.spoken).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        Text(entry.written).frame(maxWidth: .infinity, alignment: .leading)
                        if !entry.isValid { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).help(L("dict.invalidEntry")) }
                        if entry.learned { Image(systemName: "sparkle").foregroundStyle(accent).help(L("dict.fromCorrection")) }
                        Button(L("action.edit")) { editingID = entry.id; spoken = entry.spoken; written = entry.written }
                        Button {
                            store.dictionary.removeAll { $0.id == entry.id }
                            if editingID == entry.id { editingID = nil; spoken = ""; written = "" }
                        } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel(L("dict.deleteWord"))
                    }.textFieldStyle(.plain).padding(15).background(cardBackground, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct RulesView: View {
    @ObservedObject var store: AppStore
    @ViewState private var bundleID = ""
    @ViewState private var appName = ""
    @ViewState private var selectedStyle = "clean"
    @ViewState private var instructions = ""
    @ViewState private var apps: [NSRunningApplication] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle(L("rules.title"), detail: L("rules.subtitle"))
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("rules.everywhere")).font(.headline)
                    Picker(L("rules.defaultStyle"), selection: $store.preferences.style) { ForEach(styles, id: \.self) { Text(L("style." + $0)).tag($0) } }
                    TextField(L("rules.instructions"), text: $store.preferences.instructions, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(3...5)
                    Text(L("rules.charCount", String(store.preferences.instructions.unicodeScalars.count)))
                        .font(.caption).foregroundStyle(store.preferences.instructions.unicodeScalars.count > 1000 ? .orange : .secondary)
                    if let error = instructionError(store.preferences.instructions, "") { Text(error).font(.caption).foregroundStyle(.orange) }
                    Text(L("rules.styleNote")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("rules.addApp")).font(.headline)
                    Picker(L("rules.runningApp"), selection: $bundleID) {
                        Text(L("rules.chooseApp")).tag("")
                        ForEach(apps, id: \.processIdentifier) { app in Text(app.localizedName ?? app.bundleIdentifier ?? "App").tag(app.bundleIdentifier ?? "") }
                    }.onChange(of: bundleID) { _, value in appName = apps.first { $0.bundleIdentifier == value }?.localizedName ?? value }
                    HStack { TextField(L("rules.bundleID"), text: $bundleID); TextField(L("rules.displayName"), text: $appName) }.textFieldStyle(.roundedBorder)
                    Picker(L("rules.style"), selection: $selectedStyle) { ForEach(styles, id: \.self) { Text(L("style." + $0)).tag($0) } }
                    TextField(L("rules.appInstructions"), text: $instructions, axis: .vertical).textFieldStyle(.roundedBorder)
                    Text(L("rules.charCountCombined", String(instructions.unicodeScalars.count)))
                        .font(.caption).foregroundStyle(instructions.unicodeScalars.count > 1000 ? .orange : .secondary)
                    if let error = instructionError(store.preferences.instructions, instructions) { Text(error).font(.caption).foregroundStyle(.orange) }
                    Button(L("rules.saveApp")) {
                        store.rules.removeAll { $0.bundleID == bundleID }
                        store.rules.append(AppRule(bundleID: bundleID, name: appName.isEmpty ? bundleID : appName, style: selectedStyle, instructions: instructions))
                        bundleID = ""; appName = ""; instructions = ""
                    }.disabled(bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || instructionError(store.preferences.instructions, instructions) != nil).buttonStyle(.borderedProminent)
                }
            }
            ForEach(store.rules) { rule in
                Card {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rule.name).font(.headline)
                            Text(L("rules.appSummary", L("style." + rule.style), rule.bundleID)).font(.caption).foregroundStyle(.secondary)
                            if !rule.instructions.isEmpty { Text(rule.instructions).font(.subheadline) }
                        }
                        Spacer()
                        Button(L("action.edit")) { bundleID = rule.bundleID; appName = rule.name; selectedStyle = rule.style; instructions = rule.instructions }
                        Button { store.rules.removeAll { $0.id == rule.id } } label: { Image(systemName: "trash") }.accessibilityLabel(L("rules.deleteApp"))
                    }
                }
            }
        }.onAppear { apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") } }
    }
    private func instructionError(_ defaults: String, _ app: String) -> String? {
        do { _ = try Preferences.combinedInstructions(defaults, app); return nil }
        catch { return error.localizedDescription }
    }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: AppStore
    @ViewState private var microphones: [MicrophoneDevice] = []
    @ViewState private var captureMonitor: Any?
    @ViewState private var capturing = false
    @ViewState private var login = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageTitle(L("settings.title"), detail: L("settings.subtitle"))
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.keyboardAudio"), systemImage: "keyboard").font(.headline)
                    HStack {
                        Text(L("settings.shortcut")); Spacer()
                        Button(capturing ? L("settings.pressCombo") : model.shortcutLabel) { captureShortcut() }
                            .font(.system(.body, design: .monospaced))
                        Button(L("action.reset")) { store.preferences.shortcutKeyCode = 49; store.preferences.shortcutModifiers = 786432 }
                    }
                    Toggle(L("settings.holdToTalk"), isOn: $store.preferences.holdToTalk)
                    Text(L("settings.holdNote")).font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Picker(L("settings.microphone"), selection: $store.preferences.microphoneUID) {
                        Text(L("settings.systemDefault")).tag("")
                        ForEach(microphones) { Text($0.name).tag($0.id) }
                    }
                    Toggle(L("settings.sounds"), isOn: $store.preferences.sounds)
                    Toggle(L("settings.autoPaste"), isOn: $store.preferences.autoPaste)
                    Text(L("settings.autoPasteNote")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.languages"), systemImage: "globe").font(.headline)
                    Picker(L("settings.speechLanguage"), selection: $store.preferences.language) {
                        Text(L("settings.detectAutomatically")).tag("")
                        ForEach(languages, id: \.self) { Text(L("language." + $0)).tag($0) }
                    }
                    Picker(L("settings.translateInto"), selection: $store.preferences.targetLanguage) { ForEach(languages, id: \.self) { Text(L("language." + $0)).tag($0) } }
                    Divider()
                    Picker(L("settings.interfaceLanguage"), selection: $store.preferences.uiLanguage) {
                        Text(L("settings.followSystem")).tag(String?.none)
                        ForEach(L10n.supported, id: \.self) { Text(L10n.displayName($0)).tag(String?.some($0)) }
                    }
                    Text(L("settings.interfaceLanguageNote")).font(.caption).foregroundStyle(.secondary)
                    Text(L("settings.languageNote")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.localModel"), systemImage: "cpu").font(.headline)
                    Text("Qwen3-ASR · 0.6B · MLX 4-bit").font(.subheadline)
                    Text(L("settings.modelNote")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("settings.prepareASR")) { model.prepareModels() }.buttonStyle(.borderedProminent).disabled(model.isBusy)
                        Button(L("settings.unloadASR")) { model.releaseModels() }.disabled(model.isBusy)
                    }
                    DisclosureGroup(L("settings.runtime")) {
                        TextField(L("settings.python"), text: $store.preferences.pythonExecutable).textFieldStyle(.roundedBorder).padding(.top, 8)
                        Text(L("settings.runtimeNote")).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(L("settings.downloadNote")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.textAPI"), systemImage: "network").font(.headline)
                    Text(L("settings.textAPINote")).font(.caption).foregroundStyle(.secondary)
                    TextField(L("settings.baseURL"), text: $store.preferences.textSettings.baseURL)
                        .textFieldStyle(.roundedBorder).accessibilityLabel(L("settings.baseURLLabel"))
                    HStack {
                        TextField(L("settings.modelName"), text: $store.preferences.textSettings.model)
                            .textFieldStyle(.roundedBorder).accessibilityLabel(L("settings.modelLabel"))
                        if !model.textModels.isEmpty {
                            Menu(L("settings.chooseModel")) {
                                ForEach(model.textModels, id: \.self) { name in
                                    Button(name) { store.preferences.textSettings.model = name }
                                }
                            }
                        }
                    }
                    SecureField(L("settings.apiKey"), text: $model.textAPIKey).textFieldStyle(.roundedBorder)
                    Text(L("settings.apiKeyNote")).font(.caption).foregroundStyle(.secondary)
                    Button(L("settings.connect")) { model.loadTextModels() }.disabled(model.isBusy)
                    DisclosureGroup(L("settings.requestOptions")) {
                        TextEditor(text: $store.preferences.textSettings.optionsJSON)
                            .font(.system(.caption, design: .monospaced)).frame(height: 90)
                            .accessibilityLabel(L("settings.requestOptionsLabel"))
                        Text(L("settings.requestOptionsNote")).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(L("settings.privacyNote")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.privacyHistory"), systemImage: "lock.shield").font(.headline)
                    Toggle(L("settings.keepHistory"), isOn: $store.preferences.saveHistory)
                    Picker(L("settings.keepFor"), selection: $store.preferences.historyDays) {
                        Text(L("settings.retain24h")).tag(1); Text(L("settings.retain7d")).tag(7); Text(L("settings.retain30d")).tag(30)
                        Text(L("settings.retain1y")).tag(365); Text(L("settings.retainForever")).tag(0)
                    }.disabled(!store.preferences.saveHistory)
                    Toggle(L("settings.keepAudio"), isOn: $store.preferences.keepAudio).disabled(!store.preferences.saveHistory)
                    Text(L("settings.historyNote")).font(.caption).foregroundStyle(.secondary)
                    Button(L("settings.openDataFolder")) { NSWorkspace.shared.open(store.directory) }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 15) {
                    Label(L("settings.general"), systemImage: "gearshape").font(.headline)
                    Picker(L("settings.appearance"), selection: $store.preferences.appearance) { Text(L("appearance.system")).tag("system"); Text(L("appearance.light")).tag("light"); Text(L("appearance.dark")).tag("dark") }
                    Toggle(L("settings.openAtLogin"), isOn: Binding(get: { login }, set: { value in
                        do {
                            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            login = SMAppService.mainApp.status == .enabled
                        } catch { model.error = L("settings.loginError", error.localizedDescription) }
                    }))
                    HStack {
                        Button(L("settings.micSettings")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
                        Button(L("settings.axSettings")) { model.requestAccessibility() }
                    }
                    Text(L("app.about")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.onAppear {
            microphones = AudioRecorder.devices()
            // SMAppService.status is a synchronous XPC round trip; a @State default
            // expression would repeat it on every body pass.
            login = SMAppService.mainApp.status == .enabled
        }
            .onDisappear { endCapture() }
    }
    private func captureShortcut() {
        endCapture(); capturing = true
        captureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { endCapture(); return nil }
            let mask: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let flags = event.modifierFlags.intersection(mask)
            guard !flags.isEmpty || [96, 97, 98, 99, 100, 101, 109, 111].contains(event.keyCode) else { NSSound.beep(); return nil }
            store.preferences.shortcutKeyCode = event.keyCode
            store.preferences.shortcutModifiers = UInt64(flags.rawValue)
            endCapture(); return nil
        }
    }
    private func endCapture() { if let captureMonitor { NSEvent.removeMonitor(captureMonitor) }; captureMonitor = nil; capturing = false }
}

private func pageTitle(_ title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 9) { Text(title).font(.system(size: 27, weight: .semibold, design: .rounded)); Text(detail).font(.system(size: 13)).foregroundStyle(.secondary) }
}

@MainActor
private enum FileActions {
    static func importText() throws -> String? {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 1_000_000 else { throw AppError.message(L("error.dictionaryTooLarge")) }
        return try String(contentsOf: url, encoding: .utf8)
    }
    static func exportHistory(_ entries: [HistoryEntry]) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        save(name: "OmniTyper-history.json", type: .json) { try encoder.encode(entries) }
    }
    static func exportDictionary(_ entries: [DictionaryEntry]) {
        func escape(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let text = "spoken,written\n" + entries.map { "\(escape($0.spoken)),\(escape($0.written))" }.joined(separator: "\n")
        save(name: "OmniTyper-dictionary.csv", type: .commaSeparatedText) { Data(text.utf8) }
    }
    static func exportAudio(_ url: URL) { save(name: "OmniTyper-recording.wav", type: .wav) { try Data(contentsOf: url) } }
    private static func save(name: String, type: UTType, data: () throws -> Data) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data().write(to: url, options: .atomic) }
        catch { let alert = NSAlert(error: error); alert.runModal() }
    }
}
