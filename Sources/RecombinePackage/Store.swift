//
//  Store.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Combine

public class Store<State, Action>: ObservableObject {
    @Published
    public private(set) var state: State
    public let actions = PassthroughSubject<Action, Never>()
    private var cancellables = Set<AnyCancellable>()

    public required init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, Action> = .init(),
        publishOn scheduler: S
    ) where R.State == State, R.Action == Action {
        self.state = state

        actions.scan(state) { state, action in
            reducer.reduce(
                state: state,
                actions: middleware.transform(state, action)
            )
        }
        .receive(on: scheduler).sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }

    @available(iOS 14, *)
    public func lensing<SubState>(_ keyPath: KeyPath<State, SubState>) -> StoreTransform<State, SubState, Action> {
        .init(store: self, lensing: keyPath)
    }

    open func dispatch(_ actions: Action...) {
        dispatch(actions)
    }

    open func dispatch<S: Sequence>(_ actions: S) where S.Element == Action {
        actions.forEach(self.actions.send)
    }
}

extension Store: Subscriber {
    public func receive(subscription: Subscription) {
        subscription.store(in: &cancellables)
        subscription.request(.unlimited)
    }

    public func receive(_ input: Action) -> Subscribers.Demand {
        actions.send(input)
        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<Never>) {}
}

public class StoreTransform<Underlying, State, Action>: ObservableObject {
    @Published
    public private(set) var state: State
    private let store: Store<Underlying, Action>
    private let keyPath: KeyPath<Underlying, State>

    @available(iOS 14, *)
    public required init(store: Store<Underlying, Action>, lensing keyPath: KeyPath<Underlying, State>) {
        self.store = store
        self.keyPath = keyPath
        state = store.state[keyPath: keyPath]
        store.$state.map { $0[keyPath: keyPath] }.assign(to: &$state)
    }

    @available(iOS 14, *)
    public func lensing<SubState>(_ keyPath: KeyPath<State, SubState>) -> StoreTransform<Underlying, SubState, Action> {
        .init(store: store, lensing: self.keyPath.appending(path: keyPath))
    }

    open func dispatch(_ actions: Action...) {
        store.dispatch(actions)
    }

    open func dispatch<S: Sequence>(_ actions: S) where S.Element == Action {
        store.dispatch(actions)
    }
}
