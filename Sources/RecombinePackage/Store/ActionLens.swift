public struct ActionLens<RawAction, RefinedAction> {
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    let dispatchFunction: (Bool, Bool, [Action]) -> Void

    public func callAsFunction<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        actions: S
    ) where S.Element == Action {
        dispatchFunction(serially, collect, .init(actions))
    }

    public func callAsFunction<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        refined actions: S
    ) where S.Element == RefinedAction {
        dispatchFunction(serially, collect, [.refined(.init(actions))])
    }

    public func callAsFunction<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        raw actions: S
    ) where S.Element == RawAction {
        dispatchFunction(serially, collect, [.raw(.init(actions))])
    }
}

public extension ActionLens where RawAction == Never, RefinedAction == Void {
    func callAsFunction() {
        dispatchFunction(
            false,
            false,
            [.refined([()])]
        )
    }
}

public extension ActionLens where RawAction == Void, RefinedAction == Never {
    func callAsFunction() {
        dispatchFunction(
            false,
            false,
            [.raw([()])]
        )
    }
}

public extension ActionLens {
    func callAsFunction(
        serially: Bool = false,
        collect: Bool = false,
        actions: Action...
    ) {
        callAsFunction(serially: serially, collect: collect, actions: actions)
    }

    func callAsFunction(
        serially: Bool = false,
        collect: Bool = false,
        refined actions: RefinedAction...
    ) {
        callAsFunction(serially: serially, collect: collect, refined: actions)
    }

    func callAsFunction(
        serially: Bool = false,
        collect: Bool = false,
        raw actions: RawAction...
    ) {
        callAsFunction(serially: serially, collect: collect, raw: actions)
    }
}
