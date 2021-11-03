import Combine

public enum ActionStrata<RawAction, RefinedAction> {
    public typealias Raw = RawAction
    public typealias Refined = RefinedAction
    public typealias Publisher = AnyPublisher<Self, Never>

    case raw([Raw])
    case refined([Refined])
}

public extension ActionStrata {
    var raw: [Raw]? {
        switch self {
        case let .raw(action):
            return action
        case .refined:
            return nil
        }
    }

    var refined: [Refined]? {
        switch self {
        case let .refined(action):
            return action
        case .raw:
            return nil
        }
    }

    var caseName: String {
        switch self {
        case .raw:
            return "raw"
        case .refined:
            return "refined"
        }
    }

    var actions: [Any] {
        switch self {
        case let .raw(actions):
            return actions
        case let .refined(actions):
            return actions
        }
    }
}

public extension ActionStrata {
    func map<NewRawAction>(raw transform: (RawAction) -> NewRawAction) -> ActionStrata<NewRawAction, RefinedAction> {
        map(raw: transform, refined: { $0 })
    }

    func map<NewRefinedAction>(refined transform: (RefinedAction) -> NewRefinedAction) -> ActionStrata<RawAction, NewRefinedAction> {
        map(raw: { $0 }, refined: transform)
    }

    func map<NewRawAction, NewRefinedAction>(
        raw rawTransform: (RawAction) -> NewRawAction,
        refined refinedTransform: (RefinedAction) -> NewRefinedAction
    ) -> ActionStrata<NewRawAction, NewRefinedAction> {
        switch self {
        case let .raw(actions):
            return .raw(actions.map(rawTransform))
        case let .refined(actions):
            return .refined(actions.map(refinedTransform))
        }
    }
}

public extension ActionStrata {
    static func refined(_ actions: Refined...) -> Self {
        .refined(actions)
    }

    static func raw(_ actions: Raw...) -> Self {
        .raw(actions)
    }
}
