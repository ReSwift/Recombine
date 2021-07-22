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

    func testSerialDispatch() throws {
        enum RawAction {
            case addTwice(String)
            case addThrice(String)
        }

        let thunk = Thunk<String, RawAction, String> { _, action -> AnyPublisher
            <ActionStrata<[RawAction], [String]>, Never> in
            switch action {
            case let .addTwice(value):
                return Just(value)
                    .append(
                        Just(value)
                            .delay(for: .seconds(0.1), scheduler: DispatchQueue.main)
                    )
                    .map { .refined($0) }
                    .eraseToAnyPublisher()
            case let .addThrice(value):
                return Just(.raw(.addTwice(value)))
                    .append(
                        Just(.refined(value))
                            .delay(for: .seconds(0.1), scheduler: DispatchQueue.main)
                    )
                    .eraseToAnyPublisher()
            }
        }
        let reducer: MutatingReducer<String, String> = .init { state, action in
            state += action
        }

        let store = BaseStore(
            state: "",
            reducer: reducer,
            thunk: thunk,
            publishOn: ImmediateScheduler.shared
        )

        try nextEquals(
            store,
            dropFirst: 8,
            timeout: 10,
            serialActions: [
                .raw(.addTwice("5")),
                .refined("0"),
                .raw(.addThrice("6")),
                .raw(.addTwice("2")),
                .refined("1"),
            ],
            keyPath: \.self,
            value: "550666221"
        )
    }
}
