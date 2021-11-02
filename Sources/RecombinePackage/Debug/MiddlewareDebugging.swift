import CasePaths
import Combine
import CustomDump
import os.signpost

public extension Middleware {
    /// Prints debug messages describing all received local actions.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A middleware that prints debug messages for all received actions.
    func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        debug(
            prefix,
            rawAction: .self,
            refinedAction: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received local actions.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toLocalRawAction: A case path that filters raw actions that are printed.
    ///   - toLocalRefinedAction: A case path that filters refined actions that are printed.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A middleware that prints debug messages for all received actions.
    func debug<LocalRawAction, LocalRefinedAction>(
        _ prefix: String = "",
        rawAction toLocalRawAction: CasePath<RawAction, LocalRawAction>,
        refinedAction toLocalRefinedAction: CasePath<RefinedAction, LocalRefinedAction>,
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        #if DEBUG
            let printPrefix = "\(prefix.isEmpty.if(true: "", false: "\(prefix): "))middleware"

            return .init(
                internal: { state, action, dispatch, environment -> [RefinedAction] in
                    let debugEnvironment = toDebugEnvironment(environment)
                    let transformed = transform(
                        state,
                        action,
                        { dispatchedActions in
                            debugEnvironment.queue.async {
                                let description = debugActionOutput(
                                    received: .refined(action),
                                    produced: dispatchedActions,
                                    rawAction: toLocalRawAction,
                                    refinedAction: toLocalRefinedAction,
                                    actionFormat: actionFormat
                                )
                                debugEnvironment.printer("\(printPrefix) redispatched: \(description)")
                            }
                            dispatch(dispatchedActions)
                        },
                        environment
                    )
                    debugEnvironment.queue.async {
                        let description = debugActionOutput(
                            received: .refined(action),
                            produced: [.refined(transformed)],
                            rawAction: toLocalRawAction,
                            refinedAction: toLocalRefinedAction,
                            actionFormat: actionFormat
                        )
                        debugEnvironment.printer("\(printPrefix) produced: \(description)")
                    }
                    return transformed
                }
            )
        #else
            return self
        #endif
    }
}
