import Combine
import CombineExpectations
@testable import Recombine
import SwiftUI
import XCTest

private typealias StoreTestType = Store<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

private enum Redux: StoreParameter {
    enum Action: ActionProtocol {
        enum Async {
            case noOp
        }

        enum Sync: BindableAction {
            case goToFirstScreen
            case goToSecondScreen
            case binding(BindingAction<States.Main>)
        }
    }

    enum Reducers: ReducerParameter {
        static let main = Reducer<States.Main, Action.Sync, Void> { state, action, _ in
            switch action {
            case .goToFirstScreen:
                state.screen = .primary
            case .goToSecondScreen:
                state.screen = .secondary
            case .binding:
                break
            }
        }.binding()
    }

    enum Middlewares: MiddlewareParameter {
        static let main = Middleware<States.Main, Action.Async, Action.Sync, Void>()
    }

    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Async, Action.Sync, Void> { _, action, _ -> EitherAction<Action.Async, Action.Sync>.Publisher in
            switch action {
            case .noOp:
                return Empty()
                    .eraseToAnyPublisher()
            }
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Sync, Void>(logging)

        static let logging = SideEffect<Action.Sync, Void> { action, _ in
            print(action)
        }
    }

    enum States: StateParameter {
        struct Main: Equatable {
            enum Route {
                case primary
                case secondary
            }

            @BindableState var username: String = ""
            var screen: Route = .primary
        }

        static let initial: Main = .init()
    }

    static let scheduler = DispatchQueue.main
    static let environment: Void = ()
    static let store = Store(parameters: Self.self)
}

private enum Redux2: StoreParameter {
    enum Action: ActionProtocol {
        typealias Async = Never
        enum Sync: BindableAction {
            case goToFirstScreen
            case goToSecondScreen
            case binding(BindingAction<States.Main>)
        }
    }

    enum Reducers: ReducerParameter {
        static let main = Reducer<States.Main, Action.Sync, Void> { state, action, _ in
            switch action {
            case .goToFirstScreen:
                state.screen = .primary
            case .goToSecondScreen:
                state.screen = .secondary
            case .binding:
                break
            }
        }.binding()
    }

    enum Middlewares: MiddlewareParameter {
        static let main = Middleware<States.Main, Action.Async, Action.Sync, Void>()
    }

    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Async, Action.Sync, Void> { _, _, _ -> EitherAction<Action.Async, Action.Sync>.Publisher in
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Sync, Void>(logging)

        static let logging = SideEffect<Action.Sync, Void> { action, _ in
            print(action)
        }
    }

    enum States: StateParameter {
        struct Main: Equatable {
            enum Route {
                case primary
                case secondary
            }

            @BindableState var username: String = ""
            var screen: Route = .primary
        }

        static let initial: Main = .init()
    }

    static let scheduler = DispatchQueue.main
    static let environment: Void = ()
    static let store = Store(parameters: Self.self)
}

class StoreBindingTests: XCTestCase {
    func testBinding() {}
}
