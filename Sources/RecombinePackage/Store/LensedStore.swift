import Combine

public class LensedStore<BaseState: Equatable, SubState: Equatable, RawAction, BaseRefinedAction, SubRefinedAction>: StoreProtocol {
    public typealias StoreType = BaseStore<BaseState, RawAction, BaseRefinedAction>
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }
    public let underlying: BaseStore<BaseState, RawAction, BaseRefinedAction>
    public let stateLens: (BaseState) -> SubState
    public let actions = PassthroughSubject<[SubRefinedAction], Never>()
    public let actionPromotion: (SubRefinedAction) -> BaseRefinedAction
    private var cancellables = Set<AnyCancellable>()

    public required init(store: StoreType, lensing lens: @escaping (BaseState) -> SubState, actionPromotion: @escaping (SubRefinedAction) -> BaseRefinedAction) {
        underlying = store
        stateLens = lens
        self.actionPromotion = actionPromotion
        state = lens(store.state)
        store.$state
            .map(lens)
            .removeDuplicates()
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &cancellables)
    }

    public func lensing<NewState, NewAction>(
        state lens: @escaping (SubState) -> NewState,
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        NewAction
    > {
        let stateLens = self.stateLens
        return .init(
            store: underlying,
            lensing: { lens(stateLens($0)) },
            actionPromotion: { self.actionPromotion(transform($0)) }
        )
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == SubRefinedAction {
        self.actions.send(.init(actions))
        underlying.dispatch(refined: actions.map(actionPromotion))
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        underlying.dispatch(raw: actions)
    }
}

public extension LensedStore where BaseRefinedAction == SubRefinedAction {
    convenience init(store: StoreType, lensing lens: @escaping (BaseState) -> SubState) {
        self.init(store: store, lensing: lens, actionPromotion: { $0 })
    }
}
