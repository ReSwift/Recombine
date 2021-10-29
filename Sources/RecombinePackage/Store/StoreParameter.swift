import Combine
import SwiftUI

public protocol StateParameter {
    associatedtype Main
    static var initial: Main { get }
}

public protocol SideEffectParameter {
    associatedtype RefinedAction
    static var main: SideEffect<RefinedAction> { get }
}

public protocol ReducerParameter {
    associatedtype State: Equatable
    associatedtype RefinedAction
    associatedtype Environment
    static var main: Reducer<State, RefinedAction, Environment> { get }
}

public protocol MiddlewareParameter {
    associatedtype State: Equatable
    associatedtype RawAction
    associatedtype RefinedAction
    static var main: Middleware<State, RawAction, RefinedAction> { get }
}

public protocol ThunkParameter {
    associatedtype State: Equatable
    associatedtype RawAction
    associatedtype RefinedAction
    static var main: Thunk<State, RawAction, RefinedAction> { get }
}

public protocol StoreParameter {
    associatedtype Action: ActionProtocol
    associatedtype Environment

    associatedtype Reducers: ReducerParameter
        where Reducers.State == States.Main,
        Reducers.RefinedAction == Action.Refined,
        Reducers.Environment == Environment

    associatedtype Middlewares: MiddlewareParameter
        where Middlewares.State == States.Main,
        Middlewares.RawAction == Action.Raw,
        Middlewares.RefinedAction == Action.Refined

    associatedtype Thunks: ThunkParameter
        where Thunks.State == States.Main,
        Thunks.RawAction == Action.Raw,
        Thunks.RefinedAction == Action.Refined

    associatedtype SideEffects: SideEffectParameter
        where SideEffects.RefinedAction == Action.Refined

    associatedtype DeliveryScheduler: Scheduler

    associatedtype States: StateParameter

    static var scheduler: DeliveryScheduler { get }
    static var environment: Environment { get }
    static var store: Store<States.Main, Action.Raw, Action.Refined> { get }
}

public extension StoreParameter {
    static var storeType: Store<States.Main, Action.Raw, Action.Refined>.Type {
        type(of: store)
    }
}
