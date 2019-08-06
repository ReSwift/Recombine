//
//  ObservableStoreDispatchTests.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import XCTest
@testable import Recombine
import Combine

fileprivate typealias StoreTestType = Store<TestAppState, SetAction>

class ObservableStoreDispatchTests: XCTestCase {

    fileprivate var store: StoreTestType!
    var reducer: Reducer<TestAppState, SetAction>!

    override func setUp() {
        super.setUp()
        reducer = testReducer
    }

    /**
     it subscribes to the property we pass in and dispatches any new values
     */
    func testLiftingWorksAsExpected() {
        let subject = PassthroughSubject<SetAction, Never>()
        store = Store(state: TestAppState(), reducer: reducer)
        subject.subscribe(store)
        subject.send(.int(20))
        XCTAssertEqual(store.state.testValue, 20)
    }
}
