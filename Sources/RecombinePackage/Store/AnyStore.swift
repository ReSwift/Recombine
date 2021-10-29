import Combine

public class AnyStore<State: Equatable, RawAction, RefinedAction>: StoreProtocol {
    private let _dispatch: (Bool, Bool, [ActionStrata<RawAction, RefinedAction>]) -> Void
    private var cancellable: AnyCancellable?

    @Published
    public private(set) var state: State
    public var statePublisher: AnyPublisher<State, Never> {
        $state.eraseToAnyPublisher()
    }

    public init<Store: StoreProtocol>(_ store: Store)
    where Store.State == State,
    Store.RawAction == RawAction,
    Store.RefinedAction == RefinedAction {
        state = store.state
        _dispatch = store.dispatch
        cancellable = store.statePublisher
            .dropFirst()
            .assign(to: \.state, on: self)
    }

    public func dispatch<S>(serially: Bool, collect: Bool, actions: S) where S : Sequence, S.Element == Action {
        _dispatch(serially, collect, .init(actions))
    }
}
