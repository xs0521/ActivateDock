//
//  ViewController.swift
//  ActivateDock
//
//  Created by luoshuai on 2026/5/5.
//

import Cocoa

final class ViewController: NSViewController {

    private let panelContainer = NSGlassEffectView()
    let panelContent = NSView()
    private let scrollView = NSScrollView()
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
        if button.app.app.activate(options: [.activateAllWindows]) {
            view.window?.orderOut(nil)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        collectionView.collectionViewLayout?.invalidateLayout()
    }

    private func setupPanel() {
        panelContainer.translatesAutoresizingMaskIntoConstraints = false
        panelContainer.style = .clear
        panelContainer.cornerRadius = 22

        panelContent.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.scrollerStyle = .overlay
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchFieldBox.translatesAutoresizingMaskIntoConstraints = false
        searchClearButton.translatesAutoresizingMaskIntoConstraints = false
        searchBackground.translatesAutoresizingMaskIntoConstraints = false
        searchScrollView.translatesAutoresizingMaskIntoConstraints = false
        panelContent.addSubview(searchFieldBox)
        searchFieldBox.addSubview(searchField)
        searchFieldBox.addSubview(searchClearButton)
        panelContent.addSubview(scrollView)
        panelContent.addSubview(searchBackground)
        searchBackground.addSubview(searchScrollView)
        panelContainer.contentView = panelContent
        view.addSubview(panelContainer)

        NSLayoutConstraint.activate([
            panelContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelContainer.topAnchor.constraint(equalTo: view.topAnchor),
            panelContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchFieldBox.leadingAnchor.constraint(equalTo: panelContent.leadingAnchor, constant: 28),
            searchFieldBox.trailingAnchor.constraint(equalTo: panelContent.trailingAnchor, constant: -28),
            searchFieldBox.topAnchor.constraint(equalTo: panelContent.topAnchor, constant: 24),
            searchFieldBox.heightAnchor.constraint(equalToConstant: 64),
            searchField.leadingAnchor.constraint(equalTo: searchFieldBox.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: searchClearButton.leadingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchFieldBox.centerYAnchor),
            searchClearButton.trailingAnchor.constraint(equalTo: searchFieldBox.trailingAnchor, constant: -16),
            searchClearButton.centerYAnchor.constraint(equalTo: searchFieldBox.centerYAnchor),
            searchClearButton.widthAnchor.constraint(equalToConstant: 22),
            searchClearButton.heightAnchor.constraint(equalToConstant: 22),
            scrollView.leadingAnchor.constraint(equalTo: panelContent.leadingAnchor, constant: 28),
            scrollView.trailingAnchor.constraint(equalTo: panelContent.trailingAnchor, constant: -28),
            scrollView.topAnchor.constraint(equalTo: searchFieldBox.bottomAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: panelContent.bottomAnchor, constant: -28),
            searchBackground.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            searchBackground.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            searchBackground.topAnchor.constraint(equalTo: scrollView.topAnchor),
            searchBackground.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            searchScrollView.leadingAnchor.constraint(equalTo: searchBackground.leadingAnchor),
            searchScrollView.trailingAnchor.constraint(equalTo: searchBackground.trailingAnchor),
            searchScrollView.topAnchor.constraint(equalTo: searchBackground.topAnchor),
            searchScrollView.bottomAnchor.constraint(equalTo: searchBackground.bottomAnchor)
        ])
    }

    private func setupCollectionView() {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.register(SectionCollectionItem.self, forItemWithIdentifier: SectionCollectionItem.identifier)

        scrollView.documentView = collectionView
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
