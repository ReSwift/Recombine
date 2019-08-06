//
//  ObservableStoreMiddlewareTests.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import XCTest
import Foundation
@testable import Recombine

class StoreMiddlewareTests: XCTestCase {

    /**
     it can decorate dispatch function
     */
    func testDecorateDispatch() {
        let store = Store(state: TestStringAppState(),
                          reducer: testValueStringReducer,
                          middleware: Middleware(firstMiddleware, secondMiddleware))
        
        let action = SetAction.string("OK")
        store.dispatch(action)

        XCTAssertEqual(store.state.testValue, "OK First Middleware Second Middleware")
    }

    /**
     it middleware can access the store's state
     */
    func testMiddlewareCanAccessState() {
        let testValue = "OK"
        let store = Store(state: TestStringAppState(testValue: testValue),
                          reducer: testValueStringReducer,
                          middleware: stateAccessingMiddleware.sideEffect { print($0, $1) })

        store.dispatch(.string("Action That Won't Go Through"))

        XCTAssertEqual(store.state.testValue, testValue + testValue)
    }

    /**
     it middleware should not be executed if the previous middleware returned nil
     */
    func testMiddlewareSkipsReducersWhenPassedNil() {
        let filteringMiddleware1 = Middleware<TestStringAppState, SetAction>().filter({ _, _ in false }).sideEffect { _, _ in XCTFail() }
        let filteringMiddleware2 = Middleware<TestStringAppState, SetAction>().filter({ _, _ in false }).filterMap { _, _ in XCTFail(); return nil }

        let state = TestStringAppState(testValue: "OK")

        var store = Store(state: state,
                          reducer: testValueStringReducer,
                          middleware: Middleware(filteringMiddleware1, filteringMiddleware2))
        store.dispatch(.string("Action That Won't Go Through"))

        store = Store(state: state,
                      reducer: testValueStringReducer,
                      middleware: filteringMiddleware1)
        store.dispatch(.string("Action That Won't Go Through"))

        store = Store(state: state,
                      reducer: testValueStringReducer,
                      middleware: filteringMiddleware2)
        store.dispatch(.string("Action That Won't Go Through"))
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() {
        let multiplexingMiddleware = Middleware<CounterState, SetAction>().flatMap { [$1, $1, $1] }.filterMap { _, action in action }
        let store = Store(state: CounterState(count: 0),
                          reducer: increaseByOneReducer,
                          middleware: multiplexingMiddleware)
        store.dispatch(.noop)
        XCTAssertEqual(store.state.count, 3)
    }
}
