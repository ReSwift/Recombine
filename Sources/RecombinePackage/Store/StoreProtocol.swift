import Combine

public protocol StoreProtocol: ObservableObject, Subscriber {
    associatedtype BaseState
    associatedtype SubState
    associatedtype RawAction
    associatedtype BaseRefinedAction
    associatedtype SubRefinedAction
    var state: SubState { get }
    var statePublisher: Published<SubState>.Publisher { get }
    var underlying: BaseStore<BaseState, RawAction, BaseRefinedAction> { get }
    var keyPath: KeyPath<BaseState, SubState> { get }
    var actionPromotion: (SubRefinedAction) -> BaseRefinedAction { get }
    func dispatch<S: Sequence>(raw: S) where S.Element == RawAction
    func dispatch<S: Sequence>(refined: S) where S.Element == SubRefinedAction
    func lensing<NewState, NewAction>(
        state keyPath: KeyPath<SubState, NewState>,
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        NewAction
    >
    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, BaseRefinedAction, SubRefinedAction>
}

public extension StoreProtocol {
    func lensing<NewState, NewAction>(
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        NewAction
    > where NewState == SubState {
        lensing(state: \.self, actions: transform)
    }

    func lensing<NewState, NewAction>(
        state keyPath: KeyPath<SubState, NewState>
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        NewAction
    > where NewAction == SubRefinedAction {
        lensing(state: keyPath, actions: { $0 })
    }

    func dispatch(refined actions: SubRefinedAction...) {
        dispatch(refined: actions)
    }

    func dispatch(raw actions: RawAction...) {
        dispatch(raw: actions)
    }

    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, BaseRefinedAction, SubRefinedAction> {
        AnyStore(self)
    }
}

extension StoreProtocol {
    public func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    public func receive(_ input: ActionStrata<RawAction, SubRefinedAction>) -> Subscribers.Demand {
        switch input {
        case let .raw(action):
            dispatch(raw: action)
        case let .refined(action):
            dispatch(refined: action)
        }
        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<Never>) {}
}
