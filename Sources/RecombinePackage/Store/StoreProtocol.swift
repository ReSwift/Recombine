import Combine
import SwiftUI

public protocol StoreProtocol: ObservableObject, Subscriber {
    typealias Action = ActionStrata<[RawAction], [SubRefinedAction]>
    typealias Underlying = BaseStore<BaseState, RawAction, BaseRefinedAction>
    associatedtype BaseState: Equatable
    associatedtype SubState: Equatable
    associatedtype RawAction
    associatedtype BaseRefinedAction
    associatedtype SubRefinedAction
    var state: SubState { get }
    var statePublisher: Published<SubState>.Publisher { get }
    var underlying: Underlying { get }
    var stateLens: (BaseState) -> SubState { get }
    var actionPromotion: (SubRefinedAction) -> BaseRefinedAction { get }
    func dispatch<S: Sequence>(actions: S) where S.Element == Action
    func dispatchSerially<S: Sequence>(actions: S) where S.Element == Action
    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, BaseRefinedAction, SubRefinedAction>
}

public extension StoreProtocol {
    func lensing<NewState, NewAction>(
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
        let actionPromotion = self.actionPromotion
        return .init(
            store: underlying,
            lensing: { lens(stateLens($0)) },
            actionPromotion: { actionPromotion(transform($0)) }
        )
    }

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

    /// Create a `LensedStore` that cannot be updated with actions.
    var readOnly: LensedStore<
        BaseState,
        SubState,
        RawAction,
        BaseRefinedAction,
        Never
    > {
        lensing(actions: { _ -> SubRefinedAction in })
    }

    /// Create an `ActionLens`, which can only send actions.
    var writeOnly: ActionLens<
        RawAction,
        BaseRefinedAction,
        SubRefinedAction
    > {
        ActionLens {
            switch $0 {
            case let .raw(actions):
                self.underlying.dispatch(raw: actions)
            case let .refined(actions):
                self.underlying.dispatch(refined: actions.map(self.actionPromotion))
            }
        }
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
    /// Create a SwiftUI Binding from a lensing function and a `RawAction`.
    /// - Parameters:
    ///   - lens: A lens to the state property.
    ///   - action: The refined action which will be called when the value is changed.
    /// - Returns: A `Binding` whose getter is the property and whose setter dispatches the refined action.
    func binding<Value>(
        state lens: @escaping (SubState) -> Value,
        rawAction transform: @escaping (Value) -> RawAction
    ) -> Binding<Value> {
        .init(
            get: { lens(self.state) },
            set: { self.dispatch(raw: transform($0)) }
        )
    }

    /// Create a SwiftUI Binding from the `SubState` of the store and a `RawAction`.
    /// - Parameters:
    ///   - action: The refined action which will be called when the value is changed.
    /// - Returns: A `Binding` whose getter is the state and whose setter dispatches the refined action.
    func binding(
        rawAction transform: @escaping (SubState) -> RawAction
    ) -> Binding<SubState> {
        .init(
            get: { self.state },
            set: { self.dispatch(raw: transform($0)) }
        )
    }
}

public extension StoreProtocol {
    func dispatch<S: Sequence>(actions: S) where S.Element == Action {
        underlying.dispatch(actions: actions.map {
            switch $0 {
            case let .refined(actions):
                return .refined(actions.map(actionPromotion))
            case let .raw(actions):
                return .raw(actions)
            }
        })
    }

    func dispatch(actions: Action...) {
        dispatch(actions: actions)
    }

    func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        dispatch(actions: .raw(.init(actions)))
    }

    func dispatch<S: Sequence>(refined actions: S)
        where S.Element == SubRefinedAction
    {
        dispatch(actions: .refined(.init(actions)))
    }

    func dispatch(refined actions: SubRefinedAction...) {
        dispatch(actions: .refined(actions))
    }

    func dispatch(raw actions: RawAction...) {
        dispatch(actions: .raw(actions))
    }
}

public extension StoreProtocol {
    func dispatchSerially<S: Sequence>(actions: S) where S.Element == Action {
        underlying.dispatchSerially(actions: actions.map {
            switch $0 {
            case let .refined(actions):
                return .refined(actions.map(actionPromotion))
            case let .raw(actions):
                return .raw(actions)
            }
        })
    }

    func dispatchSerially(actions: Action...) {
        dispatchSerially(actions: actions)
    }

    func dispatchSerially<S: Sequence>(raw actions: S) where S.Element == RawAction {
        dispatchSerially(actions: .raw(.init(actions)))
    }

    func dispatchSerially(raw actions: RawAction...) {
        dispatchSerially(actions: .raw(actions))
    }
}

public extension StoreProtocol {
    func eraseToAnyStore() -> AnyStore<BaseState, SubState, RawAction, BaseRefinedAction, SubRefinedAction> {
        AnyStore(self)
    }
}

public extension StoreProtocol where SubRefinedAction == () {
    func dispatchRefined() {
        dispatch(refined: ())
    }
}

public extension StoreProtocol {
    func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    func receive(_ input: Action) -> Subscribers.Demand {
        dispatch(actions: input)
        return .unlimited
    }

    func receive(completion _: Subscribers.Completion<Never>) {}
}
