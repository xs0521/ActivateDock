//
//  MemoryProbe.swift
//  ActivateDock
//
//  Memory aggregation strategy mirrors Tencent Lemon's `memoryTopRepeater`:
//  enumerate every running process via sysctl(KERN_PROC_ALL), read each
//  pid's resident_size via proc_pidinfo(PROC_PIDTASKINFO), then DFS the
//  ppid tree from each tracked root and sum RSS over all descendants.
//

import Darwin
import Foundation

enum MemoryProbe {
    static func format(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb < 10 {
            return String(format: "%.1f MB", mb)
        } else if mb < 1024 {
            return String(format: "%.0f MB", mb)
        } else {
            return String(format: "%.2f GB", mb / 1024.0)
        }
    }

    /// Returns RSS for a single pid via proc_pidinfo(PROC_PIDTASKINFO).
    private static func rss(of pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let written = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard written == size else { return 0 }
        return info.pti_resident_size
    }

    /// Snapshot every (pid, ppid) on the system using sysctl(KERN_PROC_ALL).
    private static func snapshotProcessTable() -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var len = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else {
            return []
        }
        let stride = MemoryLayout<kinfo_proc>.stride
        let capacity = max(len / stride + 32, 1)
        var bufferLen = capacity * stride
        let buffer = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        guard sysctl(&mib, UInt32(mib.count), buffer, &bufferLen, nil, 0) == 0 else {
            return []
        }
        let actual = bufferLen / stride
        return Array(UnsafeBufferPointer(start: buffer, count: actual))
    }

    /// Sum RSS of every pid in each root's descendant tree (root inclusive).
    /// Mirrors Lemon's post-order traversal but uses iterative DFS per root,
    /// which is enough for our handful of tracked roots.
    static func aggregateByPpidTree(roots: Set<pid_t>) -> [pid_t: UInt64] {
        var totals: [pid_t: UInt64] = [:]
        for r in roots { totals[r] = 0 }
        guard !roots.isEmpty else { return totals }

        let table = snapshotProcessTable()
        guard !table.isEmpty else { return totals }

        var rssOf: [pid_t: UInt64] = [:]
        var children: [pid_t: [pid_t]] = [:]
        rssOf.reserveCapacity(table.count)
        children.reserveCapacity(table.count)

        for entry in table {
            let pid = entry.kp_proc.p_pid
            let ppid = entry.kp_eproc.e_ppid
            guard pid > 0 else { continue }
            rssOf[pid] = rss(of: pid)
            children[ppid, default: []].append(pid)
        }

        for root in roots {
            var sum: UInt64 = rssOf[root] ?? 0
            var stack: [pid_t] = children[root] ?? []
            while let p = stack.popLast() {
                sum += rssOf[p] ?? 0
                if let kids = children[p] { stack.append(contentsOf: kids) }
            }
            totals[root] = sum
        }
        return totals
    }
}

final class MemoryMonitor {
    static let shared = MemoryMonitor()

    static let didUpdateNotification = Notification.Name("MemoryMonitor.didUpdate")
    static let pidKey = "pid"
    static let bytesKey = "bytes"

    private let interval: TimeInterval = 2
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "MemoryMonitor.sample", qos: .utility)
    private var pids = Set<pid_t>()
    private let lock = NSLock()

    private init() {}

    func track(_ pid: pid_t) {
        lock.lock()
        let wasEmpty = pids.isEmpty
        pids.insert(pid)
        lock.unlock()
        if wasEmpty { startTimer() }
    }

    func untrack(_ pid: pid_t) {
        lock.lock()
        pids.remove(pid)
        let nowEmpty = pids.isEmpty
        lock.unlock()
        if nowEmpty { stopTimer() }
    }

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(50), repeating: interval)
        t.setEventHandler { [weak self] in self?.sample() }
        timer = t
        t.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func sample() {
        lock.lock()
        let snapshot = pids
        lock.unlock()

        let totals = MemoryProbe.aggregateByPpidTree(roots: snapshot)

        DispatchQueue.main.async {
            for pid in snapshot {
                var info: [String: Any] = [Self.pidKey: pid]
                if let bytes = totals[pid], bytes > 0 { info[Self.bytesKey] = bytes }
                NotificationCenter.default.post(
                    name: Self.didUpdateNotification,
                    object: nil,
                    userInfo: info
                )
            }
        }
    }
}
