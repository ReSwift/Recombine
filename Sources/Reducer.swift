//
//  Reducer.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

public struct Reducer<State, Action> {
    public typealias Transform = (_ state: State, _ action: Action) -> State
    let transform: Transform
    
    public init(_ transform: @escaping Transform) {
        self.transform = transform
    }
    
    public static func concat(_ first: Reducer, _ rest: Reducer...) -> Reducer {
        return concat(first, rest)
    }
    
    public static func concat<S>(_ first: Reducer, _ rest: S) -> Reducer where S: Sequence, S.Element == Reducer {
        return .init { state, action in
            rest.reduce(first.transform(state, action)) { state, reducer in
                reducer.transform(state, action)
            }
        }
    }
}
