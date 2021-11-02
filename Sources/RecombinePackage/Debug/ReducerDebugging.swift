import CasePaths
import CustomDump
import Dispatch

/// Determines how the string description of an action should be printed when using the
/// ``Reducer/debug(_:state:action:actionFormat:environment:)`` higher-order reducer.
public enum ActionFormat {
    /// Prints the action in a single line by only specifying the labels of the associated values:
    ///
    /// ```swift
    /// Action.screenA(.row(index:, action: .textChanged(query:)))
    /// ```
    ///
    case labelsOnly
    /// Prints the action in a multiline, pretty-printed format, including all the labels of
    /// any associated values, as well as the data held in the associated values:
    ///
    /// ```swift
    /// Action.screenA(
    ///   ScreenA.row(
    ///     index: 1,
    ///     action: RowAction.textChanged(
    ///       query: "Hi"
    ///     )
    ///   )
    /// )
    /// ```
    ///
    case prettyPrint
}

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
    ) -> Reducer {
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
    ) -> Reducer {
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
        action toLocalAction: CasePath<RefinedAction, LocalAction>,
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
                        received: ActionStrata<Never, RefinedAction>.refined(action),
                        produced: [],
                        rawAction: .self,
                        refinedAction: toLocalAction,
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
