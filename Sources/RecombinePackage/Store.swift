//
//  Store.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Combine

public class Store<State, Action>: ObservableObject, Subscriber {
    @Published public private(set) var state: State
    public let actions = PassthroughSubject<Action, Never>()
    private var cancellables = Set<AnyCancellable>()

    public required init(state: State, reducer: Reducer<State, Action>, middleware: Middleware<State, Action> = .init()) {
        self.state = state
        actions.scan(state) { state, action in
            middleware
                .transform(state, action)
                .reduce(state, reducer.transform)
        }
        .sink(receiveValue: { [unowned self] state in
            self.state = state
        })
        .store(in: &cancellables)
    }

    public func dispatch(_ actions: Action...) {
        dispatch(actions)
    }

    public func dispatch<S: Sequence>(_ actions: S) where S.Element == Action {
        actions.forEach(self.actions.send)
    }

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
