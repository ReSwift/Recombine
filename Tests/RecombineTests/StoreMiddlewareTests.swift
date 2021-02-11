import XCTest
import Foundation
import Combine
@testable import Recombine

class StoreMiddlewareTests: XCTestCase {
    /**
     it can decorate dispatch function
     */
    func testDecorateDispatch() {
        let store = BaseStore(
            state: TestFakes.StringTest.State(),
            reducer: TestFakes.StringTest.reducer,
            middleware: firstMiddleware.concat(secondMiddleware),
            publishOn: ImmediateScheduler.shared
        )
        let action = TestFakes.SetAction.string("OK")
        store.dispatch(raw: action)

        XCTAssertEqual(store.state.value, "OK First Middleware Second Middleware")
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() {
        let multiplexingMiddleware = Middleware<TestFakes.CounterTest.State, TestFakes.SetAction, TestFakes.SetAction> {
            [$1, $1, $1].publisher
        }
        let store = BaseStore(
            state: TestFakes.CounterTest.State(count: 0),
            reducer: increaseByOneReducer,
            middleware: multiplexingMiddleware,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .noop)
        XCTAssertEqual(store.state.count, 3)
    }
}
