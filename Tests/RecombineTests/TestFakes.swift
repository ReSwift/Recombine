import Foundation
import Recombine

let dispatchQueue = DispatchQueue.global()
typealias MainStore = BaseStore<TestFakes.NestedTest.State, TestFakes.NestedTest.Action, TestFakes.NestedTest.Action>
typealias SubStore<State: Equatable, Action> = LensedStore<TestFakes.NestedTest.State, State, TestFakes.NestedTest.Action, TestFakes.NestedTest.Action, Action>

enum TestFakes {
    enum SetAction: Equatable {
        case noop
        case int(Int)
        case string(String)
    }
}

extension TestFakes {
    enum CounterTest {
        struct State: Equatable {
            var count = 0
        }
    }
}

extension TestFakes {
    enum NestedTest {
        enum Action: Equatable {
            enum SubState: Equatable {
                case set(String)
            }

            case sub(SubState)
        }

        struct State: Equatable {
            struct SubState: Equatable {
                var value: String = ""
            }

            var subState: SubState = .init()
        }

        static let reducer: MutatingReducer<State, Action> = .init { state, action in
            switch action {
            case let .sub(.set(value)):
                state.subState.value = value
            }
        }
    }
}

extension TestFakes {
    enum ThunkRawAction {
        case first(String)
        case second(String)
    }
}

extension TestFakes {
    enum StringTest {
        struct State: Equatable {
            var value: String?
        }

        static let reducer = MutatingReducer<State, SetAction> { state, action in
            switch action {
            case let .string(value):
                state.value = value
            default:
                break
            }
        }
    }
}

extension TestFakes {
    enum IntTest {
        struct State: Equatable {
            var value: Int?
        }

        static let reducer = MutatingReducer<State, SetAction> { state, action in
            switch action {
            case let .int(value):
                state.value = value
            default:
                break
            }
        }
    }
}
