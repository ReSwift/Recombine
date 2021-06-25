import Combine

public class BaseStore<State: Equatable, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public var underlying: BaseStore<State, RawAction, RefinedAction> { self }
    public let stateLens: (State) -> State = { $0 }
    public let rawActions = PassthroughSubject<RawAction, Never>()
    public let refinedActions = PassthroughSubject<[RefinedAction], Never>()
    public let allStateUpdates = PassthroughSubject<State, Never>()
    public let actionsPairedWithState = PassthroughSubject<([RefinedAction], (previous: State, next: State)), Never>()
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }
    public var actions: AnyPublisher<Action, Never> {
        Publishers.Merge(
            rawActions.map(Action.raw),
            refinedActions.flatMap(\.publisher).map(Action.refined)
        )
        .eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    public init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RefinedAction> = .init { [$1] },
        thunk: Thunk<State, RawAction, RefinedAction> = .init { _, _ in Empty() },
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state

        rawActions.flatMap { [weak self] action in
            self.publisher().flatMap {
                thunk.transform($0.$state.first(), action)
            }
        }
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
            refinedActions,
            allStateUpdates
                .prepend(state)
                .scan([]) { acc, item in .init((acc + [item]).suffix(2)) }
                .filter { $0.count == 2 }
                .map { ($0[0], $0[1]) }
        )
        .sink(receiveValue: actionsPairedWithState.send)
        .store(in: &cancellables)

        Publishers.Zip(
            refinedActions,
            allStateUpdates
                .prepend(state)
        )
        .map { actions, previousState in
            actions.flatMap { middleware.transform(previousState, $0) }
        }
        .filter { !$0.isEmpty }
        .scan(state) { state, actions in
            actions.reduce(state, reducer.reduce)
        }
        .receive(on: scheduler)
        .sink { [weak self] state in
            guard let self = self else { return }
            self.allStateUpdates.send(state)
            if self.state != state {
                self.state = state
            }
        }
        .store(in: &cancellables)
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        refinedActions.send(.init(actions))
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(rawActions.send)
    }
}
