import Combine

/// Middleware is a structure that allows you to transform refined actions, filter them, or add to them,
/// Refined actions produced by Middleware are then forwarded to the main reducer.
public struct Middleware<State, Action> {
    public typealias Function = (State, Action) -> [Action]
    public typealias Transform<Result> = (State, Action) -> Result
    internal let transform: Function

    /// Create a passthrough Middleware.
    public init() {
        transform = { [$1] }
    }

    /// Initialises the middleware with a transformative function.
    /// - parameter transform: The function that will be able to modify passed actions.
    public init<S: Sequence>(
        _ transform: @escaping (State, Action) -> S
    ) where S.Element == Action {
        self.transform = { .init(transform($0, $1)) }
    }

    /// Concatenates the transform function of the passed `Middleware` onto the callee's transform.
    public func concat(_ other: Self) -> Self {
        .init { state, action in
            self.transform(state, action).flatMap {
                other.transform(state, $0)
            }
        }
    }
}
