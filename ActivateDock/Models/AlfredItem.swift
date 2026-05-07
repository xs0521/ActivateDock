//
//  AlfredItem.swift
//  ActivateDock
//

import Foundation

struct AlfredIcon: Decodable {
    let path: String?
}

struct AlfredItem: Decodable {
    let title: String
    let subtitle: String?
    let arg: String?
    let icon: AlfredIcon?
}

struct AlfredScriptFilterOutput: Decodable {
    let items: [AlfredItem]
}
