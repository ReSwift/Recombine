import Combine

public class StoreTransform<BaseState, SubState, RawAction, RefinedAction>: StoreProtocol {
    public typealias StoreType = Store<BaseState, RawAction, RefinedAction>
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }
    public let underlying: Store<BaseState, RawAction, RefinedAction>
    public let keyPath: KeyPath<BaseState, SubState>
    private var cancellables = Set<AnyCancellable>()

    public required init(store: StoreType, lensing keyPath: KeyPath<BaseState, SubState>) {
        self.underlying = store
        self.keyPath = keyPath
        state = store.state[keyPath: keyPath]
        store.$state
            .map { $0[keyPath: keyPath] }
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &cancellables)
    }

    public func lensing<NewState>(_ keyPath: KeyPath<SubState, NewState>) -> StoreTransform<BaseState, NewState, RawAction, RefinedAction> {
        .init(store: underlying, lensing: self.keyPath.appending(path: keyPath))
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        underlying.dispatch(refined: actions)
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        underlying.dispatch(raw: actions)
    }
}
