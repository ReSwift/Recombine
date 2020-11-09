//
//  Store.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Combine

public class Store<State, RawAction, RefinedAction>: ObservableObject {
    @Published
    public private(set) var state: State
    public let rawActions = PassthroughSubject<RawAction, Never>()
    public let refinedActions = PassthroughSubject<RefinedAction, Never>()
    private var cancellables = Set<AnyCancellable>()

    public required init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RawAction, RefinedAction>,
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state

        rawActions.flatMap { [unowned self] action in
            middleware.transform(self.$state.prefix(1), action)
        }
        .subscribe(refinedActions)
        .store(in: &cancellables)
        
        refinedActions.scan(state) { state, action in
            reducer.reduce(
                state: state,
                action: action
            )
        }
        .receive(on: scheduler)
        .sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }

    public func lensing<SubState>(_ keyPath: KeyPath<State, SubState>) -> StoreTransform<State, SubState, RawAction, RefinedAction> {
        .init(store: self, lensing: keyPath)
    }

    open func dispatch(refined actions: RefinedAction...) {
        dispatch(refined: actions)
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        actions.forEach(self.refinedActions.send)
    }

    open func dispatch(raw actions: RawAction...) {
        dispatch(raw: actions)
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(self.rawActions.send)
    }
}

extension Store: Subscriber {
    public func receive(subscription: Subscription) {
        subscription.store(in: &cancellables)
        subscription.request(.unlimited)
    }

    public func receive(_ input: ActionStrata<RawAction, RefinedAction>) -> Subscribers.Demand {
        switch input {
        case let .raw(action):
            rawActions.send(action)
        case let .refined(action):
            refinedActions.send(action)
        }
        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<Never>) {}
}

public class StoreTransform<Underlying, State, RawAction, RefinedAction>: ObservableObject {
    @Published
    public private(set) var state: State
    private let store: Store<Underlying, RawAction, RefinedAction>
    private let keyPath: KeyPath<Underlying, State>
    private var cancellables = Set<AnyCancellable>()

    public required init(store: Store<Underlying, RawAction, RefinedAction>, lensing keyPath: KeyPath<Underlying, State>) {
        self.store = store
        self.keyPath = keyPath
        state = store.state[keyPath: keyPath]
        store.$state
            .map { $0[keyPath: keyPath] }
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &cancellables)
    }

    public func lensing<SubState>(_ keyPath: KeyPath<State, SubState>) -> StoreTransform<Underlying, SubState, RawAction, RefinedAction> {
        .init(store: store, lensing: self.keyPath.appending(path: keyPath))
    }

    open func dispatch(refined actions: RefinedAction...) {
        store.dispatch(refined: actions)
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        store.dispatch(refined: actions)
    }
    
    open func dispatch(raw actions: RawAction...) {
        store.dispatch(raw: actions)
    }

    open func dispatch<S: Sequence>(unrefined actions: S) where S.Element == RawAction {
        store.dispatch(raw: actions)
    }
}

extension StoreTransform: Subscriber {
    public func receive(subscription: Subscription) {
        subscription.store(in: &cancellables)
        subscription.request(.unlimited)
    }

    public func receive(_ input: ActionStrata<RawAction, RefinedAction>) -> Subscribers.Demand {
        switch input {
        case let .raw(action):
            store.dispatch(raw: action)
        case let .refined(action):
            store.dispatch(refined: action)
        }
        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<Never>) {}
}
