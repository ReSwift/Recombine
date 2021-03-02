import Combine
import Recombine

let firstMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action -> Just<TestFakes.SetAction> in
    switch action {
    case let .string(value):
        return Just(.string(value + " First Middleware"))
    default:
        return Just(action)
    }
}

let secondMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action -> Just<TestFakes.SetAction> in
    switch action {
    case let .string(value):
        return Just(.string(value + " Second Middleware"))
    default:
        return Just(action)
    }
}

let stateAccessingMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { state, action -> AnyPublisher<TestFakes.SetAction, Never> in
    if case let .string(value) = action {
        return state.map {
            .string($0.value! + $0.value!)
        }
        .eraseToAnyPublisher()
    }
    return Just(action).eraseToAnyPublisher()
}
