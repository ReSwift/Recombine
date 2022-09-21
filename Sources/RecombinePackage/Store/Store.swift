import Combine
import Foundation
import SwiftUI

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

public class Store<State: Equatable, AsyncAction, SyncAction>: StoreProtocol, ObservableObject {
    public typealias Dispatch = (Bool, Bool, [Action]) -> Void
    public typealias BaseState = State
    public typealias Action = EitherAction<AsyncAction, SyncAction>
    public typealias Publishers = StorePublishers<State, AsyncAction, SyncAction>
    @Published public private(set) var state: State
    @Published public var dispatchEnabled = true
    public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }
    public var underlying: Store<State, AsyncAction, SyncAction> { self }
    public let stateTransform: (State) -> State = { $0 }
    public let actionPromotion: (SyncAction) -> SyncAction = { $0 }
    public var publishers: StorePublishers<State, AsyncAction, SyncAction> {
        .init(
            state: .init(
                current: state,
                changes: $state.eraseToAnyPublisher(),
                all: _allStateUpdates.eraseToAnyPublisher()
            ),
            actions: .init(
                sync: .init(
                    pre: _preMiddlewareSyncActions
                        .flatMap(\.publisher)
                        .eraseToAnyPublisher(),
                    post: _postMiddlewareSyncActions
                        .flatMap(\.publisher)
                        .eraseToAnyPublisher()
                ),
                async: _asyncActions
                    .flatMap(\.publisher)
                    .eraseToAnyPublisher()
            ),
            paired: _actionsPairedWithState
                .eraseToAnyPublisher()
        )
    }

    internal let thunk: (Publishers, AsyncAction) -> AnyPublisher<Action, Never>
    internal let _asyncActions = PassthroughSubject<[AsyncAction], Never>()
    internal let _preMiddlewareSyncActions = PassthroughSubject<[SyncAction], Never>()
    internal let _postMiddlewareSyncActions = PassthroughSubject<[SyncAction], Never>()
    internal let _allStateUpdates = PassthroughSubject<State, Never>()
    internal let _actionsPairedWithState = PassthroughSubject<Publishers.Paired, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init<S: Scheduler, Environment>(
        state: State,
        reducer: Reducer<State, SyncAction, Environment>,
        middleware: Middleware<State, AsyncAction, SyncAction, Environment> = .init(),
        thunk: Thunk<State, AsyncAction, SyncAction, Environment> = .init { _, _, _ in Empty() },
        sideEffect: SideEffect<SyncAction, Environment> = .init(),
        environment: Environment,
        publishOn scheduler: S
    ) {
        self.state = state
        self.thunk = {
            thunk(
                store: $0,
                input: $1,
                environment: environment
            )
        }

        _postMiddlewareSyncActions
            .zip(
                _allStateUpdates
                    .scan([]) { acc, item in .init((acc + [item]).suffix(2)) }
                    .filter { $0.count == 2 }
                    .map { ($0[0], $0[1]) }
            )
            .map {
                .init(actions: $0, state: .init(previous: $1.0, current: $1.1))
            }
            .forward(
                to: \._actionsPairedWithState,
                on: self,
                ownership: .weak,
                includeFinished: true
            )
            .store(in: &cancellables)

        _preMiddlewareSyncActions
            .flatMap { [$state] actions in
                $state
                    .first()
                    .map { (actions, $0) }
            }
            .map { [weak self] actions, previousState in
                actions.flatMap {
                    middleware(
                        state: previousState,
                        action: $0,
                        dispatch: { self?.dispatch(actions: $0) },
                        environment: environment
                    )
                }
            }
            .forward(
                to: \._postMiddlewareSyncActions,
                on: self,
                ownership: .weak,
                includeFinished: true
            )
            .store(in: &cancellables)

        var group = Optional(DispatchGroup())
        group?.enter()
        DispatchQueue.global().async {
            self._postMiddlewareSyncActions
                .handleEvents(receiveOutput: {
                    sideEffect.closure($0, environment)
                })
                .scan(state) { state, actions in
                    actions.reduce(state) { reducer.reduce(state: $0, action: $1, environment: environment) }
                }
                .prepend(state)
                .handleEvents(receiveOutput: { _ in
                    group?.leave()
                    group = nil
                })
                .receive(on: scheduler)
                .sink(receiveValue: { [weak self] state in
                    guard let self = self else { return }
                    self._allStateUpdates.send(state)
                    if self.state != state {
                        self.state = state
                    }
                })
                .store(in: &self.cancellables)
        }
        DispatchQueue.global().sync {
            group?.wait()
        }
    }

    public convenience init<Parameters: StoreParameter>(parameters _: Parameters.Type)
        where State == Parameters.States.Main,
        SyncAction == Parameters.Action.Sync,
        AsyncAction == Parameters.Action.Async
    {
        self.init(
            state: Parameters.States.initial,
            reducer: Parameters.Reducers.main,
            middleware: Parameters.Middlewares.main,
            thunk: Parameters.Thunks.main,
            sideEffect: Parameters.SideEffects.main,
            environment: Parameters.environment,
            publishOn: Parameters.scheduler
        )
    }

    open var actions: AnyPublisher<Action, Never> {
        _asyncActions
            .map(Action.async)
            .merge(with: _postMiddlewareSyncActions.map(Action.sync))
            .eraseToAnyPublisher()
    }

    open var asyncActions: AnyPublisher<[AsyncAction], Never> {
        _asyncActions.eraseToAnyPublisher()
    }

    open var preMiddlewareSyncActions: AnyPublisher<[SyncAction], Never> {
        _preMiddlewareSyncActions.eraseToAnyPublisher()
    }

    open var postMiddlewareSyncActions: AnyPublisher<[SyncAction], Never> {
        _postMiddlewareSyncActions.eraseToAnyPublisher()
    }

    open var allStateUpdates: AnyPublisher<State, Never> {
        _allStateUpdates.eraseToAnyPublisher()
    }

    open var actionsPairedWithState: AnyPublisher<Publishers.Paired, Never> {
        _actionsPairedWithState.eraseToAnyPublisher()
    }

    /// Dispatch actions to the store.
    ///
    /// - parameter serially: Whether to resolve the actions concurrently or serially.
    /// - parameter collect: Whether to collect all sync actions and send them when finished, or send them as they are resolved.
    /// - parameter actions: The actions to be sent.
    open func dispatch<S: Sequence>(
        serially: Bool = false,
        collect: Bool = false,
        actions: S
    ) where S.Element == Action {
        guard dispatchEnabled else {
            return
        }

        let maxPublishers: Subscribers.Demand = serially.if(true: .max(1), false: .unlimited)
        weak var `self` = self

        func recurse(actions: Action) -> AnyPublisher<[SyncAction], Never> {
            switch actions {
            case let .async(actions):
                self?._asyncActions.send(actions)
                return actions.publisher
                    .flatMap(maxPublishers: maxPublishers) { [thunk] action in
                        self.publisher()
                            .map(\.publishers)
                            .flatMap {
                                thunk($0, action)
                            }
                    }
                    .flatMap(maxPublishers: maxPublishers, recurse(actions:))
                    .eraseToAnyPublisher()
            case let .sync(actions):
                return Just(actions).eraseToAnyPublisher()
            }
        }

        let recursed = actions.publisher.flatMap(
            maxPublishers: maxPublishers,
            recurse(actions:)
        )

        collect.if(
            true: recursed
                .collect()
                .map { $0.flatMap { $0 } }
                .eraseToAnyPublisher(),
            false: recursed
                .eraseToAnyPublisher()
        )
        .sink {
            self?._preMiddlewareSyncActions.send($0)
        }
        .store(in: &cancellables)
    }

    open func injectBypassingMiddleware<S: Sequence>(actions: S) where S.Element == SyncAction {
        dispatchEnabled.if(
            true: _postMiddlewareSyncActions.send(.init(actions))
        )
    }

    open func replay<S: Sequence>(_ values: S) where S.Element == (offset: Double, actions: [SyncAction]) {
        dispatchEnabled = false
        values
            .publisher
            .flatMap { offset, actions in
                Just(actions).delay(
                    for: .seconds(max(0, offset)),
                    scheduler: DispatchQueue.global()
                )
            }
            // Cancel if dispatch is manually reenabled.
            .prefix(untilOutputFrom: $dispatchEnabled.filter { $0 })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    self.dispatchEnabled = true
                },
                receiveValue: _postMiddlewareSyncActions.send
            )
            .store(in: &cancellables)
    }
}
