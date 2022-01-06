import CasePaths
import CustomDump
import Dispatch

public extension Reducer {
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
    /// - Returns: A reducer that prints debug messages for all received actions.
    func debug(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        debug(
            prefix,
            state: { $0 },
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
    /// - Returns: A reducer that prints debug messages for all received actions.
    func debugActions(
        _ prefix: String = "",
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        debug(
            prefix,
            state: { _ in () },
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
    ///   - toLocalState: A function that filters state to be printed.
    ///   - toLocalAction: A case path that filters actions that are printed.
    ///   - toDebugEnvironment: A function that transforms an environment into a debug environment by
    ///     describing a print function and a queue to print from. Defaults to a function that ignores
    ///     the environment and returns a default ``DebugEnvironment`` that uses Swift's `print`
    ///     function and a background queue.
    /// - Returns: A reducer that prints debug messages for all received actions.
    func debug<LocalState, LocalAction>(
        _ prefix: String = "",
        state toLocalState: @escaping (State) -> LocalState,
        action toLocalAction: CasePath<SyncAction, LocalAction>,
        actionFormat: ActionFormat = .prettyPrint,
        environment toDebugEnvironment: @escaping (Environment) -> DebugEnvironment = { _ in
            DebugEnvironment()
        }
    ) -> Self {
        #if DEBUG
            .init { state, action, environment in
                let previousState = toLocalState(state)
                self(state: &state, action: action, environment: environment)
                let nextState = toLocalState(state)
                let debugEnvironment = toDebugEnvironment(environment)
                debugEnvironment.queue.async {
                    let debugOutput = debugActionOutput(
                        received: EitherAction<Never, SyncAction>.sync(action),
                        produced: [],
                        asyncAction: .self,
                        syncAction: toLocalAction,
                        actionFormat: actionFormat
                    )
                    let stateOutput = (LocalState.self == Void.self).if(
                        true: "",
                        false: diff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
                    )
                    debugEnvironment.printer(
                        """
                        \(prefix.isEmpty.if(true: "", false: "\(prefix): "))reducer received:\(debugOutput)state changed:
                        \(stateOutput.indent(by: 4))
                        """
                    )
                }
            }
        #else
            self
        #endif
    }
}
