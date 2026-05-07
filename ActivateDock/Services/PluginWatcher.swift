//
//  PluginWatcher.swift
//  ActivateDock
//
//  FSEventStream wrapper that watches the user's Plugins directory tree
//  and fires a debounced callback when anything inside changes — used
//  to trigger WorkflowRegistry.reload() without an app restart.
//
//  Events bursty by nature (copying a plugin folder fires dozens), so
//  changes are coalesced over a 300ms window.
//

import Foundation
import CoreServices

final class PluginWatcher {

    private var stream: FSEventStreamRef?
    private var pendingReload: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.3
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit { stop() }

    func start(at path: String) {
        guard stream == nil else { return }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        var context = FSEventStreamContext(
            version: 0,
            info: pointer,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = [path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<PluginWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.scheduleReload()
            },
            &context,
            paths,
            UInt64(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            flags
        ) else {
            NSLog("[PluginWatcher] FSEventStreamCreate failed for \(path)")
            return
        }
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        FSEventStreamStart(s)
        stream = s
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
        pendingReload?.cancel()
        pendingReload = nil
    }

    private func scheduleReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
