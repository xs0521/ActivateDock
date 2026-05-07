//
//  SearchFieldEditor.swift
//  ActivateDock
//

import Cocoa

final class SearchFieldEditor: NSTextView {
    var onCompositionChange: (() -> Void)?

    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: 100, height: 17))
        isFieldEditor = true
    }

    override func setMarkedText(_ string: Any,
                                selectedRange: NSRange,
                                replacementRange: NSRange) {
        super.setMarkedText(string,
                            selectedRange: selectedRange,
                            replacementRange: replacementRange)
        onCompositionChange?()
    }

    override func unmarkText() {
        super.unmarkText()
        onCompositionChange?()
    }
}
