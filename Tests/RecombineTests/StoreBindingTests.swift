import Combine
import CombineExpectations
@testable import Recombine
import XCTest
import SwiftUI

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
        static let main = Middleware<States.Main, Action.Raw, Action.Refined>()
    }
    
    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Raw, Action.Refined> { statePublisher, action -> ActionStrata<Action.Raw, Action.Refined>.Publisher in
            switch action {
            case .noOp:
                return Empty()
                    .eraseToAnyPublisher()
            }
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Refined>(logging)
        
        static let logging = SideEffect<Action.Refined> {
            print($0)
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
        static let main = Middleware<States.Main, Action.Raw, Action.Refined>()
    }
    
    enum Thunks: ThunkParameter {
        static let main = Thunk<States.Main, Action.Raw, Action.Refined> { _, _ -> ActionStrata<Action.Raw, Action.Refined>.Publisher in
        }
    }

    enum SideEffects: SideEffectParameter {
        static let main = SideEffect<Action.Refined>(logging)
        
        static let logging = SideEffect<Action.Refined> {
            print($0)
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
    func testBinding() {
    }
}
