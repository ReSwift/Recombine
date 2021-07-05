import Combine
import SwiftUI

@available(macOS 11.0, iOS 14, watchOS 7, tvOS 14, *)
@propertyWrapper
public struct StoreBinding<Value: Equatable, Store: StoreProtocol>: DynamicProperty {
    @StateObject private var store: LensedStore<
        Store.BaseState,
        Value,
        Store.RawAction,
        Store.BaseRefinedAction,
        Store.SubRefinedAction
    >
    private let actionTransform: (Value) -> ActionStrata<Store.RawAction, Store.SubRefinedAction>

    private init(
        store: Store,
        stateLens: @escaping (Store.SubState) -> Value,
        action: @escaping (Value) -> ActionStrata<Store.RawAction, Store.SubRefinedAction>
    ) {
        actionTransform = action
        _store = .init(wrappedValue: store.lensing(state: stateLens))
    }

    public init(
        _ store: Store,
        state stateLens: @escaping (Store.SubState) -> Value,
        rawAction: @escaping (Value) -> Store.RawAction
    ) {
        self.init(store: store, stateLens: stateLens, action: { .raw(rawAction($0)) })
    }

    public init(
        _ store: Store,
        rawAction: @escaping (Value) -> Store.RawAction
    ) where Store.SubState == Value {
        self.init(store: store, stateLens: { $0 }, action: { .raw(rawAction($0)) })
    }

    public init(
        _ store: Store,
        state stateLens: @escaping (Store.SubState) -> Value,
        refinedAction: @escaping (Value) -> Store.SubRefinedAction
    ) {
        self.init(store: store, stateLens: stateLens, action: { .refined(refinedAction($0)) })
    }

    public init(
        _ store: Store,
        refinedAction: @escaping (Value) -> Store.SubRefinedAction
    ) where Store.SubState == Value {
        self.init(store: store, stateLens: { $0 }, action: { .refined(refinedAction($0)) })
    }

    public init(
        _ store: Store
    ) where Store.SubState == Value, Store.SubRefinedAction == Value {
        self.init(store: store, stateLens: { $0 }, action: { .refined($0) })
    }

    public var projectedValue: Binding<Value> {
        Binding<Value>(
            get: { wrappedValue },
            set: {
                switch actionTransform($0) {
                case let .raw(action):
                    store.dispatch(raw: action)
                case let .refined(action):
                    store.dispatch(refined: action)
                }
            }
        )
    }

    public var wrappedValue: Value {
        store.state
    }
}
