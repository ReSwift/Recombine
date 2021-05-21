import SwiftUI

@propertyWrapper
public struct StoreBinding<Value, Store: StoreProtocol> {
    private let store: Store

    private let stateLens: (Store.SubState) -> Value
    private let actionTransform: (Value) -> ActionStrata<Store.RawAction, Store.SubRefinedAction>

    public var wrappedValue: Value { stateLens(store.state) }

    private init(
        store: Store,
        stateLens: @escaping (Store.SubState) -> Value,
        action: @escaping (Value) -> ActionStrata<Store.RawAction, Store.SubRefinedAction>
    ) {
        self.store = store
        self.stateLens = stateLens
        actionTransform = action
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
        state stateLens: @escaping (Store.SubState) -> Value,
        refinedAction: @escaping (Value) -> Store.SubRefinedAction
    ) {
        self.init(store: store, stateLens: stateLens, action: { .refined(refinedAction($0)) })
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
}
