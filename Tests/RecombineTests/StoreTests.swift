import XCTest
@testable import Recombine
import Combine
import CombineExpectations

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
        let subStore = store.lensing(state: \.subState.value, actions: TestFakes.NestedTest.Action.sub)
        let stateRecorder = subStore.$state.dropFirst().record()
        let actionsRecorder = subStore.actions.record()

        let string = "Oh Yeah!"

        subStore.dispatch(refined: .set(string))

        let state = try wait(for: stateRecorder.prefix(1), timeout: 1)
        XCTAssertEqual(state[0], string)
        let actions = try wait(for: actionsRecorder.prefix(1), timeout: 1)
        XCTAssertEqual(actions, [.set(string)])
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

    required init<S, R>(
        state: State,
        stateEquality: @escaping (State, State) -> Bool,
        reducer: R,
        middleware: Middleware<State, TestFakes.SetAction, TestFakes.SetAction> = .init(),
        publishOn scheduler: S
    ) where State == R.State, TestFakes.SetAction == R.Action, S : Scheduler, R : Reducer {
        super.init(
            state: state,
            stateEquality: stateEquality,
            reducer: reducer,
            middleware: middleware,
            publishOn: scheduler
        )
    }
}
