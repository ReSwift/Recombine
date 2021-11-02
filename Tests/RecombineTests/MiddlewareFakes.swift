import Combine
import Recombine

let firstMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Raw, TestFakes.SetAction.Refined, Void> { _, action, _, _ -> [TestFakes.SetAction.Refined] in
    switch action {
    case let .string(value):
        return [.string(value + " First Middleware")]
    default:
        return [action]
    }
}

let secondMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Raw, TestFakes.SetAction.Refined, Void> { _, action, _, _ -> [TestFakes.SetAction.Refined] in
    switch action {
    case let .string(value):
        return [.string(value + " Second Middleware")]
    default:
        return [action]
    }
}.debug("---")

let stateAccessingMiddleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Raw, TestFakes.SetAction.Refined, Void> { state, action, _, _ -> [TestFakes.SetAction.Refined] in
    if case let .string(value) = action {
        return [.string(state.value! + state.value!)]
    }
    return [action]
}

let thunk = Thunk<TestFakes.StringTest.State, TestFakes.ThunkRawAction, TestFakes.SetAction.Refined, Void> { _, action, _ -> Just<ActionStrata<TestFakes.ThunkRawAction, TestFakes.SetAction.Refined>> in
    switch action {
    case let .first(value):
        return Just(.raw(.second(value + " First Thunk")))
    case let .second(value):
        return Just(.refined(.string(value + " Second Thunk")))
    }
}.debug("thunk")

let stateAccessingThunk = Thunk<TestFakes.StringTest.State, TestFakes.SetAction.Raw, TestFakes.SetAction.Refined, Void> { state, action, _ -> AnyPublisher<ActionStrata<TestFakes.SetAction.Raw, TestFakes.SetAction.Refined>, Never> in
    if case let .string(value) = action {
        return state.map {
            .refined(.string($0.value! + $0.value!))
        }
        .eraseToAnyPublisher()
    }
    let transformed: TestFakes.SetAction.Refined
    switch action {
    case .noop:
        transformed = .noop
    case let .int(value):
        transformed = .int(value)
    case let .string(value):
        transformed = .string(value)
    }
    return Just(.refined(transformed)).eraseToAnyPublisher()
}.debug("stateAccessingThunk")
