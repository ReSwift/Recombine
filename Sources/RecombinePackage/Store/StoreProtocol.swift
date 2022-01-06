import Combine
import SwiftUI

public protocol StoreProtocol: Subscriber {
    typealias Action = EitherAction<AsyncAction, SyncAction>
    associatedtype State: Equatable
    associatedtype SyncAction
    associatedtype AsyncAction

    var state: State { get }
    var statePublisher: AnyPublisher<State, Never> { get }
    func dispatch<S: Sequence>(serially: Bool, collect: Bool, actions: S) where S.Element == Action
}

public extension StoreProtocol {
    func lensing<SubState: Equatable, NewAsyncAction, NewSyncAction>(
        state stateTransform: @escaping (State) -> SubState,
        actions actionPromotion: @escaping (EitherAction<NewAsyncAction, NewSyncAction>) -> Action
    ) -> LensedStore<SubState, NewAsyncAction, NewSyncAction> {
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

    func lensing<SubState: Equatable, NewAsyncAction, NewSyncAction>(
        state stateTransform: @escaping (State) -> SubState,
        sync asyncActionPromotion: @escaping (NewAsyncAction) -> AsyncAction,
        async syncActionPromotion: @escaping (NewSyncAction) -> SyncAction
    ) -> LensedStore<SubState, NewAsyncAction, NewSyncAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(async: asyncActionPromotion, sync: syncActionPromotion)
            }
        )
    }

    func lensing<NewAsyncAction, NewSyncAction>(
        async asyncActionPromotion: @escaping (NewAsyncAction) -> AsyncAction,
        sync syncActionPromotion: @escaping (NewSyncAction) -> SyncAction
    ) -> LensedStore<State, NewAsyncAction, NewSyncAction> {
        lensing(
            state: { $0 },
            actions: {
                $0.map(async: asyncActionPromotion, sync: syncActionPromotion)
            }
        )
    }

    func lensing<SubState: Equatable, NewSyncAction>(
        state stateTransform: @escaping (State) -> SubState,
        sync syncActionPromotion: @escaping (NewSyncAction) -> SyncAction
    ) -> LensedStore<SubState, AsyncAction, NewSyncAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(sync: syncActionPromotion)
            }
        )
    }

    func lensing<SubState: Equatable, NewAsyncAction>(
        state stateTransform: @escaping (State) -> SubState,
        async asyncActionPromotion: @escaping (NewAsyncAction) -> AsyncAction
    ) -> LensedStore<SubState, NewAsyncAction, SyncAction> {
        lensing(
            state: stateTransform,
            actions: {
                $0.map(async: asyncActionPromotion)
            }
        )
    }

    func lensing<SubState>(
        state stateTransform: @escaping (State) -> SubState
    ) -> LensedStore<
        SubState,
        AsyncAction,
        SyncAction
    > {
        lensing(state: stateTransform, actions: { $0 })
    }

    func lensing<NewAsyncAction, NewSyncAction>(
        actions actionPromotion: @escaping (EitherAction<NewAsyncAction, NewSyncAction>) -> Action
    ) -> LensedStore<
        State,
        NewAsyncAction,
        NewSyncAction
    > {
        lensing(state: { $0 }, actions: actionPromotion)
    }

    func lensing<NewSyncAction>(
        sync actionPromotion: @escaping (NewSyncAction) -> SyncAction
    ) -> LensedStore<
        State,
        AsyncAction,
        NewSyncAction
    > {
        lensing(state: { $0 }, sync: actionPromotion)
    }

    func lensing<NewAsyncAction>(
        async actionPromotion: @escaping (NewAsyncAction) -> AsyncAction
    ) -> LensedStore<
        State,
        NewAsyncAction,
        SyncAction
    > {
        lensing(state: { $0 }, async: actionPromotion)
    }
}

public extension StoreProtocol {
    /// Create a `LensedStore` that cannot be updated with actions.
    func readOnly() -> LensedStore<State, Never, Never> {
        lensing(async: { _ -> AsyncAction in }, sync: { _ -> SyncAction in })
    }

    /// Create a `LensedStore` that cannot be updated with actions.
    func readOnly<NewSyncAction>(
        sync transform: @escaping (NewSyncAction) -> SyncAction
    ) -> LensedStore<State, Never, NewSyncAction> {
        lensing(async: { _ -> AsyncAction in }, sync: transform)
    }

    /// Create a `LensedStore` that cannot be updated with actions.
    func readOnly<NewAsyncAction>(
        async transform: @escaping (NewAsyncAction) -> AsyncAction
    ) -> LensedStore<State, NewAsyncAction, Never> {
        lensing(async: transform, sync: { _ -> SyncAction in })
    }

    /// Create an `ActionLens`, which can only send actions.
    func writeOnly() -> ActionLens<AsyncAction, SyncAction> {
        ActionLens(dispatchFunction: dispatch)
    }

    /// Create an `ActionLens`, which can only send sync actions.
    func writeOnlySync<NewSyncAction>(
        _ transform: @escaping (NewSyncAction) -> SyncAction
    ) -> ActionLens<Never, NewSyncAction> {
        writeOnly(async: { _ -> AsyncAction in }, sync: transform)
    }

    /// Create an `ActionLens`, which can only send async actions.
    func writeOnlyAsync<NewAsyncAction>(
        _ transform: @escaping (NewAsyncAction) -> AsyncAction
    ) -> ActionLens<NewAsyncAction, Never> {
        writeOnly(async: transform, sync: { _ -> SyncAction in })
    }

    /// Create an `ActionLens`, which can only send actions.
    func writeOnly<NewAsyncAction>(
        async transform: @escaping (NewAsyncAction) -> AsyncAction
    ) -> ActionLens<NewAsyncAction, SyncAction> {
        writeOnly(async: transform, sync: { $0 })
    }

    /// Create an `ActionLens`, which can only send actions.
    func writeOnly<NewSyncAction>(
        sync transform: @escaping (NewSyncAction) -> SyncAction
    ) -> ActionLens<AsyncAction, NewSyncAction> {
        writeOnly(async: { $0 }, sync: transform)
    }

    /// Create an `ActionLens`, which can only send actions.
    func writeOnly<NewAsyncAction, NewSyncAction>(
        async asyncTransform: @escaping (NewAsyncAction) -> AsyncAction,
        sync syncTransform: @escaping (NewSyncAction) -> SyncAction
    ) -> ActionLens<NewAsyncAction, NewSyncAction> {
        ActionLens<NewAsyncAction, NewSyncAction> {
            dispatch(
                serially: $0,
                collect: $1,
                actions: $2.map {
                    $0.map(
                        async: asyncTransform,
                        sync: syncTransform
                    )
                }
            )
        }
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
        async actions: S
    ) where S.Element == AsyncAction {
        dispatch(
            serially: serially,
            collect: collect,
            actions: .async(.init(actions))
        )
    }

    func dispatch(
        serially: Bool = false,
        collect: Bool = false,
        async actions: AsyncAction...
    ) {
        dispatch(serially: serially, collect: collect, actions: .async(actions))
    }

    func dispatch<S: Sequence>(
        sync actions: S
    ) where S.Element == SyncAction {
        dispatch(actions: .sync(.init(actions)))
    }

    func dispatch(
        sync actions: SyncAction...
    ) {
        dispatch(actions: .sync(actions))
    }
}

public extension StoreProtocol where SyncAction == () {
    func dispatchSync() {
        dispatch(sync: ())
    }
}

public extension StoreProtocol {
    func eraseToAnyStore() -> AnyStore<State, AsyncAction, SyncAction> {
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
