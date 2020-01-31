//
//  Store.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Combine

// TODO: Change state back to @Published as soon as a7fce59 of apple/swift is in a mainline Xcode release
public class Store<State, Action>: ObservableObject {
    public private(set) var state: State {
        willSet {
            objectWillChange.send()
        }
    }
    public let objectWillChange = ObservableObjectPublisher()
    public let actions = PassthroughSubject<Action, Never>()
    private var cancellables = Set<AnyCancellable>()

    public required init<S: Scheduler, R: Reducer>(state: State, reducer: R, middleware: Middleware<State, Action> = .init(), publishOn scheduler: S) where R.State == State, R.Action == Action {
        self.state = state
        let statePublisher = actions.scan(state) { state, action in
            reducer.reduce(
                state: state,
                actions: middleware.transform(state, action)
            )
        }
        statePublisher.receive(on: scheduler).sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
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
