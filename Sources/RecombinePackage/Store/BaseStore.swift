import Combine
import Foundation

public class BaseStore<State: Equatable, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    public typealias ActionsAndState = ([RefinedAction], (previous: State, current: State))
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public var underlying: BaseStore<State, RawAction, RefinedAction> { self }
    public let stateLens: (State) -> State = { $0 }
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }

    private let _rawActions = PassthroughSubject<RawAction, Never>()
    private let _preMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _postMiddlewareRefinedActions = PassthroughSubject<[RefinedAction], Never>()
    private let _allStateUpdates = PassthroughSubject<State, Never>()
    private let _actionsPairedWithState = PassthroughSubject<ActionsAndState, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RefinedAction> = .init(),
        thunk: Thunk<State, RawAction, RefinedAction> = .init { _, _ in Empty() },
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state

        let group = DispatchGroup()

        group.enter()
        _rawActions.flatMap { [weak self] action in
            self.publisher().flatMap {
                thunk.transform($0.$state.first(), action)
            }
        }
        .handleEvents(receiveSubscription: { _ in
            group.leave()
        })
        .sink { [weak self] value in
            switch value {
            case let .raw(action):
                self?.dispatch(raw: action)
            case let .refined(action):
                self?.dispatch(refined: action)
            }
        }
        .store(in: &cancellables)

        Publishers.Zip(
            _postMiddlewareRefinedActions,
            _allStateUpdates
                .prepend(state)
                .scan([]) { acc, item in .init((acc + [item]).suffix(2)) }
                .filter { $0.count == 2 }
                .map { ($0[0], $0[1]) }
        )
        .sink(receiveValue: _actionsPairedWithState.send)
        .store(in: &cancellables)

        group.enter()
        _preMiddlewareRefinedActions
            .flatMap { [weak self] actions in
                self.publisher()
                    .flatMap { $0.$state.first() }
                    .map { (actions, $0) }
            }
            .map { [weak self] actions, previousState in
                actions.flatMap {
                    middleware.transform(previousState, $0) { self?.dispatch(refined: $0) }
                }
            }
            .handleEvents(receiveSubscription: { _ in
                group.leave()
            })
            .sink(receiveValue: { [weak self] actions in
                self?._postMiddlewareRefinedActions.send(actions)
            })
            .store(in: &cancellables)

        group.enter()
        _postMiddlewareRefinedActions
            .scan(state) { state, actions in
                actions.reduce(state, reducer.reduce)
            }
            .receive(on: scheduler)
            .handleEvents(receiveSubscription: { _ in
                group.leave()
            })
            .sink { [weak self] state in
                guard let self = self else { return }
                self._allStateUpdates.send(state)
                if self.state != state {
                    self.state = state
                }
            }
            .store(in: &cancellables)

        group.wait()
    }

    open var actions: AnyPublisher<Action, Never> {
        Publishers.Merge(
            _rawActions.map(Action.raw),
            _postMiddlewareRefinedActions.flatMap(\.publisher).map(Action.refined)
        )
        .eraseToAnyPublisher()
    }

    open var rawActions: AnyPublisher<RawAction, Never> {
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

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        _preMiddlewareRefinedActions.send(.init(actions))
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(_rawActions.send)
    }

    open func injectBypassingMiddleware<S: Sequence>(actions: S) where S.Element == RefinedAction {
        _postMiddlewareRefinedActions.send(.init(actions))
    }
}
