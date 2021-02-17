import Combine
import SwiftUI

public class PreviewStore<State: Equatable, RawAction, RefinedAction>: StoreProtocol {
    public typealias SubState = State
    public typealias SubRefinedAction = RefinedAction
    @Published
    public private(set) var state: State
    public var statePublisher: Published<State>.Publisher { $state }
    public let underlying: BaseStore<State, RawAction, RefinedAction>
    public let stateLens: (State) -> State = { $0 }
    public let actionPromotion: (RefinedAction) -> RefinedAction = { $0 }

    private var cancellables = Set<AnyCancellable>()

    public required init(
        state: State
    ) {
        self.state = state
        self.underlying = BaseStore(
            state: state,
            reducer: PureReducer(),
            middleware: .init { _, _ in Empty() },
            publishOn: RunLoop.main
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
        .init(store: underlying, lensing: lens, actionPromotion: transform)
    }

    public func dispatch<S: Sequence>(refined _: S) where S.Element == RefinedAction {}

    public func dispatch<S: Sequence>(raw _: S) where S.Element == RawAction {}
}
