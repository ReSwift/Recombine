import Combine

public class LensedStore<BaseState, SubState: Equatable, RawAction, BaseRefinedAction, SubRefinedAction>: StoreProtocol {
    public typealias StoreType = BaseStore<BaseState, RawAction, BaseRefinedAction>
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }
    public let underlying: BaseStore<BaseState, RawAction, BaseRefinedAction>
    public let keyPath: KeyPath<BaseState, SubState>
    public let actions = PassthroughSubject<SubRefinedAction, Never>()
    public let actionPromotion: (SubRefinedAction) -> BaseRefinedAction
    private var cancellables = Set<AnyCancellable>()

    public required init(store: StoreType, lensing keyPath: KeyPath<BaseState, SubState>, actionPromotion: @escaping (SubRefinedAction) -> BaseRefinedAction) {
        self.underlying = store
        self.keyPath = keyPath
        self.actionPromotion = actionPromotion
        state = store.state[keyPath: keyPath]
        store.$state
            .map { $0[keyPath: keyPath] }
            .removeDuplicates()
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &cancellables)

        actions.sink { [unowned self] action in
            self.underlying.dispatch(refined: actionPromotion(action))
        }
        .store(in: &cancellables)
    }

    public func lensing<NewState, NewAction>(
        state keyPath: KeyPath<SubState, NewState>,
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        NewAction
    > {
        .init(
            store: underlying,
            lensing: self.keyPath.appending(path: keyPath),
            actionPromotion: { self.actionPromotion(transform($0)) }
        )
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == SubRefinedAction {
        actions.forEach(self.actions.send)
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        underlying.dispatch(raw: actions)
    }
}

extension LensedStore where BaseRefinedAction == SubRefinedAction {
    convenience init(store: StoreType, lensing keyPath: KeyPath<BaseState, SubState>) {
        self.init(store: store, lensing: keyPath, actionPromotion: { $0 })
    }
}
