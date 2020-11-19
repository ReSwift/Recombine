import Combine

public class AnyStore<BaseState, SubState, RawAction, RefinedAction>: StoreProtocol {
    public let underlying: Store<BaseState, RawAction, RefinedAction>
    public let keyPath: KeyPath<BaseState, SubState>
    private var cancellables = Set<AnyCancellable>()
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }

    public required init<Store: StoreProtocol>(_ store: Store)
    where Store.BaseState == BaseState,
          Store.SubState == SubState,
          Store.RawAction == RawAction,
          Store.RefinedAction == RefinedAction
    {
        underlying = store.underlying
        keyPath = store.keyPath
        self.state = store.state
        store.statePublisher.sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }

    public func lensing<NewState>(_ keyPath: KeyPath<SubState, NewState>) -> StoreTransform<BaseState, NewState, RawAction, RefinedAction> {
        .init(store: underlying, lensing: self.keyPath.appending(path: keyPath))
    }

    public func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        underlying.dispatch(refined: actions)
    }

    public func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        underlying.dispatch(raw: actions)
    }
}
