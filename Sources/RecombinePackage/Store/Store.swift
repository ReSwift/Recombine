import Combine

public class Store<State, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public var underlying: Store<State, RawAction, RefinedAction> { self }
    public let keyPath: KeyPath<State, State> = \.self
    public let rawActions = PassthroughSubject<RawAction, Never>()
    public let refinedActions = PassthroughSubject<RefinedAction, Never>()
    public var actions: Publishers.Merge<
        Publishers.Map<PassthroughSubject<RawAction, Never>, Action>,
        Publishers.Map<PassthroughSubject<RefinedAction, Never>, Action>
    > {
        .init(
            rawActions.map(Action.raw),
            refinedActions.map(Action.refined)
        )
    }
    private var cancellables = Set<AnyCancellable>()

    public required init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RawAction, RefinedAction>,
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state

        rawActions.flatMap { [unowned self] action in
            middleware.transform($state.first(), action)
        }
        .subscribe(refinedActions)
        .store(in: &cancellables)

        refinedActions.scan(state) { state, action in
            reducer.reduce(
                state: state,
                action: action
            )
        }
        .receive(on: scheduler)
        .sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }

    public func lensing<NewState>(_ keyPath: KeyPath<SubState, NewState>) -> StoreTransform<State, NewState, RawAction, RefinedAction> {
        .init(store: self, lensing: keyPath)
    }

    open func dispatch<S: Sequence>(refined actions: S) where S.Element == RefinedAction {
        actions.forEach(self.refinedActions.send)
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(self.rawActions.send)
    }
}
