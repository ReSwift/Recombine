import XCTest
@testable import Recombine

class MockReducerContainer<Action> {

    var calledWithAction: [Action] = []
    var reducer: MutatingReducer<TestFakes.CounterTest.State, Action>!

    init() {
        reducer = .init { state, action in
            self.calledWithAction.append(action)
        }
    }
}

let increaseByOneReducer: MutatingReducer<TestFakes.CounterTest.State, TestFakes.SetAction> = .init { state, action in
    state.count += 1
}

let increaseByTwoReducer: MutatingReducer<TestFakes.CounterTest.State, TestFakes.SetAction> = .init { state, action in
    state.count += 2
}

class ReducerTests: XCTestCase {

    /**
     it calls each of the reducers with the given action exactly once
     */
    func testCallsReducersOnce() {
        let mockReducer1 = MockReducerContainer<TestFakes.SetAction>()
        let mockReducer2 = MockReducerContainer<TestFakes.SetAction>()
        let combinedReducer = MutatingReducer(mockReducer1.reducer, mockReducer2.reducer)

        var state = TestFakes.CounterTest.State()
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
        
        let combinedReducer = MutatingReducer(increaseByOneReducer, increaseByTwoReducer)
        var state = TestFakes.CounterTest.State()
        combinedReducer.transform(&state, .noop)

        XCTAssertEqual(state.count, 3)
    }
}
