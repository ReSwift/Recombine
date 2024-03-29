import Combine
import CombineExpectations
import Foundation
@testable import Recombine
import XCTest

class StoreMiddlewareTests: XCTestCase {
    /**
     it can decorate dispatch function
     */
    func testDecorateMiddlewareDispatch() throws {
        let store = Store(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: firstMiddleware.appending(secondMiddleware),
            thunk: .init { _, _, _ in Empty().eraseToAnyPublisher() },
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .sync(.string("OK")),
            ],
            keyPath: \.value,
            value: "OK First Middleware Second Middleware"
        )
    }

    /**
     it reruns for dispatching
     */
    func testRedispatch() throws {
        let middleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void>({ _, action, dispatch, _ -> [TestFakes.SetAction.Sync] in
            switch action {
            case let .string(value):
                if !value.contains("Middleware") {
                    dispatch(.sync(.string(value + " Middleware")))
                    return []
                }
            default:
                break
            }
            return [action]
        })
        .debug("+++")
        let store = Store(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: middleware,
            thunk: .init { _, _, _ in Empty().eraseToAnyPublisher() },
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .sync(.string("OK")),
            ],
            keyPath: \.value,
            value: "OK Middleware"
        )
    }

    /**
     it can decorate dispatch function
     */
    func testDecorateThunkDispatch() throws {
        let store = Store(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: .init(),
            thunk: thunk,
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .async(.first("OK")),
            ],
            keyPath: \.value,
            value: "OK First Thunk Second Thunk"
        )
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() throws {
        let multiplexingMiddleware = Middleware<TestFakes.CounterTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void>({ _, action, _, _ in
            Array(repeating: action, count: 3)
        })
        let store = Store(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            middleware: multiplexingMiddleware,
            thunk: .init { _, _, _ in Empty().eraseToAnyPublisher() },
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .sync(.noop),
            ],
            keyPath: \.count,
            value: 3
        )
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testThunkMultiplies() throws {
        let multiplexingThunk = Thunk<TestFakes.CounterTest.State, TestFakes.SetAction.Async, TestFakes.SetAction.Sync, Void> { _, action, _ -> AnyPublisher<EitherAction<TestFakes.SetAction.Async, TestFakes.SetAction.Sync>, Never> in
            let transformed: TestFakes.SetAction.Sync
            switch action {
            case .noop:
                transformed = .noop
            case let .int(value):
                transformed = .int(value)
            case let .string(value):
                transformed = .string(value)
            }
            return [transformed, transformed, transformed].publisher.map { .sync($0) }.eraseToAnyPublisher()
        }
        .debug(asyncAction: .self, syncAction: .self)
        let store = Store(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            thunk: multiplexingThunk,
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        try prefixEquals(
            store,
            count: 3,
            actions: [
                .async(.noop),
            ],
            keyPath: \.count,
            values: [1, 2, 3]
        )
    }
}
