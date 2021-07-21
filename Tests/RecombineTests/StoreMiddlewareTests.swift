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
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: firstMiddleware.concat(secondMiddleware),
            thunk: .init(),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .refined(.string("OK")),
            ],
            keyPath: \.value,
            value: "OK First Middleware Second Middleware"
        )
    }

    /**
     it reruns for dispatching
     */
    func testRedispatch() throws {
        let middleware = Middleware<TestFakes.StringTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action, dispatch -> [TestFakes.SetAction] in
            switch action {
            case let .string(value):
                if !value.contains("Middleware") {
                    dispatch(.refined(.string(value + " Middleware")))
                    return []
                }
            default:
                break
            }
            return [action]
        }
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: middleware,
            thunk: .init(),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .refined(.string("OK")),
            ],
            keyPath: \.value,
            value: "OK Middleware"
        )
    }

    /**
     it can decorate dispatch function
     */
    func testDecorateThunkDispatch() throws {
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: .init(),
            thunk: thunk,
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .raw(.first("OK")),
            ],
            keyPath: \.value,
            value: "OK First Thunk Second Thunk"
        )
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() throws {
        let multiplexingMiddleware = Middleware<TestFakes.CounterTest.State, TestFakes.SetAction, TestFakes.SetAction> { _, action, _ in
            Array(repeating: action, count: 3)
        }
        let store = BaseStore(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            middleware: multiplexingMiddleware,
            thunk: .init(),
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            actions: [
                .refined(.noop),
            ],
            keyPath: \.count,
            value: 3
        )
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testThunkMultiplies() throws {
        let multiplexingThunk = Thunk<TestFakes.CounterTest.State, TestFakes.SetAction, TestFakes.SetAction> {
            [$1, $1, $1].publisher.map { .refined($0) }
        }
        let store = BaseStore(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            thunk: multiplexingThunk,
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            dropFirst: 2,
            actions: [
                .raw(.noop),
            ],
            keyPath: \.count,
            value: 3
        )
    }
}
