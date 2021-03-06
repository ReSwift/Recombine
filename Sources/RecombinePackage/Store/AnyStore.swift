import Combine

public class AnyStore<BaseState: Equatable, SubState: Equatable, RawAction, BaseRefinedAction, SubRefinedAction>: StoreProtocol {
    public let underlying: BaseStore<BaseState, RawAction, BaseRefinedAction>
    public let stateLens: (BaseState) -> SubState
    public let actionPromotion: (SubRefinedAction) -> BaseRefinedAction
    private var cancellables = Set<AnyCancellable>()
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }

    public required init<Store: StoreProtocol>(_ store: Store)
        where Store.BaseState == BaseState,
        Store.SubState == SubState,
        Store.RawAction == RawAction,
        Store.BaseRefinedAction == BaseRefinedAction,
        Store.SubRefinedAction == SubRefinedAction
    {
        underlying = store.underlying
        stateLens = store.stateLens
        actionPromotion = store.actionPromotion
        state = store.state
        store.statePublisher.sink { [weak self] state in
            self?.state = state
        }
        .store(in: &cancellables)
    }

    public func dispatch<S: Sequence>(refined actions: S) where S.Element == SubRefinedAction {
        underlying.dispatch(refined: actions.map(actionPromotion))
    }

    public func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        underlying.dispatch(raw: actions)
    }
}
