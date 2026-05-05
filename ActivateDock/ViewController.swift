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

    var groupedApps: [AppGroup] = []

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
    }

    @objc private func handleWillBecomeActive(_ note: Notification) {
        refreshRunningApps()
    }

    @objc private func handleWorkspaceChange(_ note: Notification) {
        refreshRunningApps()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowChrome()
        view.window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return
        }
        if event.keyCode == 53 {
            NSApp.hide(nil)
            return
        }
        if event.charactersIgnoringModifiers?.lowercased() == "r" {
            refreshRunningApps()
            return
        }
        super.keyDown(with: event)
    }

    func handleAppTapped(_ button: AppIconButton) {
        if button.app.app.activate(options: [.activateAllWindows]) {
            NSApp.hide(nil)
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

        panelContent.addSubview(scrollView)
        panelContainer.contentView = panelContent
        view.addSubview(panelContainer)

        NSLayoutConstraint.activate([
            panelContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelContainer.topAnchor.constraint(equalTo: view.topAnchor),
            panelContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: panelContent.leadingAnchor, constant: 28),
            scrollView.trailingAnchor.constraint(equalTo: panelContent.trailingAnchor, constant: -28),
            scrollView.topAnchor.constraint(equalTo: panelContent.topAnchor, constant: 32),
            scrollView.bottomAnchor.constraint(equalTo: panelContent.bottomAnchor, constant: -32)
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
