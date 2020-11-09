//
//  ObservableStoreMiddlewareTests.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

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
     it middleware should not be executed if the previous middleware returned nil
     */
    func testMiddlewareSkipsReducersWhenPassedNil() {
        let filteringMiddleware1 = Middleware<TestStringAppState, SetAction, SetAction>()
            .filter { _, _ in false }
            .map { _, _ -> Empty<SetAction, Never> in
                XCTFail()
                return Empty()
            }
        let filteringMiddleware2 = Middleware<TestStringAppState, SetAction, SetAction>()
            .filter { _, _ in false }
            .map { _, _ -> Empty<SetAction, Never> in
                XCTFail()
                return Empty()
            }

        let state = TestStringAppState(testValue: "OK")

        var store = Store(
            state: state,
            reducer: testValueStringReducer,
            middleware: filteringMiddleware1.concat(filteringMiddleware2),
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .string("Action That Won't Go Through"))

        store = Store(
            state: state,
            reducer: testValueStringReducer,
            middleware: filteringMiddleware1,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .string("Action That Won't Go Through"))

        store = Store(
            state: state,
            reducer: testValueStringReducer,
            middleware: filteringMiddleware2,
            publishOn: ImmediateScheduler.shared
        )
        store.dispatch(raw: .string("Action That Won't Go Through"))
    }

    /**
     it actions should be multiplied via the increase function
     */
    func testMiddlewareMultiplies() {
        let multiplexingMiddleware = Middleware<CounterState, SetAction, SetAction>()
            .map { [$1, $1, $1].publisher }
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
