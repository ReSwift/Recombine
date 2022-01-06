public struct Reducer<State, SyncAction, Environment> {
    public typealias Transform = (_ state: inout State, _ action: SyncAction, _ environment: Environment) -> Void
    public let transform: Transform

    public init() {
        transform = { _, _, _ in }
    }

    public init(transform: @escaping Transform) {
        self.transform = transform
    }

    public init(_ reducers: Self...) {
        self = .init(reducers)
    }

    public init<S: Sequence>(_ reducers: S) where S.Element == Self {
        self = reducers.reduce(.init()) {
            $0.concat($1)
        }
    }

    public func callAsFunction(state: inout State, action: SyncAction, environment: Environment) {
        transform(&state, action, environment)
    }

    public func concat(_ other: Reducer) -> Self {
        Self.init { state, action, environment in
            self.transform(&state, action, environment)
            other.transform(&state, action, environment)
        }
    }

    public func reduce(state: State, action: SyncAction, environment: Environment) -> State {
        var s = state
        transform(&s, action, environment)
        return s
    }
}
