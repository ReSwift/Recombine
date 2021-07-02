public protocol Reducer {
    associatedtype State
    associatedtype Action
    associatedtype Transform

    var transform: Transform { get }
    init()
    init(_ transform: Transform)
    func reduce(state: State, action: Action, redispatch: (Action...) -> Void) -> State
    func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform
}

public extension Reducer {
    init(_ reducers: Self...) {
        self = .init(reducers)
    }

    init<S: Sequence>(_ reducers: S) where S.Element: Reducer, S.Element.Transform == Transform {
        self = reducers.reduce(Self()) {
            $0.concat($1)
        }
    }
}

public struct PureReducer<State, Action>: Reducer {
    public typealias Transform = (_ state: State, _ action: Action, _ redispatch: (Action...) -> Void) -> State
    public let transform: Transform

    public init() {
        transform = { state, _, _ in state }
    }

    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }

    public func callAsFunction(state: State, action: Action, redispatch: (Action...) -> Void) -> State {
        transform(state, action, redispatch)
    }

    public func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform {
        Self.init { state, action, redispatch in
            other.transform(self.transform(state, action, redispatch), action, redispatch)
        }
    }

    public func reduce(state: State, action: Action, redispatch: (Action...) -> Void) -> State {
        transform(state, action, redispatch)
    }
}

public struct MutatingReducer<State, Action>: Reducer {
    public typealias Transform = (_ state: inout State, _ action: Action, _ redispatch: (Action...) -> Void) -> Void
    public let transform: Transform

    public init() {
        transform = { _, _, _ in }
    }

    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }

    public func callAsFunction(state: inout State, action: Action, redispatch: (Action...) -> Void) {
        transform(&state, action, redispatch)
    }

    public func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform {
        Self.init { state, action, redispatch in
            self.transform(&state, action, redispatch)
            other.transform(&state, action, redispatch)
        }
    }

    public func reduce(state: State, action: Action, redispatch: (Action...) -> Void) -> State {
        var s = state
        transform(&s, action, redispatch)
        return s
    }
}
