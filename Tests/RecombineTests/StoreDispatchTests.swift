import Combine
import CombineExpectations
@testable import Recombine
import XCTest

private typealias StoreTestType = BaseStore<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

class ObservableStoreDispatchTests: XCTestCase {
    fileprivate var store: StoreTestType!
    var reducer: MutatingReducer<TestFakes.IntTest.State, TestFakes.SetAction>!

    override func setUp() {
        super.setUp()
        reducer = TestFakes.IntTest.reducer
    }

    /**
     it subscribes to the property we pass in and dispatches any new values
     */
    func testLiftingWorksAsExpected() {
        let subject = PassthroughSubject<StoreTestType.Action, Never>()
        store = BaseStore(state: TestFakes.IntTest.State(), reducer: reducer, middleware: .init(), publishOn: ImmediateScheduler.shared)
        let recorder = store.recorder

        subject.subscribe(store)
        subject.send(.refined(.int(20)))

        XCTAssertEqual(
            try wait(for: recorder.next(), timeout: 1).value,
            20
        )
    }
}
