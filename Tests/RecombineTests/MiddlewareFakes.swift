import Combine
import Recombine

let firstMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void> { _, action, _, _ -> [TestFakes.SetAction.Sync] in
    switch action {
    case let .string(value):
        return [.string(value + " First Middleware")]
    default:
        return [action]
    }
}

let secondMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void> { _, action, _, _ -> [TestFakes.SetAction.Sync] in
    switch action {
    case let .string(value):
        return [.string(value + " Second Middleware")]
    default:
        return [action]
    }
}.debug("---")

let stateAccessingMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void> { state, action, _, _ -> [TestFakes.SetAction.Sync] in
    if case let .string(value) = action {
        return [.string(state.value! + state.value!)]
    }
    return [action]
}

let thunk = Thunk<TestFakes.StringTest.State, TestFakes.ThunkAsyncAction, TestFakes.SetAction.Sync, Void> { _, action, _ -> Just<EitherAction<TestFakes.ThunkAsyncAction, TestFakes.SetAction.Sync>> in
    switch action {
    case let .first(value):
        return Just(.async(.second(value + " First Thunk")))
    case let .second(value):
        return Just(.sync(.string(value + " Second Thunk")))
    }
}.debug("thunk")

let stateAccessingThunk = Thunk<TestFakes.StringTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void> { store, action, _ -> AnyPublisher<EitherAction<TestFakes.SetAction.Async, TestFakes.SetAction.Sync>, Never> in
    if case let .string(value) = action {
        return store.state.map {
            .sync(.string($0.value! + $0.value!))
        }
        .eraseToAnyPublisher()
    }
    let transformed: TestFakes.SetAction.Sync
    switch action {
    case .noop:
        transformed = .noop
    case let .int(value):
        transformed = .int(value)
    case let .string(value):
        transformed = .string(value)
    }
    return Just(.sync(transformed)).eraseToAnyPublisher()
}.debug("stateAccessingThunk")
