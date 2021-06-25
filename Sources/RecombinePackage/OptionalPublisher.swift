import Combine

extension Optional {
    func publisher() -> AnyPublisher<Wrapped, Never> {
        switch self {
        case let .some(wrapped):
            return Just(wrapped).eraseToAnyPublisher()
        case .none:
            return Empty().eraseToAnyPublisher()
        }
    }
}
