public enum ActionStrata<RawAction, RefinedAction> {
    public typealias Raw = RawAction
    public typealias Refined = RefinedAction
    case raw(Raw)
    case refined(Refined)

    public static func raw<RawAction>(_ actions: RawAction...) -> Self
        where Raw: RangeReplaceableCollection,
        Raw.Element == RawAction
    {
        .raw(.init(actions))
    }

    public static func refined<RefinedAction>(_ actions: RefinedAction...) -> Self
        where Refined: RangeReplaceableCollection,
        Refined.Element == RefinedAction
    {
        .refined(.init(actions))
    }

    public var raw: Raw? {
        switch self {
        case let .raw(action):
            return action
        case .refined:
            return nil
        }
    }

    public var refined: Refined? {
        switch self {
        case let .refined(action):
            return action
        case .raw:
            return nil
        }
    }
}
