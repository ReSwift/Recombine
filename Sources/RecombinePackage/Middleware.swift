import Combine

/// Middleware is a dependency injection structure that allows you to transform raw actions into refined ones,
/// Refined actions produced by Middleware are then forwarded to the main reducer.
///
public struct Middleware<State, Input, Output> {
    public typealias StatePublisher = Publishers.First<Published<State>.Publisher>
    public typealias Function = (StatePublisher, Input) -> AnyPublisher<Output, Never>
    public typealias Transform<Result> = (StatePublisher, Output) -> Result
    internal let transform: Function

    /// Create a blank slate Middleware.
    public init() where Input == Output {
        self.transform = { Just($1).eraseToAnyPublisher() }
    }

    /// Initialises the middleware with a transformative function.
    /// - parameter transform: The function that will be able to modify passed actions.
    public init<P: Publisher>(
        _ transform: @escaping (StatePublisher, Input) -> P
    ) where P.Output == Output, P.Failure == Never {
        self.transform = { transform($0, $1).eraseToAnyPublisher() }
    }

    /// Concatenates the transform function of the passed `Middleware` onto the callee's transform.
    public func concat<Result>(_ other: Middleware<State, Output, Result>) -> Middleware<State, Input, Result> {
        .init { state, action in
            self.transform(state, action).flatMap {
                other.transform(state, $0)
            }
        }
    }
}
