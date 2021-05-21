public struct ActionLens<RawAction, BaseRefinedAction, SubRefinedAction> {
    let dispatchFunction: (ActionStrata<[RawAction], [SubRefinedAction]>) -> Void

    public func callAsFunction<S: Sequence>(actions: S) where S.Element == SubRefinedAction {
        dispatchFunction(.refined(.init(actions)))
    }

    public func callAsFunction<S: Sequence>(actions: S) where S.Element == RawAction {
        dispatchFunction(.raw(.init(actions)))
    }
}

public extension ActionLens {
    func callAsFunction(actions: SubRefinedAction...) {
        dispatchFunction(.refined(actions))
    }

    func callAsFunction(actions: RawAction...) {
        dispatchFunction(.raw(actions))
    }
}
