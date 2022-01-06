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
            asyncAction: .self,
            syncAction: .self,
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
    ///   - toLocalAsyncAction: A case path that filters async actions that are printed.
    ///   - toLocalSyncAction: A case path that filters sync actions that are printed.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A middleware that prints debug messages for all received actions.
    func debug<LocalAsyncAction, LocalSyncAction>(
        _ prefix: String = "",
        asyncAction toLocalAsyncAction: CasePath<AsyncAction, LocalAsyncAction>,
        syncAction toLocalSyncAction: CasePath<SyncAction, LocalSyncAction>,
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        #if DEBUG
            let printPrefix = "\(prefix.isEmpty.if(true: "", false: "\(prefix): "))middleware"

            return .init(
                internal: { state, action, dispatch, environment -> [SyncAction] in
                    let debugEnvironment = toDebugEnvironment(environment)
                    let transformed = transform(
                        state,
                        action,
                        { dispatchedActions in
                            debugEnvironment.queue.async {
                                let description = debugActionOutput(
                                    received: .sync(action),
                                    produced: dispatchedActions,
                                    asyncAction: toLocalAsyncAction,
                                    syncAction: toLocalSyncAction,
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
                            received: .sync(action),
                            produced: [.sync(transformed)],
                            asyncAction: toLocalAsyncAction,
                            syncAction: toLocalSyncAction,
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
