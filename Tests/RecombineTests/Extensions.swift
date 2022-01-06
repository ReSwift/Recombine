import Combine
import CombineExpectations
@testable import Recombine
import XCTest

extension StoreProtocol {
    var recorder: Recorder<State, Never> {
        statePublisher.dropFirst().record()
    }
}

extension XCTestCase {
    func next<Store: StoreProtocol>(
        _ store: Store,
        dropFirst: Int,
        timeout: TimeInterval = 1,
        access: (Store) -> Void
    ) throws -> Store.State? {
        let recorder = store.recorder
        access(store)
        return try wait(for: recorder.prefix(dropFirst + 1), timeout: timeout).last
    }

    func nextEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        dropFirst: Int = 0,
        timeout: TimeInterval = 1,
        access: (Store) -> Void,
        keyPath: KeyPath<Store.State, State>,
        value: State
    ) throws {
        XCTAssertEqual(
            try next(
                store,
                dropFirst: dropFirst,
                timeout: timeout,
                access: access
            )?[keyPath: keyPath],
            value
        )
    }

    func nextEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        dropFirst: Int = 0,
        timeout: TimeInterval = 1,
        serially: Bool = false,
        collect: Bool = false,
        actions: [EitherAction<Store.AsyncAction, Store.SyncAction>],
        keyPath: KeyPath<Store.State, State>,
        value: State
    ) throws {
        try nextEquals(
            store,
            dropFirst: dropFirst,
            timeout: timeout,
            access: { $0.dispatch(serially: serially, collect: collect, actions: actions) },
            keyPath: keyPath,
            value: value
        )
    }

    func prefix<Store: StoreProtocol>(
        _ store: Store,
        count: Int,
        timeout: TimeInterval = 1,
        access: (Store) -> Void
    ) throws -> [Store.State] {
        let recorder = store.recorder
        access(store)
        return try wait(for: recorder.prefix(count), timeout: timeout)
    }

    func prefixEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        count: Int,
        timeout: TimeInterval = 1,
        access: (Store) -> Void,
        keyPath: KeyPath<Store.State, State>,
        values: [State]
    ) throws {
        XCTAssertEqual(
            try prefix(
                store,
                count: count,
                timeout: timeout,
                access: access
            ).map { $0[keyPath: keyPath] },
            values
        )
    }

    func prefixEquals<Store: StoreProtocol, State: Equatable>(
        _ store: Store,
        count: Int,
        timeout: TimeInterval = 1,
        serially: Bool = false,
        collect: Bool = false,
        actions: [EitherAction<Store.AsyncAction, Store.SyncAction>],
        keyPath: KeyPath<Store.State, State>,
        values: [State]
    ) throws {
        try prefixEquals(
            store,
            count: count,
            timeout: timeout,
            access: { $0.dispatch(serially: serially, collect: collect, actions: actions) },
            keyPath: keyPath,
            values: values
        )
    }
}
