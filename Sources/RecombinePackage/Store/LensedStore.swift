import Combine

public class LensedStore<BaseState: Equatable, SubState: Equatable, RawAction, BaseRefinedAction, SubRefinedAction>: StoreProtocol {
    public typealias StoreType = BaseStore<BaseState, RawAction, BaseRefinedAction>
    @Published
    public private(set) var state: SubState
    public var statePublisher: Published<SubState>.Publisher { $state }
    public let underlying: BaseStore<BaseState, RawAction, BaseRefinedAction>
    public let stateLens: (BaseState) -> SubState
    public let actionPromotion: (SubRefinedAction) -> BaseRefinedAction

    private var cancellables = Set<AnyCancellable>()

    public required init(store: StoreType, lensing lens: @escaping (BaseState) -> SubState, actionPromotion: @escaping (SubRefinedAction) -> BaseRefinedAction) {
        underlying = store
        stateLens = lens
        self.actionPromotion = actionPromotion
        state = lens(store.state)
        store.$state
            .map(lens)
            .removeDuplicates()
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &cancellables)
    }
}

public extension LensedStore where BaseRefinedAction == SubRefinedAction {
    convenience init(store: StoreType, lensing lens: @escaping (BaseState) -> SubState) {
        self.init(store: store, lensing: lens, actionPromotion: { $0 })
    }
}
