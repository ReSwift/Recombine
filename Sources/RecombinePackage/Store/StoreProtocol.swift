import Combine
import SwiftUI

public protocol StoreProtocol: ObservableObject, Subscriber {
    associatedtype BaseState: Equatable
    associatedtype SubState: Equatable
    associatedtype RawAction
    associatedtype BaseRefinedAction
    associatedtype SubRefinedAction
    var state: SubState { get }
    var statePublisher: Published<SubState>.Publisher { get }
    var underlying: BaseStore<BaseState, RawAction, BaseRefinedAction> { get }
    var stateLens: (BaseState) -> SubState { get }
    var actionPromotion: (SubRefinedAction) -> BaseRefinedAction { get }
    func dispatch<S: Sequence>(raw: S) where S.Element == RawAction
    func dispatch<S: Sequence>(refined: S) where S.Element == SubRefinedAction
    func lensing<NewState, NewAction>(
        state lens: @escaping (SubState) -> NewState,
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
    func lensing<NewState>(
        state lens: @escaping (SubState) -> NewState
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        SubRefinedAction
    > {
        lensing(state: lens, actions: { $0 })
    }

    func lensing<NewAction>(
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        BaseState,
        SubState,
        RawAction,
        BaseRefinedAction,
        NewAction
    > {
        lensing(state: { $0 }, actions: transform)
    }
    
    /// Create a LensedStore that cannot be updated with actions.
    /// - Parameters:
    ///   - lens: A lens to the state property.
    /// - Returns: A `LensedStore`, whose state is lensed by `keyPath` and whose actions are of type `Never`.
    func lensingReadOnly<NewState>(
        state lens: @escaping (SubState) -> NewState
    ) -> LensedStore<
        BaseState,
        NewState,
        RawAction,
        BaseRefinedAction,
        Never
    > {
        lensing(state: lens, actions: { _ -> SubRefinedAction in })
    }
}

public extension StoreProtocol {
    /// Create a SwiftUI Binding from a lensing function and a `SubRefinedAction`.
    /// - Parameters:
    ///   - lens: A lens to the state property.
    ///   - action: The refined action which will be called when the value is changed.
    /// - Returns: A `Binding` whose getter is the property and whose setter dispatches the refined action.
    func binding<Value>(
        state lens: @escaping (SubState) -> Value,
        action transform: @escaping (Value) -> SubRefinedAction
    ) -> Binding<Value> {
        .init(
            get: { lens(self.state) },
            set: { self.dispatch(refined: transform($0)) }
        )
    }

    /// Create a SwiftUI Binding from the `SubState` of the store and a `SubRefinedAction`.
    /// - Parameters:
    ///   - action: The refined action which will be called when the value is changed.
    /// - Returns: A `Binding` whose getter is the state and whose setter dispatches the refined action.
    func binding(
        action transform: @escaping (SubState) -> SubRefinedAction
    ) -> Binding<SubState> {
        .init(
            get: { self.state },
            set: { self.dispatch(refined: transform($0)) }
        )
    }

    /// Create a SwiftUI Binding from a lensing function when the value of that function is equivalent to `SubRefinedAction`.
    /// - Parameters:
    ///   - lens: A lens to the state property.
    /// - Returns: A `Binding` whose getter is the property and whose setter dispatches the store's refined action.
    func binding<Value>(
        state lens: @escaping (SubState) -> Value
    ) -> Binding<Value> where SubRefinedAction == Value {
        .init(
            get: { lens(self.state) },
            set: { self.dispatch(refined: $0) }
        )
    }

    /// Create a SwiftUI Binding from the `SubState` when its value is equivalent to `SubRefinedAction`.
    /// - Returns: A `Binding` whose getter is the state and whose setter dispatches the store's refined action.
    func binding() -> Binding<SubState> where SubRefinedAction == SubState {
        .init(
            get: { self.state },
            set: { self.dispatch(refined: $0) }
        )
    }
}

public extension StoreProtocol {
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

public extension StoreProtocol {
    func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    func receive(_ input: ActionStrata<RawAction, SubRefinedAction>) -> Subscribers.Demand {
        switch input {
        case let .raw(action):
            dispatch(raw: action)
        case let .refined(action):
            dispatch(refined: action)
        }
        return .unlimited
    }

    func receive(completion: Subscribers.Completion<Never>) {}
}
