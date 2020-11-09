//
//  Middleware.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

import Combine

/**
 Middleware is a structure that allows you to modify, filter out and create more
 actions, before the action being handled reaches the store.
 */
public struct Middleware<State, Input, Output> {
    public typealias Function = (Publishers.Output<Published<State>.Publisher>, Input) -> AnyPublisher<Output, Never>
    public typealias Transform<Result> = (Publishers.Output<Published<State>.Publisher>, Output) -> Result
    internal let transform: Function

    /// Create a blank slate Middleware.
    public init() where Input == Output {
        self.transform = { Just($1).eraseToAnyPublisher() }
    }

    /**
     Initialises the middleware with a transformative function.
     
     - parameter transform: The function that will be able to modify passed actions.
     */
    private init(_ transform: @escaping Function) {
        self.transform = transform
    }
    
    /// Concatenates the transform function of the passed `Middleware` onto the callee's transform.
    public func concat<Result>(_ other: Middleware<State, Output, Result>) -> Middleware<State, Input, Result> {
        return map(other.transform)
    }

    /// Transform the action into another action.
    public func map<Result, P: Publisher>(
        _ transform: @escaping Transform<P>
    ) -> Middleware<State, Input, Result> where P.Output == Result, P.Failure == Never {
        .init { state, action in
            self.transform(state, action).flatMap {
                transform(state, $0)
            }
            .eraseToAnyPublisher()
        }
    }

    /// Drop the action iff `isIncluded(action) != true`.
    public func filter(_ isIncluded: @escaping Transform<Bool>) -> Self {
        .init { state, action in
            self.transform(state, action).filter {
                isIncluded(state, $0)
            }
            .eraseToAnyPublisher()
        }
    }
}

extension Middleware where Input == Output {
    /// Transform the action into another action.
    public static func map<Result, P: Publisher>(
        _ transform: @escaping Transform<P>
    ) -> Middleware<State, Input, Result> where P.Output == Result, P.Failure == Never {
        Middleware<State, Input, Input>().map(transform)
    }

    /// Drop the action iff `isIncluded(action) != true`.
    public static func filter(_ isIncluded: @escaping Transform<Bool>) -> Self {
        Middleware<State, Input, Input>().filter(isIncluded)
    }
}
