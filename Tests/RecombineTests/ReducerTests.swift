//
//  ReducerTests.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import XCTest
@testable import Recombine

class MockReducerContainer<Action> {

    var calledWithAction: [Action] = []
    var reducer: Reducer<CounterState, Action>!

    init() {
        reducer = .init { state, action in
            self.calledWithAction.append(action)
        }
    }
}

let increaseByOneReducer: Reducer<CounterState, SetAction> = .init { state, action in
    state.count += 1
}

let increaseByTwoReducer: Reducer<CounterState, SetAction> = .init { state, action in
    state.count += 2
}

class ReducerTests: XCTestCase {

    /**
     it calls each of the reducers with the given action exactly once
     */
    func testCallsReducersOnce() {
        let mockReducer1 = MockReducerContainer<SetAction>()
        let mockReducer2 = MockReducerContainer<SetAction>()
        let combinedReducer = Reducer(mockReducer1.reducer, mockReducer2.reducer)

        var state = CounterState()
        _ = combinedReducer.transform(&state, .noop)

        XCTAssertEqual(mockReducer1.calledWithAction.count, 1)
        XCTAssertEqual(mockReducer2.calledWithAction.count, 1)
        XCTAssert(mockReducer1.calledWithAction.first == .noop)
        XCTAssert(mockReducer2.calledWithAction.first == .noop)
    }

    /**
     it combines the results from each individual reducer correctly
     */
    func testCombinesReducerResults() {
        
        let combinedReducer = Reducer(increaseByOneReducer, increaseByTwoReducer)
        var state = CounterState()
        combinedReducer.transform(&state, .noop)

        XCTAssertEqual(state.count, 3)
    }
}
