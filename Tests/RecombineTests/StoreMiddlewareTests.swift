import Combine
import Foundation
@testable import Recombine
import XCTest

class StoreMiddlewareTests: XCTestCase {
    /**
     it can decorate dispatch function
     */
    func testDecorateMiddlewareDispatch() {
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: firstMiddleware.concat(secondMiddleware),
            thunk: .init(),
            publishOn: ImmediateScheduler.shared
        )
        let action = TestFakes.SetAction.string("OK")
        store.dispatch(refined: [])
        store.dispatch(refined: action)

        XCTAssertEqual(store.state.value, "OK First Middleware Second Middleware")
    }

    /**
     it can decorate dispatch function
     */
    func testDecorateThunkDispatch() {
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: .init(),
            thunk: thunk,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .first("OK"))

        XCTAssertEqual(store.state.value, "OK First Thunk Second Thunk")
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() {
        let multiplexingMiddleware = Middleware<TestFakes.CounterTest.State, TestFakes.SetAction> {
            [$1, $1, $1]
        }
        let store = BaseStore(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            middleware: multiplexingMiddleware,
            thunk: .init(),
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(refined: .noop)
        XCTAssertEqual(store.state.count, 3)
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testThunkMultiplies() {
        let multiplexingThunk = Thunk<TestFakes.CounterTest.State, TestFakes.SetAction, TestFakes.SetAction> {
            [$1, $1, $1].publisher.map { .refined($0) }
        }
        let store = BaseStore(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            thunk: multiplexingThunk,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .noop)
        XCTAssertEqual(store.state.count, 3)
    }
}
