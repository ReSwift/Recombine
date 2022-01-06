import Combine

public class AnyStore<State: Equatable, AsyncAction, SyncAction>: StoreProtocol {
    private let _dispatch: (Bool, Bool, [EitherAction<AsyncAction, SyncAction>]) -> Void
    private var cancellable: AnyCancellable?

    @Published
    public private(set) var state: State
    public var statePublisher: AnyPublisher<State, Never> {
        $state.eraseToAnyPublisher()
    }

    public init<Store: StoreProtocol>(_ store: Store)
        where Store.State == State,
        Store.AsyncAction == AsyncAction,
        Store.SyncAction == SyncAction
    {
        state = store.state
        _dispatch = store.dispatch
        cancellable = store.statePublisher
            .dropFirst()
            .assign(to: \.state, on: self)
    }

    public func dispatch<S>(serially: Bool, collect: Bool, actions: S) where S: Sequence, S.Element == Action {
        _dispatch(serially, collect, .init(actions))
    }
}
