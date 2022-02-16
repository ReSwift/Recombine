import Combine
import CombineExpectations
@testable import Recombine
import XCTest

private typealias StoreTestType = Store<TestFakes.IntTest.State, TestFakes.SetAction, TestFakes.SetAction>

class ObservableStoreDispatchTests: XCTestCase {
    enum AsyncAction: Equatable {
        case addTwice(String)
        case addThrice(String)
    }

    let thunk = Thunk<String, AsyncAction, String, Void> { _, action, _ -> AnyPublisher
        <EitherAction<AsyncAction, String>, Never> in
        switch action {
        case let .addTwice(value):
            return Just(value)
                .append(
                    Just(value)
                        .delay(for: .seconds(0.1), scheduler: DispatchQueue.main)
                )
                .map { .sync($0) }
                .eraseToAnyPublisher()
        case let .addThrice(value):
            return Just(.async(.addTwice(value)))
                .append(
                    Just(.sync(value))
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

        let subject = PassthroughSubject<EitherAction<AsyncAction, String>, Never>()
        let asyncActionsRecorder = store.publishers.actions.async.all.record()
        let syncActionsRecorder = store.publishers.actions.sync.middleware.post.record()

        try nextEquals(
            store,
            dropFirst: 2,
            access: {
                subject.subscribe($0)
                subject.send(.async(.addThrice("1")))
            },
            keyPath: \.self,
            value: "111"
        )

        let asyncExpectation: [AsyncAction] = [.addThrice("1"), .addTwice("1")]
        XCTAssertEqual(
            try wait(for: asyncActionsRecorder.prefix(2), timeout: 10),
            asyncExpectation.map { $0 }
        )

        XCTAssertEqual(
            try wait(for: syncActionsRecorder.prefix(3), timeout: 10),
            "111".map { String($0) }
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

        let asyncActionsRecorder = store._asyncActions.record()
        let syncActionsRecorder = store._postMiddlewareSyncActions.record()

        try prefixEquals(
            store,
            count: 9,
            timeout: 10,
            serially: true,
            actions: [
                .async(.addTwice("5")),
                .sync(["0", "0"]),
                .async(.addThrice("6")),
                .async(.addTwice("2")),
                .sync("1"),
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

        let asyncExpectation: [AsyncAction] = [.addTwice("5"), .addThrice("6"), .addTwice("6"), .addTwice("2")]
        XCTAssertEqual(
            try wait(for: asyncActionsRecorder.prefix(asyncExpectation.count), timeout: 10).flatMap { $0 },
            asyncExpectation
        )

        let syncExpectation = [["5"], ["5"], ["0", "0"], ["6"], ["6"], ["6"], ["2"], ["2"], ["1"]]
        XCTAssertEqual(
            try wait(for: syncActionsRecorder.prefix(syncExpectation.count), timeout: 10),
            syncExpectation
        )
    }

    func testSerialDispatchWithCollectWithSideEffects() throws {
        var sideEffected = ""

        let store = Store(
            state: "",
            reducer: reducer,
            thunk: thunk,
            sideEffect: .init { actions, _ in
                actions.flatMap { [$0, $0] }.forEach {
                    sideEffected += $0
                }
            }.debug("s-e"),
            environment: (),
            publishOn: ImmediateScheduler.shared
        )

        let asyncActionsRecorder = store._asyncActions.record()
        let syncActionsRecorder = store._postMiddlewareSyncActions.record()

        let value = "5500666221"

        try nextEquals(
            store,
            timeout: 10,
            serially: true,
            collect: true,
            actions: [
                .async(.addTwice("5")),
                .sync(["0", "0"]),
                .async(.addThrice("6")),
                .async(.addTwice("2")),
                .sync("1"),
            ],
            keyPath: \.self,
            value: "5500666221"
        )

        let asyncExpectation: [AsyncAction] = [.addTwice("5"), .addThrice("6"), .addTwice("6"), .addTwice("2")]
        XCTAssertEqual(
            try wait(for: asyncActionsRecorder.prefix(asyncExpectation.count), timeout: 10).flatMap { $0 },
            asyncExpectation
        )

        XCTAssertEqual(
            try wait(for: syncActionsRecorder.next(), timeout: 10),
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
