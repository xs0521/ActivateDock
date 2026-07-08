//
//  ViewController.swift
//  ActivateDock
//
//

import Cocoa

final class ViewController: NSViewController {

    let panelContainer = NSGlassEffectView()
    let panelContent = NSView()
    let scrollView = NSScrollView()
    let collectionView = NSCollectionView()

    let searchField = NSSearchField()
    let searchFieldBox = NSVisualEffectView()
    let searchClearButton = NSButton()
    let searchHintLabel = NSTextField(labelWithString: "")
    var searchHintLeadingConstraint: NSLayoutConstraint?
    let searchFieldEditor = SearchFieldEditor()
    let searchBackground = NSVisualEffectView()
    let searchScrollView = NSScrollView()
    let searchResultsTable = NSTableView()

    var groupedApps: [AppGroup] = []
    var installedApps: [InstalledApp] = []
    var searchResults: [SearchRow] = []
    var searchDebounceWorkItem: DispatchWorkItem?

    let executor = WorkflowExecutor()

    var cardDragOverlay: NSImageView?
    var cardDragSourceIndex: Int?
    var cardDragMouseStart: NSPoint?
    var cardDragOverlayStartOrigin: NSPoint?

    var iconDragOverlay: NSImageView?
    var iconDragSourceGroup: Int?
    var iconDragSourceItem: Int?
    var iconDragTargetGroup: Int?
    var iconDragMouseStart: NSPoint?
    var iconDragOverlayStartOrigin: NSPoint?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPanel()
        setupCollectionView()
        setupSearch()
        loadInstalledApps()
        refreshRunningApps()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillBecomeActive(_:)),
            name: NSApplication.willBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalizationChange(_:)),
            name: LocalizationManager.didChangeNotification,
            object: nil
        )
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(handleWorkspaceChange(_:)),
                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(handleWorkspaceChange(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        installCmdQMonitor()
    }

    @objc private func handleWillBecomeActive(_ note: Notification) {
        refreshRunningApps()
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.makeFirstResponder(searchField)
    }

    @objc private func handleWorkspaceChange(_ note: Notification) {
        refreshRunningApps()
    }

    @objc private func handleLocalizationChange(_ note: Notification) {
        searchField.placeholderString = L("search.placeholder")
        updateSearchHint(for: searchField.stringValue)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowChrome()
        view.window?.makeFirstResponder(searchField)
    }

    func handleAppTapped(_ button: AppIconButton) {
        if AppActivator.activate(button.app.app) {
            bringSelectedAppToFront(button.app)
            view.window?.orderOut(nil)
        }
    }

    private func bringSelectedAppToFront(_ app: RunningApp) {
        let target = app.app
        for g in groupedApps.indices {
            guard let i = groupedApps[g].items.firstIndex(where: { $0.app == target }) else { continue }
            if i == 0 { return }
            let item = groupedApps[g].items.remove(at: i)
            groupedApps[g].items.insert(item, at: 0)
            if let cell = collectionView.item(at: IndexPath(item: g, section: 0)) as? SectionCollectionItem {
                cell.moveButton(from: i, to: 0)
            }
            saveLayout()
            return
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        collectionView.collectionViewLayout?.invalidateLayout()
    }

    func refreshRunningApps() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular &&
                !$0.isTerminated &&
                $0.processIdentifier != currentPID
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
            .map {
                RunningApp(
                    app: $0,
                    displayName: $0.localizedName ?? "unknow application",
                    bundleIdentifier: $0.bundleIdentifier ?? ""
                )
            }
        let next = AppGroupBuilder.build(from: apps)
        if sameStructure(groupedApps, next) { return }
        groupedApps = next
        collectionView.reloadData()
        DispatchQueue.main.async { [weak self] in
            self?.fitWindowHeightToContent()
        }
    }

    private func sameStructure(_ lhs: [AppGroup], _ rhs: [AppGroup]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (a, b) in zip(lhs, rhs) {
            if a.title != b.title || a.items.count != b.items.count { return false }
            for (x, y) in zip(a.items, b.items) where x.bundleIdentifier != y.bundleIdentifier {
                return false
            }
        }
        return true
    }
}
