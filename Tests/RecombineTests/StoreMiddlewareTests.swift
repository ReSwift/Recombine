import XCTest
import Foundation
import Combine
@testable import Recombine

class StoreMiddlewareTests: XCTestCase {

    /**
     it can decorate dispatch function
     */
    func testDecorateDispatch() {
        let store = Store(
            state: TestStringAppState(),
            reducer: testValueStringReducer,
            middleware: firstMiddleware.concat(secondMiddleware),
            publishOn: ImmediateScheduler.shared
        )
        let action = SetAction.string("OK")
        store.dispatch(raw: action)

        XCTAssertEqual(store.state.testValue, "OK First Middleware Second Middleware")
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() {
        let multiplexingMiddleware = Middleware<CounterState, SetAction, SetAction> {
            [$1, $1, $1].publisher
        }
        let store = Store(
            state: CounterState(count: 0),
            reducer: increaseByOneReducer,
            middleware: multiplexingMiddleware,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .noop)
        XCTAssertEqual(store.state.count, 3)
    }
}
