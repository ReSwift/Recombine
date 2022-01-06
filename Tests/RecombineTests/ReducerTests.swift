@testable import Recombine
import XCTest

class MockReducerContainer<Action> {
    var calledWithAction: [Action] = []
    var reducer: Reducer<TestFakes.CounterTest.State, Action, Void>!

    init() {
        reducer = .init { [weak self] _, action, _ in
            self?.calledWithAction.append(action)
        }
    }
}

let increaseByOneReducer: Reducer<TestFakes.CounterTest.State, TestFakes.SetAction.Sync, Void> = .init { state, _, _ in
    state.count += 1
}.debug("-_1")

let increaseByTwoReducer: Reducer<TestFakes.CounterTest.State, TestFakes.SetAction.Sync, Void> = .init { state, _, _ in
    state.count += 2
}.debug("-_2")

class ReducerTests: XCTestCase {
    /**
     it calls each of the reducers with the given action exactly once
     */
    func testCallsReducersOnce() {
        let mockReducer1 = MockReducerContainer<TestFakes.SetAction.Sync>()
        let mockReducer2 = MockReducerContainer<TestFakes.SetAction.Sync>()
        let combinedReducer = Reducer(mockReducer1.reducer, mockReducer2.reducer)

        var state = TestFakes.CounterTest.State()
        _ = combinedReducer.transform(&state, .noop, ())

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
        var state = TestFakes.CounterTest.State()
        combinedReducer.transform(&state, .noop, ())

        XCTAssertEqual(state.count, 3)
    }
}
