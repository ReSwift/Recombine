import Combine
import Foundation

public class Store<State: Equatable, RawAction, RefinedAction>: StoreProtocol, ObservableObject {
    public typealias Dispatch = (Bool, Bool, [ActionStrata<RawAction, RefinedAction>]) -> Void
    public typealias BaseState = State
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    public typealias ActionsAndState = ([RefinedAction], (previous: State, current: State))
    @Published public private(set) var state: State
    @Published public var dispatchEnabled = true
    public var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }
    public var underlying: Store<State, RawAction, RefinedAction> { self }
    public let stateTransform: (State) -> State = { $0 }
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }

    private let thunk: Thunk<State, RawAction, RefinedAction>
    private let _rawActions = PassthroughSubject<[RawAction], Never>()
    private let _preMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _postMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _allStateUpdates = PassthroughSubject<State, Never>()
    private let _actionsPairedWithState = PassthroughSubject<ActionsAndState, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init<S: Scheduler, Environment>(
        state: State,
        reducer: Reducer<State, RefinedAction, Environment>,
        middleware: Middleware<State, RawAction, RefinedAction> = .init(),
        thunk: Thunk<State, RawAction, RefinedAction> = .init { _, _ in Empty() },
        sideEffect: SideEffect<RefinedAction> = .init(),
        environment: Environment,
        publishOn scheduler: S
    ) {
        self.state = state
        self.thunk = thunk

        Publishers.Zip(
            _postMiddlewareRefinedActions,
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

        _preMiddlewareRefinedActions
            .flatMap { [weak self] actions in
                self.publisher()
                    .flatMap { $0.$state.first() }
                    .map { (actions, $0) }
            }
            .map { [weak self] actions, previousState in
                actions.flatMap {
                    middleware.transform(previousState, $0) { (actions: Action...) in
                        self?.dispatch(actions: actions)
                    }
                }
            }
            .forward(
                to: \._postMiddlewareRefinedActions,
                on: self,
                ownership: .weak,
                includeFinished: true
            )
            .store(in: &cancellables)

        var group = Optional(DispatchGroup())
        group?.enter()
        DispatchQueue.global().async {
            self._postMiddlewareRefinedActions
                .handleEvents(receiveOutput: {
                    sideEffect.closure($0)
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
        RefinedAction == Parameters.Action.Refined,
        RawAction == Parameters.Action.Raw
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
            _rawActions.map(Action.raw),
            _postMiddlewareRefinedActions.map(Action.refined)
        )
        .eraseToAnyPublisher()
    }

    open var rawActions: AnyPublisher<[RawAction], Never> {
        _rawActions.eraseToAnyPublisher()
    }

    open var preMiddlewareRefinedActions: AnyPublisher<[RefinedAction], Never> {
        _preMiddlewareRefinedActions.eraseToAnyPublisher()
    }

    open var postMiddlewareRefinedActions: AnyPublisher<[RefinedAction], Never> {
        _postMiddlewareRefinedActions.eraseToAnyPublisher()
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
    /// - parameter collect: Whether to collect all refined actions and send them when finished, or send them as they are resolved.
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

        func recurse(actions: Action) -> AnyPublisher<[RefinedAction], Never> {
            switch actions {
            case let .raw(actions):
                self?._rawActions.send(actions)
                return actions.publisher
                    .flatMap(maxPublishers: maxPublishers) { [weak self] action in
                        self.publisher().flatMap {
                            $0.thunk.transform($0.$state.first(), action)
                        }
                    }
                    .flatMap(maxPublishers: maxPublishers, recurse(actions:))
                    .eraseToAnyPublisher()
            case let .refined(actions):
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
            self?._preMiddlewareRefinedActions.send($0)
        }
        .store(in: &cancellables)
    }

    open func injectBypassingMiddleware<S: Sequence>(actions: S) where S.Element == RefinedAction {
        dispatchEnabled.if(
            true: _postMiddlewareRefinedActions.send(.init(actions))
        )
    }

    open func replay<S: Sequence>(_ values: S) where S.Element == (offset: Double, actions: [RefinedAction]) {
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
                receiveValue: _postMiddlewareRefinedActions.send
            )
            .store(in: &cancellables)
    }
}
