import Combine

public protocol StoreProtocol: ObservableObject, Subscriber {
    associatedtype BaseState
    associatedtype SubState
    associatedtype RawAction
    associatedtype RefinedAction
    var state: SubState { get }
    var statePublisher: Published<SubState>.Publisher { get }
    var underlying: Store<BaseState, RawAction, RefinedAction> { get }
    var keyPath: KeyPath<BaseState, SubState> { get }
    func dispatch<S: Sequence>(raw: S) where S.Element == RawAction
    func dispatch<S: Sequence>(refined: S) where S.Element == RefinedAction
    func lensing<NewState>(_ keyPath: KeyPath<SubState, NewState>) -> StoreTransform<BaseState, NewState, RawAction, RefinedAction>
    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, RefinedAction>
}

public extension StoreProtocol {
    func dispatch(refined actions: RefinedAction...) {
        dispatch(refined: actions)
    }

    func dispatch(raw actions: RawAction...) {
        dispatch(raw: actions)
    }

    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, RefinedAction> {
        AnyStore(self)
    }
}

extension StoreProtocol {
    public func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    public func receive(_ input: ActionStrata<RawAction, RefinedAction>) -> Subscribers.Demand {
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
