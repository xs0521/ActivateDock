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
