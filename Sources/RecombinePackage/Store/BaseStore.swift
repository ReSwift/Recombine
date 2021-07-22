import Combine
import Foundation

public class BaseStore<State: Equatable, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    public typealias ActionsAndState = ([RefinedAction], (previous: State, current: State))
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public var underlying: BaseStore<State, RawAction, RefinedAction> { self }
    public let stateLens: (State) -> State = { $0 }
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }

    private let thunk: Thunk<State, RawAction, RefinedAction>
    private let _rawActions = PassthroughSubject<[RawAction], Never>()
    private let _preMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _postMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _allStateUpdates = PassthroughSubject<State, Never>()
    private let _actionsPairedWithState = PassthroughSubject<ActionsAndState, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RawAction, RefinedAction> = .init(),
        thunk: Thunk<State, RawAction, RefinedAction> = .init { _, _ in Empty() },
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state
        self.thunk = thunk

        _rawActions
            .flatMap(\.publisher)
            .flatMap { [weak self] action in
                self.publisher().flatMap {
                    thunk.transform($0.$state.first(), action)
                }
            }
            .sink { [weak self] actions in
                self?.dispatch(actions: actions)
            }
            .store(in: &cancellables)

        Publishers.Zip(
            _postMiddlewareRefinedActions,
            _allStateUpdates
                .scan([]) { acc, item in .init((acc + [item]).suffix(2)) }
                .filter { $0.count == 2 }
                .map { ($0[0], $0[1]) }
        )
        .sink(receiveValue: _actionsPairedWithState.send)
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
            .sink(receiveValue: { [weak self] in
                self?._postMiddlewareRefinedActions.send($0)
            })
            .store(in: &cancellables)

        var group = Optional(DispatchGroup())
        group?.enter()
        DispatchQueue.global().async {
            self._postMiddlewareRefinedActions
                .scan(state) { state, actions in
                    actions.reduce(state, reducer.reduce)
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

    open func dispatch<S: Sequence>(actions: S)
        where S.Element == ActionStrata<[RawAction], [SubRefinedAction]>
    {
        actions.forEach {
            switch $0 {
            case let .raw(actions):
                _rawActions.send(actions)
            case let .refined(actions):
                _preMiddlewareRefinedActions.send(actions)
            }
        }
    }

    open func dispatchSerially<S: Sequence>(actions: S)
        where S.Element == ActionStrata<[RawAction], [RefinedAction]>
    {
        func reduce(actions: [RawAction]) -> AnyPublisher<[RefinedAction], Never> {
            actions.publisher
                .flatMap(maxPublishers: .max(1)) { [weak self] action in
                    self.publisher().flatMap {
                        $0.thunk.transform($0.$state.first(), action)
                    }
                }
                .flatMap(maxPublishers: .max(1)) { action -> AnyPublisher<[RefinedAction], Never> in
                    switch action {
                    case let .raw(actions):
                        return reduce(actions: actions)
                    case let .refined(actions):
                        return Just(actions).eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        }

        actions
            .publisher
            .flatMap(maxPublishers: .max(1)) { actions -> AnyPublisher<[RefinedAction], Never> in
                switch actions {
                case let .raw(actions):
                    return reduce(actions: actions)
                case let .refined(actions):
                    return Just(actions).eraseToAnyPublisher()
                }
            }
            .sink { [weak self] in
                self?.dispatch(refined: $0)
            }
            .store(in: &cancellables)
    }

    open func injectBypassingMiddleware<S: Sequence>(actions: S) where S.Element == RefinedAction {
        _postMiddlewareRefinedActions.send(.init(actions))
    }
}
