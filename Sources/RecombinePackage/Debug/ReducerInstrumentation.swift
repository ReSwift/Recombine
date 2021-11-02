import Combine
import os.signpost

public extension Reducer {
    /// Instruments the reducer with
    /// [signposts](https://developer.apple.com/documentation/os/logging/recording_performance_data).
    /// Each invocation of the reducer will be measured by an interval.
    ///
    /// To use, build your app for Instruments (⌘I), create a blank instrument, and then use the "+"
    /// icon at top right to add the signpost instrument. Start recording your app (red button at top
    /// left) and then you should see timing information for every action sent to the store.
    ///
    /// Effect instrumentation can be particularly useful for inspecting the lifecycle of long-living
    /// effects. For example, if you start an effect (e.g. a location manager) in `onAppear` and
    /// forget to tear down the effect in `onDisappear`, it will clearly show in Instruments that the
    /// effect never completed.
    ///
    /// - Parameters:
    ///   - prefix: A string to print at the beginning of the formatted message for the signpost.
    ///   - log: An `OSLog` to use for signposts.
    /// - Returns: A reducer that has been enhanced with instrumentation.
    func signpost(
        _ prefix: String = "",
        log: OSLog = OSLog(
            subsystem: "com.reswift.recombine",
            category: "Reducer Instrumentation"
        )
    ) -> Self {
        guard log.signpostsEnabled else { return self }

        // NB: Prevent rendering as "N/A" in Instruments
        let zeroWidthSpace = "\u{200B}"

        let prefix = prefix.isEmpty ? zeroWidthSpace : "[\(prefix)] "

        return .init { state, action, environment in
            var actionOutput: String!
            if log.signpostsEnabled {
                actionOutput = debugCaseOutput(action)
                os_signpost(.begin, log: log, name: "RefinedAction", "%s%s", prefix, actionOutput)
            }
            self(state: &state, action: action, environment: environment)
            if log.signpostsEnabled {
                os_signpost(.end, log: log, name: "RefinedAction")
            }
        }
    }
}

func debugCaseOutput(_ value: Any) -> String {
    func debugCaseOutputHelp(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .enum:
            guard let child = mirror.children.first else {
                let childOutput = "\(value)"
                return childOutput == "\(type(of: value))" ? "" : ".\(childOutput)"
            }
            let childOutput = debugCaseOutputHelp(child.value)
            return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
        case .tuple:
            return mirror.children.map { label, value in
                let childOutput = debugCaseOutputHelp(value)
                return """
                \(label.map { isUnlabelledArgument($0) ? "_:" : "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")
                """
            }
            .joined(separator: ", ")
        default:
            return ""
        }
    }

    return "\(type(of: value))\(debugCaseOutputHelp(value))"
}

private func isUnlabelledArgument(_ label: String) -> Bool {
    label.firstIndex(where: { $0 != "." && !$0.isNumber }) == nil
}
