import Combine
import os.signpost

public extension Thunk {
    func signpost(
        _ prefix: String = "",
        log: OSLog = OSLog(
            subsystem: "com.reswift.recombine",
            category: "Thunk Instrumentation"
        )
    ) -> Self {
        guard log.signpostsEnabled else { return self }

        // NB: Prevent rendering as "N/A" in Instruments
        let zeroWidthSpace = "\u{200B}"

        return .init {
            transform($0, $1, $2).thunkSignpost(
                prefix.isEmpty.if(
                    true: zeroWidthSpace,
                    false: "[\(prefix)] "
                ),
                log: log,
                actionOutput: debugCaseOutput($1)
            )
        }
    }
}

extension Publisher where Failure == Never {
    func thunkSignpost(
        _ prefix: String,
        log: OSLog,
        actionOutput: String
    ) -> Publishers.HandleEvents<Self> {
        let sid = OSSignpostID(log: log)
        let token = DebugToken().description
        let printPrefix = "\(prefix)-\(token)"
        return handleEvents(
            receiveSubscription: { _ in
                if log.signpostsEnabled {
                    os_signpost(
                        .begin, log: log, name: "Thunk", signpostID: sid, "%sStarted from %s", printPrefix,
                        actionOutput
                    )
                }
            },
            receiveOutput: {
                if log.signpostsEnabled {
                    os_signpost(
                        .event, log: log, name: "Thunk Output", "%sOutput from %s: %s", printPrefix, actionOutput, debugCaseOutput($0)
                    )
                }
            },
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    if log.signpostsEnabled {
                        os_signpost(.end, log: log, name: "Thunk", signpostID: sid, "%sFinished", printPrefix)
                    }
                }
            },
            receiveCancel: {
                if log.signpostsEnabled {
                    os_signpost(.end, log: log, name: "Thunk", signpostID: sid, "%sCancelled", printPrefix)
                }
            }
        )
    }
}
