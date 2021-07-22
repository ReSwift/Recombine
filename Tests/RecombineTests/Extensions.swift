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

    func nextEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        dropFirst: Int = 0,
        timeout: TimeInterval = 1,
        serially: Bool = false,
        actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>],
        keyPath: KeyPath<Store.SubState, State>,
        value: State
    ) throws {
        XCTAssertEqual(
            try next(
                store,
                dropFirst: dropFirst,
                timeout: timeout,
                access: { $0.dispatch(serially: serially, actions: actions) }
            )?[keyPath: keyPath],
            value
        )
    }

    func prefix<Store: StoreProtocol>(
        _ store: Store,
        count: Int,
        timeout: TimeInterval = 1,
        access: (Store) -> Void
    ) throws -> [Store.SubState] {
        let recorder = store.recorder
        access(store)
        return try wait(for: recorder.prefix(count), timeout: timeout)
    }

    func prefixEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        count: Int,
        timeout: TimeInterval = 1,
        serially: Bool = false,
        actions: [ActionStrata<[Store.RawAction], [Store.SubRefinedAction]>],
        keyPath: KeyPath<Store.SubState, State>,
        values: [State]
    ) throws {
        XCTAssertEqual(
            try prefix(
                store,
                count: count,
                timeout: timeout,
                access: { $0.dispatch(serially: serially, actions: actions) }
            ).map { $0[keyPath: keyPath] },
            values
        )
    }
}
