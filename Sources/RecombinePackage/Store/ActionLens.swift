public struct ActionLens<AsyncAction, SyncAction> {
    public typealias Action = EitherAction<AsyncAction, SyncAction>
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
        sync actions: S
    ) where S.Element == SyncAction {
        dispatchFunction(serially, collect, [.sync(.init(actions))])
    }

    public func callAsFunction<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        async actions: S
    ) where S.Element == AsyncAction {
        dispatchFunction(serially, collect, [.async(.init(actions))])
    }
}

public extension ActionLens where AsyncAction == Never, SyncAction == Void {
    func callAsFunction() {
        dispatchFunction(
            false,
            false,
            [.sync([()])]
        )
    }
}

public extension ActionLens where AsyncAction == Void, SyncAction == Never {
    func callAsFunction() {
        dispatchFunction(
            false,
            false,
            [.async([()])]
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
        sync actions: SyncAction...
    ) {
        callAsFunction(serially: serially, collect: collect, sync: actions)
    }

    func callAsFunction(
        serially: Bool = false,
        collect: Bool = false,
        async actions: AsyncAction...
    ) {
        callAsFunction(serially: serially, collect: collect, async: actions)
    }
}
