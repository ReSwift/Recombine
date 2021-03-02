import Combine
import CombineExpectations
@testable import Recombine
import XCTest

class StoreTests: XCTestCase {
    /**
     it deinitializes when no reference is held
     */
    func testDeinit() {
        var deInitCount = 0

        autoreleasepool {
            let store = DeInitStore(
                state: TestFakes.IntTest.State(),
                reducer: TestFakes.IntTest.reducer,
                deInitAction: { deInitCount += 1 }
            )
            Just(.refined(.int(100))).subscribe(store)
            XCTAssertEqual(store.state.value, 100)
        }

        XCTAssertEqual(deInitCount, 1)
    }

    func testLensing() throws {
        let store = BaseStore(
            state: TestFakes.NestedTest.State(),
            reducer: TestFakes.NestedTest.reducer,
            middleware: .init(),
            publishOn: ImmediateScheduler.shared
        )
        let subStore = store.lensing(
            state: \.subState.value,
            actions: TestFakes.NestedTest.Action.sub
        )
        let stateRecorder = subStore.$state.dropFirst().record()
        let actionsRecorder = subStore.actions.record()

        let string = "Oh Yeah!"

        subStore.dispatch(refined: .set(string))

        let state = try wait(for: stateRecorder.prefix(1), timeout: 1)
        XCTAssertEqual(state[0], string)
        let actions = try wait(for: actionsRecorder.prefix(1), timeout: 1)
        XCTAssertEqual(actions, [.set(string)])
    }

    func testBinding() throws {
        let store = BaseStore(
            state: TestFakes.NestedTest.State(),
            reducer: TestFakes.NestedTest.reducer,
            middleware: .init(),
            publishOn: ImmediateScheduler.shared
        )
        let binding1 = store.binding(
            state: \.subState.value,
            action: { .sub(.set("\($0)1")) }
        )
        let binding2 = store.lensing(
            state: \.subState.value
        ).binding(
            action: { .sub(.set("\($0)2")) }
        )
        let binding3 = store.lensing(
            state: \.subState,
            actions: { .sub(.set("\($0)3")) }
        ).binding(
            state: \.value
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
class DeInitStore<State: Equatable>: BaseStore<State, TestFakes.SetAction, TestFakes.SetAction> {
    var deInitAction: (() -> Void)?

    deinit {
        deInitAction?()
    }

    convenience init(
        state: State,
        reducer: MutatingReducer<State, TestFakes.SetAction>,
        middleware: Middleware<State, TestFakes.SetAction, TestFakes.SetAction> = .init(),
        deInitAction: @escaping () -> Void
    ) {
        self.init(
            state: state,
            reducer: reducer,
            middleware: middleware,
            publishOn: ImmediateScheduler.shared
        )
        self.deInitAction = deInitAction
    }

    override init<S, R>(
        state: State,
        reducer: R,
        middleware: Middleware<State, TestFakes.SetAction, TestFakes.SetAction> = .init(),
        publishOn scheduler: S
    ) where State == R.State, TestFakes.SetAction == R.Action, S: Scheduler, R: Reducer {
        super.init(
            state: state,
            reducer: reducer,
            middleware: middleware,
            publishOn: scheduler
        )
    }
}
