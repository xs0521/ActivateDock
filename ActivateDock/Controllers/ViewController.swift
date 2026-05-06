//
//  ViewController.swift
//  ActivateDock
//
//  Created by luoshuai on 2026/5/5.
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
    let searchBackground = NSVisualEffectView()
    let searchScrollView = NSScrollView()
    let searchResultsTable = NSTableView()

    var groupedApps: [AppGroup] = []
    var installedApps: [InstalledApp] = []
    var searchResults: [InstalledApp] = []
    var searchDebounceWorkItem: DispatchWorkItem?

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

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowChrome()
        view.window?.makeFirstResponder(searchField)
    }

    func handleAppTapped(_ button: AppIconButton) {
        if AppActivator.activate(button.app.app) {
            view.window?.orderOut(nil)
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
                    displayName: $0.localizedName ?? "未知应用",
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
