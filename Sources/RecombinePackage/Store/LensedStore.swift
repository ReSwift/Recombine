import Combine
import SwiftUI

public struct StoreLens<State: Equatable, AsyncAction, SyncAction>: StoreProtocol {
    public var combineIdentifier: CombineIdentifier = .init()

    public typealias Action = EitherAction<AsyncAction, SyncAction>
    public typealias Dispatch = (Bool, Bool, [Action]) -> Void
    private let _dispatch: Dispatch

    private var cancellable: AnyCancellable?
    public var stateSubject: CurrentValueSubject<State, Never>
    public var state: State {
        stateSubject.value
    }

    public var statePublisher: AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public init<StatePublisher: Publisher>(
        initial: State,
        statePublisher: StatePublisher,
        dispatch: @escaping Dispatch
    )
        where StatePublisher.Output == State, StatePublisher.Failure == Never
    {
        _dispatch = dispatch
        stateSubject = .init(initial)
        cancellable = statePublisher
            .removeDuplicates()
            .sink(receiveValue: stateSubject.send)
    }

    public func dispatch<S>(
        serially: Bool,
        collect: Bool,
        actions: S
    )
        where S: Sequence, S.Element == Action
    {
        _dispatch(serially, collect, .init(actions))
    }
}

public class LensedStore<State: Equatable, AsyncAction, SyncAction>: StoreProtocol, ObservableObject {
    public typealias Action = EitherAction<AsyncAction, SyncAction>
    public typealias Underlying = StoreLens<State, AsyncAction, SyncAction>

    private let underlying: Underlying
    private var cancellable: AnyCancellable?

    @Published public var state: State
    public var statePublisher: AnyPublisher<State, Never> {
        $state.eraseToAnyPublisher()
    }

    public init(from storeLens: Underlying) {
        underlying = storeLens
        state = storeLens.stateSubject.value
        cancellable = storeLens.stateSubject
            .dropFirst()
            .assign(to: \.state, on: self)
    }

    public convenience init<StatePublisher: Publisher>(
        initial: State,
        statePublisher: StatePublisher,
        dispatch: @escaping Underlying.Dispatch
    )
        where StatePublisher.Output == State, StatePublisher.Failure == Never
    {
        self.init(
            from: .init(
                initial: initial,
                statePublisher: statePublisher,
                dispatch: dispatch
            )
        )
    }

    public func dispatch<S>(
        serially: Bool,
        collect: Bool,
        actions: S
    )
        where S: Sequence, S.Element == Action
    {
        underlying.dispatch(serially: serially, collect: collect, actions: actions)
    }
}
