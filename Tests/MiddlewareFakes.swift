//
//  MiddlewareFakes.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Recombine

let firstMiddleware = Middleware<TestStringAppState, SetAction>().map { state, action in
    switch action {
    case let .string(value):
        return .string(value + " First Middleware")
    default:
        return action
    }
}

let secondMiddleware = Middleware<TestStringAppState, SetAction>().map { state, action in
    switch action {
    case let .string(value):
        return .string(value + " Second Middleware")
    default:
        return action
    }
}

let stateAccessingMiddleware = Middleware<TestStringAppState, SetAction>().map { state, action in
    if case let .string(value) = action  {
        return .string(state.testValue! + state.testValue!)
    }
    return action
}
