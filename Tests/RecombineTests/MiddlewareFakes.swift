import Combine
import Recombine

let firstMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { _, action -> [TestFakes.SetAction] in
    switch action {
    case let .string(value):
        return [.string(value + " First Middleware")]
    default:
        return [action]
    }
}

let secondMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { _, action -> [TestFakes.SetAction] in
    switch action {
    case let .string(value):
        return [.string(value + " Second Middleware")]
    default:
        return [action]
    }
}

let stateAccessingMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { state, action -> [TestFakes.SetAction] in
    if case let .string(value) = action {
        return [.string(state.value! + state.value!)]
    }
    return [action]
}

let firstThunk = Thunk<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action -> Just<ActionStrata<TestFakes.SetAction, TestFakes.SetAction>> in
    switch action {
    case let .string(value):
        return Just(.refined(.string(value + " First Middleware")))
    default:
        return Just(.refined(action))
    }
}

let secondThunk = Thunk<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action -> Just<ActionStrata<TestFakes.SetAction, TestFakes.SetAction>> in
    switch action {
    case let .string(value):
        return Just(.refined(.string(value + " Second Middleware")))
    default:
        return Just(.refined(action))
    }
}

let stateAccessingThunk = Thunk<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { state, action -> AnyPublisher<ActionStrata<TestFakes.SetAction, TestFakes.SetAction>, Never> in
    if case let .string(value) = action {
        return state.map {
            .refined(.string($0.value! + $0.value!))
        }
        .eraseToAnyPublisher()
    }
    return Just(.refined(action)).eraseToAnyPublisher()
}
