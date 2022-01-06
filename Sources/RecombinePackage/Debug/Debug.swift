import CasePaths
import CustomDump
import Foundation

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

enum Debug {
    static let queue = DispatchQueue(
        label: "com.reswift.Recombine.DebugEnvironment",
        qos: .background
    )
}

/// An environment for debug-printing reducers.
public struct DebugEnvironment {
    public var printer: (String) -> Void
    public var queue: DispatchQueue

    public init(
        printer: @escaping (String) -> Void = { print($0) },
        queue: DispatchQueue
    ) {
        self.printer = printer
        self.queue = queue
    }

    public init(
        printer: @escaping (String) -> Void = { print($0) }
    ) {
        self.init(printer: printer, queue: Debug.queue)
    }
}

extension String {
    func indent(by indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        return indentation + replacingOccurrences(of: "\n", with: "\n\(indentation)")
    }
}

func debugActionOutput<AsyncAction, SyncAction, LocalAsyncAction, LocalSyncAction>(
    received: EitherAction<AsyncAction, SyncAction>,
    produced: [EitherAction<AsyncAction, SyncAction>],
    asyncAction toLocalAsyncAction: CasePath<AsyncAction, LocalAsyncAction>,
    syncAction toLocalSyncAction: CasePath<SyncAction, LocalSyncAction>,
    actionFormat: ActionFormat
) -> String {
    func debugAction(_ action: EitherAction<AsyncAction, SyncAction>) -> (type: String, actions: [Any?]) {
        let local = action.map(async: toLocalAsyncAction.extract(from:), sync: toLocalSyncAction.extract(from:))
        return (local.caseName, local.allActions)
    }
    func printed(action: Any?) -> String {
        action.map {
            var output = ""
            if actionFormat == .prettyPrint {
                customDump($0, to: &output)
            } else {
                output.write(debugCaseOutput($0))
            }
            return output
        } ?? "nil"
    }
    let debugReceived = debugAction(received)
    let debugProduced = produced.map(debugAction)

    let debugProducedDescription = debugProduced
        .map { type, actions in
            let description = actions
                .map(printed(action:))
                .map { ", " + $0 }
                .joined(separator: "\n")
            let producedDescription = [
                "\((actions.count == 1).if(true: "", false: "["))\(description.dropFirst(actions.count == 1 ? 2 : 1))",
                "]",
            ]
            .dropLast((actions.count == 1).if(true: 1, false: 0))
            .joined(separator: "\n")
            .indent(by: 2)

            return """
            output \(type) action\((actions.count == 1).if(true: "", false: "s")):
            \(producedDescription)
            """
        }
        .joined(separator: "\n")

    return """
    \ninput \(debugReceived.type) action:
    \(printed(action: debugReceived.actions.first.flatMap { $0 }).indent(by: 2))
    \(debugProducedDescription)
    """.indent(by: 2)
}
