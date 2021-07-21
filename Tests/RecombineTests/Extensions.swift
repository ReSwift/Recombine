import Combine
import CombineExpectations
@testable import Recombine
import XCTest

extension StoreProtocol {
    var recorder: Recorder<SubState, Never> {
        statePublisher.dropFirst().record()
    }
}

extension XCTestCase {
    func next<Store: StoreProtocol>(
        _ store: Store,
        dropFirst: Int,
        timeout: TimeInterval = 1,
        actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>]
    ) throws -> Store.SubState {
        let recorder = store.recorder
        actions.forEach {
            switch $0 {
            case let .raw(actions):
                store.dispatch(raw: actions)
            case let .refined(actions):
                store.dispatch(refined: actions)
            }
        }
        return try wait(for: recorder.prefix(dropFirst + 1), timeout: timeout).last!
    }

    func nextEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        dropFirst: Int = 0,
        timeout: TimeInterval = 1,
        actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>],
        keyPath: KeyPath<Store.SubState, State>,
        value: State
    ) throws {
        XCTAssertEqual(
            try next(
                store,
                dropFirst: dropFirst,
                timeout: timeout,
                actions: actions
            )[keyPath: keyPath],
            value
        )
    }
}
