//
//  Reducer.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

public protocol Reducer {
    associatedtype State
    associatedtype Action
    associatedtype Transform

    var transform: Transform { get }
    init()
    init(_ transform: Transform)
    func reduce(state: State, action: Action) -> State
    func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform
}

extension Reducer {
    public init(_ reducers: Self...) {
        self = .init(reducers)
    }

    public init<S: Sequence>(_ reducers: S) where S.Element: Reducer, S.Element.Transform == Transform {
        self = reducers.reduce(Self.init()) {
            $0.concat($1)
        }
    }
}

public struct PureReducer<State, Action>: Reducer {
    public typealias Transform = (_ state: State, _ action: Action) -> State
    public let transform: Transform
    
    public init() {
        self.transform = { state, _ in state }
    }

    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }
    
    public func callAsFunction(state: State, action: Action) -> State {
        transform(state, action)
    }

    public func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform {
        Self.init { state, action in
            other.transform(self.transform(state, action), action)
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        transform(state, action)
    }
}

public struct MutatingReducer<State, Action>: Reducer {
    public typealias Transform = (_ state: inout State, _ action: Action) -> Void
    public let transform: Transform
    
    public init() {
        self.transform = { _, _ in }
    }

    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }
    
    public func callAsFunction(state: inout State, action: Action) {
        transform(&state, action)
    }

    public func concat<R: Reducer>(_ other: R) -> Self where R.Transform == Transform {
        Self.init { state, action in
            self.transform(&state, action)
            other.transform(&state, action)
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var s = state
        transform(&s, action)
        return s
    }
}
