//
//  Middleware.swift
//  Recombine
//
//  Created by Charlotte Tortorella on 2019-07-13.
//  Copyright © 2019 Charlotte Tortorella. All rights reserved.
//

/**
 Middleware is a structure that allows you to modify, filter out and create more
 actions, before the action being handled reaches the store.
 */
public struct Middleware<State, Action> {
    typealias Transform = (State, Action) -> [Action]
    internal let transform: Transform

    /// Create a blank slate Middleware.
    public init() {
        self.transform = { [$1] }
    }

    /**
     Initialises the middleware with a transformative function.
     
     - parameter transform: The function that will be able to modify passed actions.
     */
    internal init(_ transform: @escaping Transform) {
        self.transform = transform
    }

    /**
     Initialises the middleware by concatenating the transformative functions from
     the middleware that was passed in.
     */
    public init(_ middleware: Self...) {
        self = .init(middleware)
    }

    /**
     Initialises the middleware by concatenating the transformative functions from
     the middleware that was passed in.
     */
    public init<S: Sequence>(_ middleware: S) where S.Element == Middleware {
        self = middleware.reduce(.init()) {
            $0.concat($1)
        }
    }

    /// Concatenates the transform function of the passed `Middleware` onto the callee's transform.
    public func concat(_ other: Middleware) -> Middleware {
        .init { state, action in
            self.transform(state, action).flatMap {
                other.transform(state, $0)
            }
        }
    }

    /// Safe encapsulation of side effects guaranteed not to affect the action being passed through the middleware.
    public func sideEffect(_ effect: @escaping (State, Action) -> Void) -> Self {
        .init { state, action in
            self.transform(state, action).map {
                effect(state, $0)
                return $0
            }
        }
    }

    /// Transform the action into another action.
    public func map(_ transform: @escaping (State, Action) -> Action) -> Self {
        .init { state, action in
            self.transform(state, action).map {
                transform(state, $0)
            }
        }
    }

    /// One to many pattern allowing one action to be turned into multiple.
    public func flatMap<S: Sequence>(_ transform: @escaping (State, Action) -> S) -> Self where S.Element == Action {
        .init { state, action in
            self.transform(state, action).flatMap {
                transform(state, $0)
            }
        }
    }

    /// Filters while mapping actions to new actions.
    public func filterMap(_ transform: @escaping (State, Action) -> Action?) -> Self {
        .init { state, action in
            self.transform(state, action).compactMap {
                transform(state, $0)
            }
        }
    }

    /// Drop the action iff `isIncluded(action) != true`.
    public func filter(_ isIncluded: @escaping (State, Action) -> Bool) -> Self {
        .init { state, action in
            self.transform(state, action).filter {
                isIncluded(state, $0)
            }
        }
    }
}
