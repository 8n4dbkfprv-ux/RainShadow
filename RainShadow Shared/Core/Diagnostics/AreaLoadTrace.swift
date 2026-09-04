import Foundation
import os

/// Timing for the one-off work between "the player skipped the intro" and "the
/// area is on screen".
///
/// There was no instrumentation on this path at all — not a signpost, not a
/// print — which is why its cost had to be argued from source rather than read
/// off a trace. Intervals land on Instruments' Points of Interest track under
/// subsystem `RainShadow`, category `AreaLoad`, following the one pattern the
/// codebase already had (`FogMaskRenderer.makeTexture`).
///
/// `RAINSHADOW_TRACE_LOAD=1` additionally echoes each interval to stderr, so a
/// capture launch from a shell reports its own numbers without Instruments
/// attached. That switch is what the before/after comparisons are read from.
enum AreaLoadTrace {
    #if DEBUG
    private static let log = OSLog(subsystem: "RainShadow", category: "AreaLoad")
    #endif

    /// Off unless asked for: this runs on the load path, not the frame loop, but
    /// a shipping launch should still pay nothing for a diagnostic.
    static let isEchoing =
        ProcessInfo.processInfo.environment["RAINSHADOW_TRACE_LOAD"] == "1"

    /// Times `body`, naming it `name` with an optional trailing `detail`.
    ///
    /// `detail` is an autoclosure so a description that costs something to build
    /// is not built when tracing is off.
    static func measure<T>(
        _ name: StaticString,
        _ detail: @autoclosure () -> String = "",
        body: () throws -> T
    ) rethrows -> T {
        #if DEBUG
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        #endif
        let start = isEchoing ? CFAbsoluteTimeGetCurrent() : 0
        defer {
            #if DEBUG
            os_signpost(.end, log: log, name: name, signpostID: signpostID)
            #endif
            if isEchoing {
                report(name, detail(), milliseconds: (CFAbsoluteTimeGetCurrent() - start) * 1_000)
            }
        }
        return try body()
    }

    /// Records a duration measured somewhere else, for work that cannot be
    /// wrapped in a closure — a first frame, or a value the caller already timed.
    static func note(_ name: StaticString, _ detail: @autoclosure () -> String = "",
                     milliseconds: Double) {
        guard isEchoing else { return }
        report(name, detail(), milliseconds: milliseconds)
    }

    private static func report(_ name: StaticString, _ detail: String, milliseconds: Double) {
        let suffix = detail.isEmpty ? "" : " \(detail)"
        let line = String(format: "load: %@%@ %.1f ms\n", String(describing: name), suffix, milliseconds)
        FileHandle.standardError.write(Data(line.utf8))
    }
}
