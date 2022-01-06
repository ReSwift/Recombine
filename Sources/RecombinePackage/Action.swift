import Combine

public enum EitherAction<AsyncAction, SyncAction> {
    public typealias Async = AsyncAction
    public typealias Sync = SyncAction
    public typealias Publisher = AnyPublisher<Self, Never>

    case async([Async])
    case sync([Sync])
}

public extension EitherAction {
    var asyncActions: [Async]? {
        switch self {
        case let .async(action):
            return action
        case .sync:
            return nil
        }
    }

    var syncActions: [Sync]? {
        switch self {
        case let .sync(action):
            return action
        case .async:
            return nil
        }
    }

    var caseName: String {
        switch self {
        case .async:
            return "async"
        case .sync:
            return "sync"
        }
    }

    var allActions: [Any] {
        switch self {
        case let .async(actions):
            return actions
        case let .sync(actions):
            return actions
        }
    }
}

public extension EitherAction {
    func map<NewAsyncAction>(async transform: (Async) -> NewAsyncAction) -> EitherAction<NewAsyncAction, SyncAction> {
        map(async: transform, sync: { $0 })
    }

    func map<NewSyncAction>(sync transform: (Sync) -> NewSyncAction) -> EitherAction<AsyncAction, NewSyncAction> {
        map(async: { $0 }, sync: transform)
    }

    func map<NewAsyncAction, NewSyncAction>(
        async asyncTransform: (Async) -> NewAsyncAction,
        sync syncTransform: (Sync) -> NewSyncAction
    ) -> EitherAction<NewAsyncAction, NewSyncAction> {
        switch self {
        case let .async(actions):
            return .async(actions.map(asyncTransform))
        case let .sync(actions):
            return .sync(actions.map(syncTransform))
        }
    }
}

public extension EitherAction {
    static func sync(_ actions: Sync...) -> Self {
        .sync(actions)
    }

    static func async(_ actions: Async...) -> Self {
        .async(actions)
    }
}
