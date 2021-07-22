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
        access: (Store) -> Void
    ) throws -> Store.SubState? {
        let recorder = store.recorder
        access(store)
        return try wait(for: recorder.prefix(dropFirst + 1), timeout: timeout).last
    }

    func next<Store: StoreProtocol>(
        _ store: Store,
        dropFirst: Int,
        timeout: TimeInterval = 1,
        actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>]
    ) throws -> Store.SubState? {
        try next(store, dropFirst: dropFirst, timeout: timeout) {
            $0.dispatch(actions: actions)
        }
    }

    func nextEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        dropFirst: Int = 0,
        timeout: TimeInterval = 1,
        serialActions actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>],
        keyPath: KeyPath<Store.SubState, State>,
        value: State
    ) throws {
        XCTAssertEqual(
            try next(
                store,
                dropFirst: dropFirst,
                timeout: timeout,
                access: { $0.dispatchSerially(actions: actions) }
            )?[keyPath: keyPath],
            value
        )
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
            )?[keyPath: keyPath],
            value
        )
    }
}
