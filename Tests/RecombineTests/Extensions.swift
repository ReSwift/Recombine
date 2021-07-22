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
    func last<Store: StoreProtocol>(
        _ store: Store,
        timeout: TimeInterval = 1,
        access: (Store) -> Void
    ) throws -> Store.SubState? {
        let recorder = store.recorder
        access(store)
        return try wait(for: recorder.last, timeout: timeout)
    }

    func lastEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        timeout: TimeInterval = 1,
        serialActions actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>],
        keyPath: KeyPath<Store.SubState, State>,
        value: State
    ) throws {
        XCTAssertEqual(
            try last(
                store,
                timeout: timeout,
                access: { $0.dispatchSerially(actions: actions) }
            )?[keyPath: keyPath],
            value
        )
    }

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
                access: { $0.dispatch(actions: actions) }
            )?[keyPath: keyPath],
            value
        )
    }
}
