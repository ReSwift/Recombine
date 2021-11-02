import Combine
import CombineExpectations
@testable import Recombine
import XCTest

private typealias StoreTestType = Store<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

class ObservableStoreDispatchTests: XCTestCase {
    enum RawAction: Equatable {
        case addTwice(String)
        case addThrice(String)
    }

    let thunk = Thunk<String, RawAction, String, Void> { _, action, _ -> AnyPublisher
        <ActionStrata<RawAction, String>, Never> in
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

    let reducer: Reducer<String, String, Void> = .init { state, action, _ in
        state += action
    }

    /**
     it subscribes to the property we pass in and dispatches any new values
     */
    func testLiftingWorksAsExpected() throws {
        let store = Store(
            state: "",
            reducer: reducer,
            thunk: thunk,
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        let subject = PassthroughSubject<ActionStrata<RawAction, String>, Never>()
        let rawActionsRecorder = store.rawActions.record()
        let refinedActionsRecorder = store.postMiddlewareRefinedActions.record()

        try nextEquals(
            store,
            dropFirst: 2,
            access: {
                subject.subscribe($0)
                subject.send(.raw(.addThrice("1")))
            },
            keyPath: \.self,
            value: "111"
        )

        let rawExpectation: [RawAction] = [.addThrice("1"), .addTwice("1")]
        XCTAssertEqual(
            try wait(for: rawActionsRecorder.prefix(2), timeout: 10),
            rawExpectation.map { [$0] }
        )

        XCTAssertEqual(
            try wait(for: refinedActionsRecorder.prefix(3), timeout: 10),
            "111".map { [String($0)] }
        )
    }

    func testSerialDispatch() throws {
        let store = Store(
            state: "",
            reducer: reducer,
            thunk: thunk,
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        let rawActionsRecorder = store.rawActions.record()
        let refinedActionsRecorder = store.postMiddlewareRefinedActions.record()

        try prefixEquals(
            store,
            count: 9,
            timeout: 10,
            serially: true,
            actions: [
                .raw(.addTwice("5")),
                .refined(["0", "0"]),
                .raw(.addThrice("6")),
                .raw(.addTwice("2")),
                .refined("1"),
            ],
            keyPath: \.self,
            values: [
                "5",
                "55",
                "5500",
                "55006",
                "550066",
                "5500666",
                "55006662",
                "550066622",
                "5500666221",
            ]
        )

        let rawExpectation: [RawAction] = [.addTwice("5"), .addThrice("6"), .addTwice("6"), .addTwice("2")]
        XCTAssertEqual(
            try wait(for: rawActionsRecorder.prefix(rawExpectation.count), timeout: 10).flatMap { $0 },
            rawExpectation
        )

        let refinedExpectation = [["5"], ["5"], ["0", "0"], ["6"], ["6"], ["6"], ["2"], ["2"], ["1"]]
        XCTAssertEqual(
            try wait(for: refinedActionsRecorder.prefix(refinedExpectation.count), timeout: 10),
            refinedExpectation
        )
    }

    func testSerialDispatchWithCollectWithSideEffects() throws {
        var sideEffected = ""

        let store = Store(
            state: "",
            reducer: reducer,
            thunk: thunk,
            sideEffect: .init {
                $0.flatMap { [$0, $0] }.forEach {
                    sideEffected += $0
                }
            },
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        let rawActionsRecorder = store.rawActions.record()
        let refinedActionsRecorder = store.postMiddlewareRefinedActions.record()

        let value = "5500666221"

        try nextEquals(
            store,
            timeout: 10,
            serially: true,
            collect: true,
            actions: [
                .raw(.addTwice("5")),
                .refined(["0", "0"]),
                .raw(.addThrice("6")),
                .raw(.addTwice("2")),
                .refined("1"),
            ],
            keyPath: \.self,
            value: "5500666221"
        )

        let rawExpectation: [RawAction] = [.addTwice("5"), .addThrice("6"), .addTwice("6"), .addTwice("2")]
        XCTAssertEqual(
            try wait(for: rawActionsRecorder.prefix(rawExpectation.count), timeout: 10).flatMap { $0 },
            rawExpectation
        )

        XCTAssertEqual(
            try wait(for: refinedActionsRecorder.next(), timeout: 10),
            value.map { String($0) }
        )

        XCTAssertEqual(
            sideEffected,
            value.map { String($0) + String($0) }.joined()
        )
    }

    func testReplay() throws {
        let store = Store(
            state: "",
            reducer: reducer,
            thunk: thunk,
            environment: (),
            publishOn: DispatchQueue.global()
        )

        try prefixEquals(
            store,
            count: 2,
            timeout: 10,
            access: { store in
                store.replay(
                    [
                        (offset: 0, actions: ["1"]),
                        (offset: 0.5, actions: ["2"]),
                    ]
                )
            },
            keyPath: \.self,
            values: ["1", "12"]
        )
    }
}
