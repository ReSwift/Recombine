import Combine
import Foundation

public class Store<State: Equatable, AsyncAction, SyncAction>: StoreProtocol, ObservableObject {
    public typealias Dispatch = (Bool, Bool, [Action]) -> Void
    public typealias BaseState = State
    public typealias Action = EitherAction<AsyncAction, SyncAction>
    public typealias ActionsAndState = ([SyncAction], (previous: State, current: State))
    @Published public private(set) var state: State
    @Published public var dispatchEnabled = true
    public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }
    public var underlying: Store<State, AsyncAction, SyncAction> { self }
    public let stateTransform: (State) -> State = { $0 }
    public let actionPromotion: (SyncAction) -> SyncAction = { $0 }

    private let thunk: (Published<State>.Publisher, AsyncAction) -> AnyPublisher<Action, Never>
    private let _asyncActions = PassthroughSubject<[AsyncAction], Never>()
    private let _preMiddlewareSyncActions = PassthroughSubject<[SyncAction], Never>()
    private let _postMiddlewareSyncActions = PassthroughSubject<[SyncAction], Never>()
    private let _allStateUpdates = PassthroughSubject<State, Never>()
    private let _actionsPairedWithState = PassthroughSubject<ActionsAndState, Never>()
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
            thunk(state: $0.first(), input: $1, environment: environment)
        }

        Publishers.Zip(
            _postMiddlewareSyncActions,
            _allStateUpdates
                .scan([]) { acc, item in .init((acc + [item]).suffix(2)) }
                .filter { $0.count == 2 }
                .map { ($0[0], $0[1]) }
        )
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
        Publishers.Merge(
            _asyncActions.map(Action.async),
            _postMiddlewareSyncActions.map(Action.sync)
        )
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

    open var actionsPairedWithState: AnyPublisher<ActionsAndState, Never> {
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
                    .flatMap(maxPublishers: maxPublishers) { [thunk, $state] in
                        thunk($state, $0)
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
