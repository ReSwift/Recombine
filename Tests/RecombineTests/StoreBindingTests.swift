import Combine
import CombineExpectations
@testable import Recombine
import SwiftUI
import XCTest

private typealias StoreTestType = Store<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

private enum Redux: StoreParameter {
    enum Action: ActionProtocol {
        enum Raw {
            case noOp
        }

        enum Refined: BindableAction {
            case goToFirstScreen
            case goToSecondScreen
            case binding(BindingAction<States.Main>)
        }
    }

    enum Reducers: ReducerParameter {
        static let main = Reducer<States.Main, Action.Refined, Void> { state, action, _ in
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
        static let main = Middleware<States.Main, Action.Raw, Action.Refined, Void>()
    }

    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Raw, Action.Refined, Void> { _, action, _ -> ActionStrata<Action.Raw, Action.Refined>.Publisher in
            switch action {
            case .noOp:
                return Empty()
                    .eraseToAnyPublisher()
            }
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Refined, Void>(logging)

        static let logging = SideEffect<Action.Refined, Void> { action, _ in
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
        typealias Raw = Never
        enum Refined: BindableAction {
            case goToFirstScreen
            case goToSecondScreen
            case binding(BindingAction<States.Main>)
        }
    }

    enum Reducers: ReducerParameter {
        static let main = Reducer<States.Main, Action.Refined, Void> { state, action, _ in
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
        static let main = Middleware<States.Main, Action.Raw, Action.Refined, Void>()
    }

    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Raw, Action.Refined, Void> { _, _, _ -> ActionStrata<Action.Raw, Action.Refined>.Publisher in
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Refined, Void>(logging)

        static let logging = SideEffect<Action.Refined, Void> { action, _ in
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
