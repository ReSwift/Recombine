import Combine
import SwiftUI

public protocol StoreProtocol: Subscriber {
    typealias Action = ActionStrata<RawAction, RefinedAction>
    associatedtype State: Equatable
    associatedtype RefinedAction
    associatedtype RawAction

    var state: State { get }
    var statePublisher: AnyPublisher<State, Never> { get }
    func dispatch<S: Sequence>(serially: Bool, collect: Bool, actions: S) where S.Element == Action
}

public extension StoreProtocol {
    func lensing<SubState: Equatable, NewRawAction, NewRefinedAction>(
        state stateTransform: @escaping (State) -> SubState,
        actions actionPromotion: @escaping (ActionStrata<NewRawAction, NewRefinedAction>) -> Action
    ) -> LensedStore<SubState, NewRawAction, NewRefinedAction> {
        .init(
            initial: stateTransform(state),
            statePublisher: statePublisher.map(stateTransform),
            dispatch: {
                self.dispatch(
                    serially: $0,
                    collect: $1,
                    actions: $2.map(actionPromotion)
                )
            }
        )
    }

    func lensing<SubState: Equatable, NewRawAction, NewRefinedAction>(
        state stateTransform: @escaping (State) -> SubState,
        refined refinedActionPromotion: @escaping (NewRefinedAction) -> RefinedAction,
        raw rawActionPromotion: @escaping (NewRawAction) -> RawAction
    ) -> LensedStore<SubState, NewRawAction, NewRefinedAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(raw: rawActionPromotion, refined: refinedActionPromotion)
            }
        )
    }

    func lensing<SubState: Equatable, NewRefinedAction>(
        state stateTransform: @escaping (State) -> SubState,
        refined refinedActionPromotion: @escaping (NewRefinedAction) -> RefinedAction
    ) -> LensedStore<SubState, RawAction, NewRefinedAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(refined: refinedActionPromotion)
            }
        )
    }

    func lensing<SubState: Equatable, NewRawAction>(
        state stateTransform: @escaping (State) -> SubState,
        raw rawActionPromotion: @escaping (NewRawAction) -> RawAction
    ) -> LensedStore<SubState, NewRawAction, RefinedAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(raw: rawActionPromotion)
            }
        )
    }

    func lensing<SubState>(
        state stateTransform: @escaping (State) -> SubState
    ) -> LensedStore<
        SubState,
        RawAction,
        RefinedAction
    > {
        lensing(state: stateTransform, actions: { $0 })
    }

    func lensing<NewRawAction, NewRefinedAction>(
        actions actionPromotion: @escaping (ActionStrata<NewRawAction, NewRefinedAction>) -> Action
    ) -> LensedStore<
        State,
        NewRawAction,
        NewRefinedAction
    > {
        lensing(state: { $0 }, actions: actionPromotion)
    }

    func lensing<NewRefinedAction>(
        refined actionPromotion: @escaping (NewRefinedAction) -> RefinedAction
    ) -> LensedStore<
        State,
        RawAction,
        NewRefinedAction
    > {
        lensing(state: { $0 }, refined: actionPromotion)
    }

    func lensing<NewRawAction>(
        raw actionPromotion: @escaping (NewRawAction) -> RawAction
    ) -> LensedStore<
        State,
        NewRawAction,
        RefinedAction
    > {
        lensing(state: { $0 }, raw: actionPromotion)
    }

    /// Create a `LensedStore` that cannot be updated with actions.
    func readOnly() -> LensedStore<State, Never, Never> {
        lensing(refined: { _ -> RefinedAction in })
            .lensing(raw: { _ -> RawAction in })
    }

    /// Create an `ActionLens`, which can only send actions.
    func writeOnly() -> ActionLens<RawAction, RefinedAction> {
        ActionLens(dispatchFunction: dispatch)
    }
}

public extension StoreProtocol {
    func dispatch(
        serially: Bool = false,
        collect: Bool = false,
        actions: Action...
    ) {
        dispatch(serially: serially, collect: collect, actions: actions)
    }

    func dispatch<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        raw actions: S
    ) where S.Element == RawAction {
        dispatch(
            serially: serially,
            collect: collect,
            actions: .raw(.init(actions))
        )
    }

    func dispatch(
        serially: Bool = false,
        collect: Bool = false,
        raw actions: RawAction...
    ) {
        dispatch(serially: serially, collect: collect, actions: .raw(actions))
    }

    func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        dispatch(actions: .refined(.init(actions)))
    }

    func dispatch(refined actions: RefinedAction...) {
        dispatch(actions: .refined(actions))
    }
}

public extension StoreProtocol where RefinedAction == () {
    func dispatchRefined() {
        dispatch(refined: ())
    }
}

public extension StoreProtocol {
    func eraseToAnyStore() -> AnyStore<State, RawAction, RefinedAction> {
        AnyStore(self)
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
