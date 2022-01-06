import CasePaths
import Combine
import CustomDump
import os.signpost

public extension Thunk {
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
    /// - Returns: A thunk that prints debug messages for all received actions.
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
    /// - Returns: A thunk that prints debug messages for all received actions.
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
            return .init { state, receivedAction, environment -> AnyPublisher<Action, Never> in
                let debugEnvironment = toDebugEnvironment(environment)
                let transformed = transform(state, receivedAction, environment)
                let printPrefix = "\(prefix.isEmpty.if(true: "", false: "\(prefix): "))thunk"
                return transformed
                    .handleEvents(
                        receiveSubscription: { _ in
                            debugEnvironment.printer("\(printPrefix) started")
                        },
                        receiveOutput: { action in
                            let description = debugActionOutput(
                                received: .async(receivedAction),
                                produced: [action],
                                asyncAction: toLocalAsyncAction,
                                syncAction: toLocalSyncAction,
                                actionFormat: actionFormat
                            )
                            debugEnvironment.printer("\(printPrefix) produced:\(description)")
                        },
                        receiveCompletion: { _ in
                            debugEnvironment.printer("\(printPrefix) finished")
                        },
                        receiveCancel: {
                            debugEnvironment.printer("\(printPrefix) cancelled")
                        }
                    )
                    .eraseToAnyPublisher()
            }
        #else
            return self
        #endif
    }
}
