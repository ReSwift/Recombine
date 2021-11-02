import Combine
import CombineExpectations
@testable import Recombine
import XCTest

class StoreTests: XCTestCase {
    /**
     it deinitializes when no reference is held
     */
    func testDeinit() throws {
        var deInitCount = 0

        try autoreleasepool {
            let store = DeInitStore(
                state: TestFakes.IntTest.State(),
                reducer: TestFakes.IntTest.reducer,
                deInitAction: { deInitCount += 1 }
            )
            let recorder = store.recorder

            Just(.refined(.int(100))).subscribe(store)

            XCTAssertEqual(
                try wait(for: recorder.next(), timeout: 1).value,
                100
            )
        }

        XCTAssertEqual(deInitCount, 1)
    }

    func testBinding() throws {
        let store = Store(
            state: TestFakes.NestedTest.State(),
            reducer: TestFakes.NestedTest.reducer,
            middleware: .init(),
            thunk: .init(),
            environment: (),
            publishOn: ImmediateScheduler.shared
        )
        let binding1 = store.binding(
            get: \.subState.value,
            send: { .sub(.set("\($0)1")) }
        )
        let binding2 = store.lensing(
            state: \.subState.value
        ).binding(
            send: { .sub(.set("\($0)2")) }
        )
        let binding3 = store.lensing(
            state: \.subState,
            refined: { .sub(.set("\($0)3")) }
        ).binding(
            get: \.value
        )
        let stateRecorder = store.$state.dropFirst().record()

        let string = "Oh Yeah!"

        binding1.wrappedValue = string
        binding2.wrappedValue = string
        binding3.wrappedValue = string

        let state = try wait(for: stateRecorder.prefix(3), timeout: 1)
        XCTAssertEqual(
            state.map(\.subState.value),
            zip(repeatElement(string, count: 3), 1...).map { "\($0)\($1)" }
        )
    }
}

// Used for deinitialization test
class DeInitStore<State: Equatable>: Store<State, TestFakes.SetAction.Raw, TestFakes.SetAction.Refined> {
    var deInitAction: (() -> Void)?

    deinit {
        deInitAction?()
    }

    convenience init(
        state: State,
        reducer: Reducer<State, RefinedAction, Void>,
        thunk: Thunk<State, RawAction, RefinedAction, Void> = .init { _, _, _ in Empty().eraseToAnyPublisher() },
        deInitAction: @escaping () -> Void
    ) {
        self.init(
            state: state,
            reducer: reducer,
            thunk: thunk,
            environment: (),
            publishOn: ImmediateScheduler.shared
        )
        self.deInitAction = deInitAction
    }

    override init<S: Scheduler, Environment>(
        state: State,
        reducer: Reducer<State, RefinedAction, Environment>,
        middleware _: Middleware<State, RawAction, RefinedAction, Environment> = .init(),
        thunk: Thunk<State, RawAction, RefinedAction, Environment> = .init { _, _, _ in Empty().eraseToAnyPublisher() },
        sideEffect _: SideEffect<RefinedAction> = .init(),
        environment: Environment,
        publishOn scheduler: S
    ) {
        super.init(
            state: state,
            reducer: reducer,
            thunk: thunk,
            environment: environment,
            publishOn: scheduler
        )
    }
}
