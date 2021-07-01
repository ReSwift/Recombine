import Combine
import Recombine

let firstMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { _, action, _ -> [TestFakes.SetAction] in
    switch action {
    case let .string(value):
        return [.string(value + " First Middleware")]
    default:
        return [action]
    }
}

let secondMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { _, action, _ -> [TestFakes.SetAction] in
    switch action {
    case let .string(value):
        return [.string(value + " Second Middleware")]
    default:
        return [action]
    }
}

let stateAccessingMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction> { state, action, _ -> [TestFakes.SetAction] in
    if case let .string(value) = action {
        return [.string(state.value! + state.value!)]
    }
    return [action]
}

let thunk = Thunk<TestFakes.StringTest.State, TestFakes.ThunkRawAction, TestFakes.SetAction> { _, action -> Just<ActionStrata<TestFakes.ThunkRawAction, TestFakes.SetAction>> in
    switch action {
    case let .first(value):
        return Just(.raw(.second(value + " First Thunk")))
    case let .second(value):
        return Just(.refined(.string(value + " Second Thunk")))
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
