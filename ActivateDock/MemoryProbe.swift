//
//  MemoryProbe.swift
//  ActivateDock
//

import Darwin
import Foundation

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t

enum MemoryProbe {
    static func physFootprint(pid: pid_t) -> UInt64? {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard result == 0 else { return nil }
        return info.ri_phys_footprint
    }

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

    /// Sum phys_footprint of every running pid whose "responsible pid" matches one of `roots`.
    /// This is how Activity Monitor groups helper processes (Chrome Helper, Electron renderers, etc.)
    /// under their main app.
    static func aggregateByResponsible(roots: Set<pid_t>) -> [pid_t: UInt64] {
        var totals: [pid_t: UInt64] = [:]
        for r in roots { totals[r] = 0 }
        guard !roots.isEmpty else { return totals }

        let probeBytes = proc_listallpids(nil, 0)
        guard probeBytes > 0 else { return totals }
        let stride = MemoryLayout<pid_t>.size
        let capacity = Int(probeBytes) / stride + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let written = proc_listallpids(&pids, Int32(capacity * stride))
        guard written > 0 else { return totals }
        let count = Int(written) / stride

        for i in 0..<count {
            let p = pids[i]
            guard p > 0 else { continue }
            let resp = responsibility_get_pid_responsible_for_pid(p)
            guard resp > 0, totals[resp] != nil else { continue }
            if let bytes = physFootprint(pid: p) {
                totals[resp]! += bytes
            }
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

        let totals = MemoryProbe.aggregateByResponsible(roots: snapshot)

        DispatchQueue.main.async {
            for pid in snapshot {
                var info: [String: Any] = [Self.pidKey: pid]
                if let bytes = totals[pid] { info[Self.bytesKey] = bytes }
                NotificationCenter.default.post(
                    name: Self.didUpdateNotification,
                    object: nil,
                    userInfo: info
                )
            }
        }
    }
}
