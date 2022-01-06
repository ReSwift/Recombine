import Combine
import SwiftUI

public protocol ActionProtocol {
    associatedtype Async
    associatedtype Sync
}

public protocol StateParameter {
    associatedtype Main
    static var initial: Main { get }
}

public protocol SideEffectParameter {
    associatedtype SyncAction
    associatedtype Environment
    static var main: SideEffect<SyncAction, Environment> { get }
}

public protocol ReducerParameter {
    associatedtype State: Equatable
    associatedtype SyncAction
    associatedtype Environment
    static var main: Reducer<State, SyncAction, Environment> { get }
}

public protocol MiddlewareParameter {
    associatedtype State: Equatable
    associatedtype AsyncAction
    associatedtype SyncAction
    associatedtype Environment
    static var main: Middleware<State, AsyncAction, SyncAction, Environment> { get }
}

public protocol ThunkParameter {
    associatedtype State: Equatable
    associatedtype AsyncAction
    associatedtype SyncAction
    associatedtype Environment
    static var main: Thunk<State, AsyncAction, SyncAction, Environment> { get }
}

public protocol StoreParameter {
    associatedtype Action: ActionProtocol
    associatedtype Environment

    associatedtype Reducers: ReducerParameter
        where Reducers.State == States.Main,
        Reducers.SyncAction == Action.Sync,
        Reducers.Environment == Environment

    associatedtype Middlewares: MiddlewareParameter
        where Middlewares.State == States.Main,
        Middlewares.AsyncAction == Action.Async,
        Middlewares.SyncAction == Action.Sync,
        Middlewares.Environment == Environment

    associatedtype Thunks: ThunkParameter
        where Thunks.State == States.Main,
        Thunks.AsyncAction == Action.Async,
        Thunks.SyncAction == Action.Sync,
        Thunks.Environment == Environment

    associatedtype SideEffects: SideEffectParameter
        where SideEffects.SyncAction == Action.Sync,
        SideEffects.Environment == Environment

    associatedtype DeliveryScheduler: Scheduler

    associatedtype States: StateParameter

    static var scheduler: DeliveryScheduler { get }
    static var environment: Environment { get }
    static var store: Store<States.Main, Action.Async, Action.Sync> { get }
}

public extension StoreParameter {
    static var storeType: Store<States.Main, Action.Async, Action.Sync>.Type {
        type(of: store)
    }
}
