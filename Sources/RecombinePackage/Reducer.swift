//
//  Reducer.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

public struct Reducer<State, Action> {
    public typealias Transform = (_ state: inout State, _ action: Action) -> Void
    public let transform: Transform
    
    private init() {
        self.transform = { _, _ in }
    }
    
    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }
    
    public init(_ reducers: Reducer...) {
        self = .init(reducers)
    }

    public init<S: Sequence>(_ reducers: S) where S.Element == Reducer {
        self = reducers.reduce(.init()) {
            $0.concat($1)
        }
    }

    public func concat(_ other: Reducer) -> Reducer {
        .init { state, action in
            self.transform(&state, action)
            other.transform(&state, action)
        }
    }
}
