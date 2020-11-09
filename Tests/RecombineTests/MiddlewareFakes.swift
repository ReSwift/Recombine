//
//  MiddlewareFakes.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Recombine
import Combine

let firstMiddleware = Middleware<TestStringAppState, SetAction, SetAction>.map { state, action -> Just<SetAction> in
    switch action {
    case let .string(value):
        return Just(.string(value + " First Middleware"))
    default:
        return Just(action)
    }
}

let secondMiddleware = Middleware<TestStringAppState, SetAction, SetAction>.map { state, action -> Just<SetAction> in
    switch action {
    case let .string(value):
        return Just(.string(value + " Second Middleware"))
    default:
        return Just(action)
    }
}

let stateAccessingMiddleware = Middleware<TestStringAppState, SetAction, SetAction>().map { state, action -> AnyPublisher<SetAction, Never> in
    if case let .string(value) = action {
        return state.map {
            .string($0.testValue! + $0.testValue!)
        }
        .eraseToAnyPublisher()
    }
    return Just(action).eraseToAnyPublisher()
}
