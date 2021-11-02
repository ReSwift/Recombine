import Combine

/// Middleware is a structure that allows you to transform refined actions, filter them, or add to them,
/// Refined actions produced by Middleware are then forwarded to the main reducer.
public struct Middleware<State, RawAction, RefinedAction, Environment> {
    /// A function to dispatch actions such that they flow through all of the `Middleware` again.
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    public typealias Dispatch = (Action...) -> Void
    public typealias Function = (State, RefinedAction, ([Action]) -> Void, Environment) -> [RefinedAction]
    internal let transform: Function

    /// Create a passthrough Middleware.
    public init() {
        transform = { _, action, _, _ in [action] }
    }

    /// Create a `Middleware` out of multiple other `Middleware`.
    public init(_ middlewares: Self...) {
        self = middlewares.reduce(.init()) { $0.appending($1) }
    }

    /// Initialises the middleware with a transformative function.
    /// - parameter transform: The function that will be able to modify passed actions.
    public init<S: Sequence>(
        _ transform: @escaping (State, RefinedAction, Dispatch, Environment) -> S
    ) where S.Element == RefinedAction {
        self.init { state, action, dispatch, environment in
            transform(state, action, { dispatch($0) }, environment)
        }
    }

    init<S: Sequence>(
        internal transform: @escaping (State, RefinedAction, ([Action]) -> Void, Environment) -> S
    ) where S.Element == RefinedAction {
        self.transform = { .init(transform($0, $1, $2, $3)) }
    }

    /// Concatenates the transform function of the passed `Middleware` onto the callee's transform.
    public func appending(_ other: Self) -> Self {
        .init { state, action, dispatch, environment in
            self.transform(state, action, dispatch, environment).flatMap {
                other.transform(state, $0, dispatch, environment)
            }
        }
    }

    func callAsFunction(state: State, action: RefinedAction, dispatch: ([Action]) -> Void, environment: Environment) -> [RefinedAction] {
        transform(state, action, dispatch, environment)
    }
}
