import Combine

public struct Thunk<State, Input, Output> {
    public typealias StatePublisher = Published<State>.Publisher
    public typealias Function = (StatePublisher, Input) -> AnyPublisher<ActionStrata<Input, Output>, Never>
    internal let transform: Function

    /// Create a passthrough `Thunk`.
    public init() where Input == Output {
        transform = { Just(.refined($1)).eraseToAnyPublisher() }
    }

    /// Initialises the thunk with a transformative function.
    /// - parameter transform: The function that will be able to modify passed actions.
    public init<P: Publisher>(
        _ transform: @escaping (StatePublisher, Input) -> P
    ) where P.Output == ActionStrata<Input, Output>, P.Failure == Never {
        self.transform = { transform($0, $1).eraseToAnyPublisher() }
    }
}
