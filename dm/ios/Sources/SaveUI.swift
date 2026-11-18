// Shared save presentation for the launcher and the in-game menu. The serial
// coordinator owns actions and launch safety; this view renders its snapshots.
import SwiftUI
import UIKit
import Combine

struct SaveAction: Identifiable {
    let id, title, group, icon: String
    let primary: Bool
    init?(_ value: [String: Any]) {
        guard let id = value["id"] as? String, let title = value["title"] as? String else { return nil }
        self.id = id; self.title = title
        group = value["group"] as? String ?? ""
        icon = value["icon"] as? String ?? "chevron.right"
        primary = value["primary"] as? Bool ?? false
    }
}

struct SavePage {
    let token: NSNumber
    let title, message: String
    let menu, running: Bool
    let actions: [SaveAction]
    let comparisons: [[String: Any]]
    init?(_ value: [String: Any]) {
        guard let token = value["token"] as? NSNumber else { return nil }
        self.token = token
        title = value["title"] as? String ?? "Saves"
        message = value["message"] as? String ?? ""
        menu = value["menu"] as? Bool ?? false
        running = value["running"] as? Bool ?? false
        actions = (value["actions"] as? [[String: Any]] ?? []).compactMap(SaveAction.init)
        comparisons = value["comparisons"] as? [[String: Any]] ?? []
    }
}

final class SaveModel: ObservableObject {
    @Published private(set) var page: SavePage?
    @Published private(set) var status: [String: Any] = [:]
    @Published private(set) var sending = false
    private var subscriptions = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: Notification.Name("DMSaveLauncherState")).sink { [weak self] note in
            self?.page = (note.object as? [String: Any]).flatMap(SavePage.init)
            self?.sending = false
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: Notification.Name("DMSaveSyncStatus")).sink { [weak self] note in
            self?.status = note.object as? [String: Any] ?? [:]
        }.store(in: &subscriptions)
    }
    var atMenu: Bool { page?.menu == true && !sending }
    var busy: Bool { sending || page == nil || (page?.menu == false && page?.actions.isEmpty == true) }
    var operation: String { status["operation"] as? String ?? "pending" }
    var paired: Bool { status["paired"] as? Bool ?? false }
    var waiting: Bool { status["handoffWaiting"] as? Bool ?? false }
    var ready: Bool { status["handoffReady"] as? Bool ?? false }
    var recoveryPending: Bool { status["recoveryPending"] as? Bool ?? false }
    var needsRestart: Bool { ["conflict", "remoteAdvanced"].contains(operation) }
    var attention: Bool { recoveryPending || needsRestart || operation == "recoveryRequired" }
    var title: String {
        if recoveryPending { return "Save recovery needed" }
        if waiting { return "Checking cloud save…" }
        if ready { return "Ready for another device" }
        switch operation {
        case "localOnly": return "Cloud saves off"
        case "uploading": return "Uploading saved progress…"
        case "uploaded": return "Last save uploaded"
        case "offlinePaused": return "Cloud uploads paused"
        case "conflict": return "Choose a save before syncing"
        case "remoteAdvanced": return "Another device has a newer save"
        case "recoveryRequired": return "Cloud sync needs attention"
        default: return status["pendingLocalChanges"] as? Bool == true ? "Saved here · upload pending" : "Cloud saves connected"
        }
    }
    var symbol: String {
        if attention { return "exclamationmark.icloud" }
        if ready { return "checkmark.circle" }
        switch operation {
        case "localOnly": return "iphone"
        case "uploaded": return "checkmark.icloud"
        case "offlinePaused": return "icloud.slash"
        default: return "icloud"
        }
    }
    var detail: String {
        if recoveryPending { return "Play will retry recovery before starting. Recovery copies are available in More." }
        if waiting { return "Checking that your saved progress is available in the cloud." }
        if ready { return "Open this game on the other device to load it. New progress needs another sync." }
        if needsRestart { return "Close and reopen this app to choose which save to use. Backups are kept." }
        if operation == "recoveryRequired" { return status["message"] as? String ?? "Your local progress is kept. Try syncing again." }
        if !paired { return page?.running == true ? "Set up cloud saves the next time you open this game." : "Cloud saves are optional. Connect to continue on your other devices." }
        if page?.running != true { return operation == "offlinePaused" ? "Play checks cloud progress and resumes uploads." : "Play checks cloud progress before the game starts." }
        if operation == "offlinePaused" { return "Resume & sync turns cloud uploads back on." }
        return "Sync now uploads saved progress and checks it before you switch devices."
    }
    func send(_ action: String) {
        guard let page, !sending else { return }
        sending = true
        NotificationCenter.default.post(name: Notification.Name("DMSaveLauncherAction"), object: nil,
                                        userInfo: ["action": action, "token": page.token])
    }
}

private func saveTime(_ value: Any?) -> String? {
    guard let text = value as? String, let date = ISO8601DateFormatter().date(from: text) else { return nil }
    return date.formatted(date: .abbreviated, time: .shortened)
}

struct SaveSection: View {
    @ObservedObject var model: SaveModel
    @State private var showDetails = false
    private var secondary: [SaveAction] { model.page?.actions.filter { !$0.primary } ?? [] }
    private var groups: [String] { secondary.reduce(into: []) { if !$0.contains($1.group) { $0.append($1.group) } } }

    var body: some View {
        Section {
            if model.atMenu {
                HStack(alignment: .top, spacing: 12) {
                    if model.waiting || model.operation == "uploading" { ProgressView().accessibilityLabel(model.title) }
                    else { Image(systemName: model.symbol).font(.title3).foregroundStyle(model.attention ? Color.orange : Color.secondary).accessibilityHidden(true) }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.title).font(.headline)
                        Text(model.detail).font(.footnote).foregroundStyle(.secondary)
                        if let time = saveTime(model.status["lastConfirmedUpload"]) {
                            Text("Last upload: \(time)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(.vertical, 3)
                HStack {
                    ForEach(model.page?.actions.filter(\.primary) ?? []) { action in
                        Button { model.send(action.id) } label: {
                            Label(model.waiting ? "Checking…" : action.title, systemImage: action.icon)
                        }.disabled(model.waiting)
                    }
                    Spacer()
                    Menu {
                        ForEach(groups, id: \.self) { group in
                            Section(group) {
                                ForEach(secondary.filter { $0.group == group }) { action in
                                    Button { model.send(action.id) } label: { Label(action.title, systemImage: action.icon) }
                                }
                            }
                        }
                        Section {
                            Button { showDetails.toggle() } label: { Label(showDetails ? "Hide technical details" : "Technical details", systemImage: "info.circle") }
                        }
                    } label: { Label("More", systemImage: "ellipsis.circle") }
                    .accessibilityLabel("More save options")
                }.buttonStyle(.borderless)
                if showDetails { details }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if model.busy { ProgressView().accessibilityLabel("Working on saves") }
                        Text(model.sending ? "Please wait…" : model.page?.title ?? "Saves").font(.headline)
                    }
                    if !model.sending { Text(model.page?.message ?? "Loading save options…").font(.subheadline).foregroundStyle(.secondary) }
                }
                if let page = model.page, !model.sending {
                    if !page.comparisons.isEmpty {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(page.comparisons.indices, id: \.self) { index in
                                let copy = page.comparisons[index]
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(copy["title"] as? String ?? "Save").font(.headline)
                                    Text(copy["device"] as? String ?? "Unknown device")
                                    Text(saveTime(copy["time"]) ?? "Save time unavailable")
                                    Text("Game version: \(copy["version"] as? String ?? "unknown")")
                                }.font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(.vertical, 5)
                    }
                    ForEach(page.actions) { action in
                        Button(action.title) { model.send(action.id) }
                    }
                }
            }
        } footer: {
            if model.page?.running == true { Text("Save in-game first. Sync and backups contain saved files, not unsaved gameplay. The game keeps running while this menu is open.") }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.status["message"] as? String ?? "No status available")
            Text("Pending captures: \(model.status["pendingCaptures"] as? Int ?? 0) · uploads: \(model.status["pendingUploads"] as? Int ?? 0)")
            Text("Acknowledged revision: \(model.status["acknowledgedRevision"] as? String ?? "unknown")")
            Text("Source device: \(model.status["sourceDevice"] as? String ?? "unknown")")
        }.font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
    }
}

private struct SaveScreen: View {
    @ObservedObject var model: SaveModel
    var body: some View { Form { SaveSection(model: model) }.preferredColorScheme(.dark) }
}

private final class SaveHostingController: UIHostingController<SaveScreen> {
    private var opened = false
    private var closed = false
    init() {
        super.init(rootView: SaveScreen(model: SaveModel()))
        title = "Saves"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(closeMenu))
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !opened {
            opened = true
            NotificationCenter.default.post(name: Notification.Name("DMSaveScreenReady"), object: self)
        }
    }
    private func closeCoordinator() {
        guard opened, !closed else { return }
        closed = true
        NotificationCenter.default.post(name: Notification.Name("DMSaveScreenClosed"), object: self)
    }
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil { closeCoordinator() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { closeCoordinator() }
    }
    @objc private func closeMenu() { navigationController?.dismiss(animated: true) }
}

@_cdecl("dm_show_save_screen")
public func dmShowSaveScreen(_ pointer: UnsafeMutableRawPointer) {
    let navigation = Unmanaged<UINavigationController>.fromOpaque(pointer).takeUnretainedValue()
    navigation.pushViewController(SaveHostingController(), animated: true)
}
