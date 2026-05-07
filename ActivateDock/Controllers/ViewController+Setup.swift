//
//  ViewController+Setup.swift
//  ActivateDock
//

import Cocoa

extension ViewController {
    func setupPanel() {
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
        panelContent.addSubview(searchScrollView)
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

    func setupSearch() {
        searchField.placeholderString = "search"
        searchField.font = .systemFont(ofSize: 22)
        searchField.sendsWholeSearchString = true
        searchField.sendsSearchStringImmediately = false
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        (searchField.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        (searchField.cell as? NSSearchFieldCell)?.cancelButtonCell = nil
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(handleSearchSubmit(_:))

        searchClearButton.isBordered = false
        searchClearButton.bezelStyle = .regularSquare
        searchClearButton.imagePosition = .imageOnly
        searchClearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        searchClearButton.contentTintColor = .secondaryLabelColor
        searchClearButton.target = self
        searchClearButton.action = #selector(handleSearchClear(_:))
        searchClearButton.isHidden = true
        searchClearButton.setButtonType(.momentaryChange)

        searchFieldBox.material = .menu
        searchFieldBox.blendingMode = .withinWindow
        searchFieldBox.state = .active
        searchFieldBox.wantsLayer = true
        searchFieldBox.layer?.cornerRadius = 20
        searchFieldBox.layer?.masksToBounds = true
        searchFieldBox.alphaValue = 0.75

        searchBackground.material = .menu
        searchBackground.blendingMode = .withinWindow
        searchBackground.state = .active
        searchBackground.wantsLayer = true
        searchBackground.layer?.cornerRadius = 12
        searchBackground.layer?.masksToBounds = true
        searchBackground.alphaValue = 0.75
        searchBackground.isHidden = true

        searchScrollView.drawsBackground = false
        searchScrollView.hasVerticalScroller = true
        searchScrollView.hasHorizontalScroller = false
        searchScrollView.automaticallyAdjustsContentInsets = false
        searchScrollView.scrollerStyle = .overlay
        searchScrollView.wantsLayer = true
        searchScrollView.layer?.cornerRadius = 12
        searchScrollView.layer?.masksToBounds = true
        searchScrollView.isHidden = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.resizingMask = [.autoresizingMask]
        searchResultsTable.addTableColumn(column)
        searchResultsTable.headerView = nil
        searchResultsTable.style = .plain
        searchResultsTable.backgroundColor = .clear
        searchResultsTable.gridStyleMask = []
        searchResultsTable.intercellSpacing = NSSize(width: 0, height: 4)
        searchResultsTable.rowHeight = 44
        searchResultsTable.allowsEmptySelection = false
        searchResultsTable.allowsMultipleSelection = false
        searchResultsTable.selectionHighlightStyle = .none
        searchResultsTable.dataSource = self
        searchResultsTable.delegate = self
        searchResultsTable.target = self
        searchResultsTable.doubleAction = #selector(handleSearchSubmit(_:))
        searchScrollView.documentView = searchResultsTable

        setupSearchHint()
    }

    func setupCollectionView() {
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
}
