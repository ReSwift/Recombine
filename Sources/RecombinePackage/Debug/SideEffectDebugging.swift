import CasePaths
import CustomDump
import Dispatch

public extension SideEffect {
    /// Prints debug messages describing all received actions and state mutations.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A side-effect that prints debug messages for all received actions.
    func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        debug(
            prefix,
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received actions.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A side-effect that prints debug messages for all received actions.
    func debugActions(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        debug(
            prefix,
            action: .self,
            actionFormat: actionFormat,
            environment: toDebugEnvironment
        )
    }

    /// Prints debug messages describing all received local actions and local state mutations.
    ///
    /// Printing is only done in debug (`#if DEBUG`) builds.
    ///
    /// - Parameters:
    ///   - prefix: A string with which to prefix all debug messages.
    ///   - toLocalAction: A case path that filters actions that are printed.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A side-effect that prints debug messages for all received actions.
    func debug<LocalAction>(
        _ prefix: String = "",
        action toLocalAction: CasePath<SyncAction, LocalAction>,
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        #if DEBUG
            .init { action, environment in
                let debugEnvironment = toDebugEnvironment(environment)
                debugEnvironment.queue.async {
                    let debugOutput = debugActionOutput(
                        received: EitherAction<Never, SyncAction>.sync(action),
                        produced: [],
                        asyncAction: .self,
                        syncAction: toLocalAction,
                        actionFormat: actionFormat
                    )
                    debugEnvironment.printer(
                        """
                        \(prefix.isEmpty.if(true: "", false: "\(prefix): "))side-effect received:\(debugOutput)
                        """
                    )
                }
                closure(action, environment)
            }
        #else
            self
        #endif
    }
}
