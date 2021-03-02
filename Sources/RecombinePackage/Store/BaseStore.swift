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
        middleware: Middleware<State, RawAction, RefinedAction> = .init { _, _ in Empty() },
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state

        rawActions.flatMap { [unowned self] action in
            middleware.transform($state.first(), action)
        }
        .map { [$0] }
        .subscribe(refinedActions)
        .store(in: &cancellables)

        refinedActions.scan(state) { state, actions in
            actions.reduce(state, reducer.reduce)
        }
        .removeDuplicates()
        .receive(on: scheduler)
        .sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }

    public func lensing<NewState, NewAction>(
        state lens: @escaping (SubState) -> NewState,
        actions transform: @escaping (NewAction) -> SubRefinedAction
    ) -> LensedStore<
        State,
        NewState,
        RawAction,
        RefinedAction,
        NewAction
    > {
        .init(store: self, lensing: lens, actionPromotion: transform)
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        refinedActions.send(.init(actions))
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(rawActions.send)
    }
}
