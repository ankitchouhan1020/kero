//
//  TerminalProcessSnapshot.swift
//  kero
//

import Darwin
import Foundation

/// Best-effort metadata for the process group currently owning a terminal.
struct TerminalProcessSnapshot: Equatable {
    struct Member: Equatable, Identifiable {
        var id: pid_t { pid }
        let pid: pid_t
        let name: String
        let argv: [String]?

        var argv0: String? { argv?.first }
    }

    let processGroupID: pid_t
    let members: [Member]

    private static let maximumProcessCount = 65_536
    private static let maximumArgumentBytes = 1_048_576

    /// Resolves the shell's foreground process group, then snapshots its
    /// members. Races and inaccessible kernel metadata fail closed.
    static func capture(shellPID: pid_t) -> Self? {
        guard shellPID > 0, let shell = bsdInfo(for: shellPID) else { return nil }
        let processGroupID = pid_t(shell.e_tpgid)
        guard processGroupID > 0, let pids = processIDs(in: processGroupID) else {
            return nil
        }

        let members = pids.compactMap { pid -> Member? in
            guard let info = bsdInfo(for: pid),
                  pid_t(info.pbi_pgid) == processGroupID
            else { return nil }
            return Member(pid: pid, name: processName(pid), argv: processArguments(pid))
        }.sorted { $0.pid < $1.pid }

        return Self(processGroupID: processGroupID, members: members)
    }

    private static func processIDs(in processGroupID: pid_t) -> [pid_t]? {
        let count = Int(proc_listpgrppids(processGroupID, nil, 0))
        guard count > 0, count < maximumProcessCount else { return nil }

        var pids = [pid_t](repeating: 0, count: min(count + 16, maximumProcessCount))
        let bytes = Int32(pids.count * MemoryLayout<pid_t>.size)
        let result = pids.withUnsafeMutableBufferPointer {
            proc_listpgrppids(processGroupID, $0.baseAddress, bytes)
        }
        guard result > 0, result < pids.count else { return nil }
        return Array(pids.prefix(Int(result))).filter { $0 > 0 }
    }

    private static func bsdInfo(for pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else {
            return nil
        }
        return info
    }

    private static func processName(_ pid: pid_t) -> String {
        var bytes = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let count = bytes.withUnsafeMutableBufferPointer {
            proc_name(pid, $0.baseAddress, UInt32($0.count))
        }
        guard count > 0 else { return "" }
        return String(cString: bytes)
    }

    private static func processArguments(_ pid: pid_t) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size >= MemoryLayout<Int32>.size,
              size <= maximumArgumentBytes
        else { return nil }

        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes {
            sysctl(&mib, UInt32(mib.count), $0.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return parseArguments(Array(bytes.prefix(size)))
    }

    /// Parses Darwin's KERN_PROCARGS2 format: argc, executable path, padding,
    /// then argc null-terminated argument strings.
    static func parseArguments(_ bytes: [UInt8]) -> [String]? {
        let width = MemoryLayout<Int32>.size
        guard bytes.count >= width else { return nil }
        let argc = bytes.prefix(width).enumerated().reduce(UInt32(0)) {
            $0 | UInt32($1.element) << UInt32($1.offset * 8)
        }
        guard argc <= bytes.count else { return nil }

        var cursor = width
        guard let executableEnd = bytes[cursor...].firstIndex(of: 0) else { return nil }
        cursor = executableEnd
        while cursor < bytes.count, bytes[cursor] == 0 { cursor += 1 }

        var arguments: [String] = []
        arguments.reserveCapacity(Int(argc))
        while arguments.count < Int(argc) {
            guard cursor < bytes.count,
                  let end = bytes[cursor...].firstIndex(of: 0)
            else { return nil }
            arguments.append(String(decoding: bytes[cursor..<end], as: UTF8.self))
            cursor = end + 1
        }
        return arguments
    }
}
