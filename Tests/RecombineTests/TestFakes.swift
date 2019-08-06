//
//  TestFakes.swift
//  Recombine
//
//  Created by Benji Encz on 12/24/15.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Foundation
import Recombine

let dispatchQueue = DispatchQueue.global()

struct CounterState {
    var count: Int = 0
}

struct TestAppState {
    var testValue: Int?
}

struct TestStringAppState {
    var testValue: String?
}

enum SetAction: Equatable {
    case noop
    case int(Int)
    case string(String)
}

let testReducer: Reducer<TestAppState, SetAction> = .init { state, action in
    switch action {
    case let .int(value):
        state.testValue = value
    default:
        break
    }
}

let testValueStringReducer: Reducer<TestStringAppState, SetAction> = .init { state, action in
    switch action {
    case let .string(value):
        state.testValue = value
    default:
        break
    }
}

class TestStoreSubscriber<T> {
    var receivedStates: [T] = []
    var subscription: ((T) -> Void)!

    init() {
        subscription = { self.receivedStates.append($0) }
    }
}
