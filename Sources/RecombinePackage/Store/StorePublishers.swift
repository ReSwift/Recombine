import Combine

public struct StorePublishers<StoreState: Equatable, AsyncAction, SyncAction> {
    public let state: State
    public let actions: Actions
    public let paired: AnyPublisher<Paired, Never>

    public struct State {
        public let current: StoreState
        public let changes: AnyPublisher<StoreState, Never>
        public let all: AnyPublisher<StoreState, Never>
    }

    public struct Actions {
        public struct Sync {
            public let pre: AnyPublisher<SyncAction, Never>
            public let post: AnyPublisher<SyncAction, Never>
        }

        public let sync: Sync
        public let async: AnyPublisher<AsyncAction, Never>
        public var all: AnyPublisher<EitherAction<AsyncAction, SyncAction>, Never> {
            async
                .map { .async($0) }
                .merge(with: sync.post.map { .sync($0) })
                .eraseToAnyPublisher()
        }
    }

    public struct Paired {
        struct PairedState: Equatable {
            let previous: StoreState
            let current: StoreState
        }

        let actions: [SyncAction]
        let state: PairedState
    }
}
