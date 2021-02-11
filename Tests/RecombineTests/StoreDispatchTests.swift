import XCTest
@testable import Recombine
import Combine

fileprivate typealias StoreTestType = BaseStore<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

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
        subject.subscribe(store)
        subject.send(.refined(.int(20)))
        XCTAssertEqual(store.state.value, 20)
    }
}
