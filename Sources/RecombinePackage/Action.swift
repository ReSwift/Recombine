public enum ActionStrata<RawAction, RefinedAction> {
    public typealias Raw = RawAction
    public typealias Refined = RefinedAction
    case raw(Raw)
    case refined(Refined)

    static func raw<RawAction>(_ actions: RawAction...) -> Self
        where Raw: RangeReplaceableCollection,
        Raw.Element == RawAction
    {
        .raw(.init(actions))
    }

    static func refined<RefinedAction>(_ actions: RefinedAction...) -> Self
        where Refined: RangeReplaceableCollection,
        Refined.Element == RefinedAction
    {
        .refined(.init(actions))
    }

    var raw: Raw? {
        switch self {
        case let .raw(action):
            return action
        case .refined:
            return nil
        }
    }

    var refined: Refined? {
        switch self {
        case let .refined(action):
            return action
        case .raw:
            return nil
        }
    }
}
