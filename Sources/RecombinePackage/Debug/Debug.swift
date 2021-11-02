import CasePaths
import CustomDump
import Foundation

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

func debugActionOutput<RawAction, RefinedAction, LocalRawAction, LocalRefinedAction>(
    received: ActionStrata<RawAction, RefinedAction>,
    produced: [ActionStrata<RawAction, RefinedAction>],
    rawAction toLocalRawAction: CasePath<RawAction, LocalRawAction>,
    refinedAction toLocalRefinedAction: CasePath<RefinedAction, LocalRefinedAction>,
    actionFormat: ActionFormat
) -> String {
    func debugAction(_ action: ActionStrata<RawAction, RefinedAction>) -> (type: String, actions: [Any?]) {
        switch action.map(raw: toLocalRawAction.extract(from:), refined: toLocalRefinedAction.extract(from:)) {
        case let .raw(actions):
            return ("raw", actions)
        case let .refined(actions):
            return ("refined", actions)
        }
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
