//
//  SettingsTabContainer.swift
//  ActivateDock
//
//  Top-level layout for the settings window: a centered segmented
//  control acts as the nav bar; the body below swaps between the
//  pages it was initialised with. Pages are retained, so each tab
//  preserves its scroll position across switches.
//

import Cocoa

final class SettingsTabContainer: NSView {

    struct Page {
        let title: String
        let view: NSView
    }

    private let segmented = NSSegmentedControl()
    private let body = NSView()
    private let pages: [Page]

    init(pages: [Page]) {
        self.pages = pages
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupSegmented()
        setupLayout()
        if !pages.isEmpty { select(index: 0) }
    }
    required init?(coder: NSCoder) { nil }

    private func setupSegmented() {
        segmented.segmentStyle = .texturedRounded
        segmented.trackingMode = .selectOne
        segmented.segmentCount = pages.count
        for (i, page) in pages.enumerated() {
            segmented.setLabel(page.title, forSegment: i)
            segmented.setWidth(96, forSegment: i)
        }
        segmented.target = self
        segmented.action = #selector(segmentChanged)
        segmented.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLayout() {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(segmented)
        body.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        addSubview(body)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),
            segmented.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            segmented.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            body.topAnchor.constraint(equalTo: separator.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func segmentChanged() {
        select(index: segmented.selectedSegment)
    }

    private func select(index: Int) {
        guard index >= 0, index < pages.count else { return }
        segmented.selectedSegment = index
        for view in body.subviews { view.removeFromSuperview() }
        let page = pages[index].view
        page.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(page)
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: body.topAnchor),
            page.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            page.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: body.trailingAnchor)
        ])
    }
}
