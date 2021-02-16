import Combine

public class BaseStore<State, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    public typealias Action = ActionStrata<RawAction, RefinedAction>
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public var underlying: BaseStore<State, RawAction, RefinedAction> { self }
    public let stateLens: (State) -> State = { $0 }
    public let rawActions = PassthroughSubject<RawAction, Never>()
    public let refinedActions = PassthroughSubject<RefinedAction, Never>()
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }
    public var actions: AnyPublisher<Action, Never> {
        Publishers.Merge(
            rawActions.map(Action.raw),
            refinedActions.map(Action.refined)
        )
        .eraseToAnyPublisher()
    }
    private let stateEquality: (State, State) -> Bool
    private var cancellables = Set<AnyCancellable>()

    public required init<S: Scheduler, R: Reducer>(
        state: State,
        stateEquality: @escaping (State, State) -> Bool,
        reducer: R,
        middleware: Middleware<State, RawAction, RefinedAction>,
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction {
        self.state = state
        self.stateEquality = stateEquality
        
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
        .removeDuplicates(by: stateEquality)
        .receive(on: scheduler)
        .sink { [unowned self] state in
            self.state = state
        }
        .store(in: &cancellables)
    }
    
    public convenience init<S: Scheduler, R: Reducer>(
        state: State,
        reducer: R,
        middleware: Middleware<State, RawAction, RefinedAction>,
        publishOn scheduler: S
    ) where R.State == State, R.Action == RefinedAction, State: Equatable {
        self.init(
            state: state,
            stateEquality: ==,
            reducer: reducer,
            middleware: middleware,
            publishOn: scheduler
        )
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
        actions.forEach(self.refinedActions.send)
    }

    open func dispatch<S: Sequence>(raw actions: S) where S.Element == RawAction {
        actions.forEach(self.rawActions.send)
    }
}
