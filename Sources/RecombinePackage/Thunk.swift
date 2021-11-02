import Combine

/// The thunk is where you handle side effects, asynchronous calls, and generally code which interacts with the outside world (ie: making a network call, loading app data from disk, getting the user's current location). Much like the rest of Recombine, `Thunk` harnesses Combine and its publishers to represent these interactions.
///
/// `Thunk` is generic over 3 types:
/// * `State`: The data structure which represents the current app state.
/// * `Input`: Most commonly raw actions, this is the value that will be transformed into the `Output`.
/// * `Output`: `ActionStrata`, most commonly over raw/refined actions. This is the result of the `Input`'s transformation, which is then sent to the store's `Reducer`
///
/// When creating the thunk, you pass in the `State`, `Input`, and `Output` in the angle brackets, and then a closure which takes two arguments –  a publisher of `State`, the  `Input`, and which returns an `AnyPublisher` of the `Output`.
///
/// Critically, you don't have access to the current state itself – only a "stream" where you can send refined actions.
///
/// Because you need to return an `AnyPublisher`, you usually make your asynchronous calls using Combine publishers, which you can `flatMap(_:)` into the `statePublisher` to return a refined action. It is recommended to make publisher extensions on common types which don't already have one, like `FileManager` or `CLLocationManager`.
///
/// For example, a thunk which handles making a network call and resetting the app's state:
///
///     static let thunk = Thunk<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<Action.Refined, Never> in
///         switch action {
///             case let networkCall(url):
///                 URLSession.shared.dataTaskPublisher(for: url)
///                     .map(\.data)
///                     .decode(type: MyModel.self, decoder: JSONDecoder())
///                     .replaceError(with: MyModel())
///                     .flatMap { myModel in
///                         statePublisher.map { _ in
///                             return .refined(.setModel(myModel))
///                         }
///                      }
///                      .eraseToAnyPublisher()
///                 }
///         }
///     }
/// In the code above, the network call is made in the form of `URLSession`'s  `dataTaskPublisher(for:)`. We decode the data and change the publisher's error type using `replaceError(with:)` (since the returned `AnyPublisher`'s error type must be `Never` – this can be done with other operators like `catch(:)` and `mapError(_:)`).
///
/// Then, we replace the `URLSession` publisher with the `statePublisher` using `flatMap(_:)`, which itself returns a refined action: `.setModel(MyModel)`.

public struct Thunk<State, RawAction, RefinedAction, Environment> {
    public typealias Input = RawAction
    public typealias Output = RefinedAction
    public typealias StatePublisher = Publishers.First<Published<State>.Publisher>
    public typealias Action = ActionStrata<Input, Output>
    public typealias Function = (StatePublisher, Input, Environment) -> AnyPublisher<Action, Never>
    internal let transform: Function

    /// Create an empty passthrough `Thunk.`
    ///
    /// The input type must be equivalent to the output type.
    ///
    /// For example:
    ///
    ///     static let passthroughThunk = Thunk<State, Action.Refined, Action.Refined>()
    public init() where Input == Never {
        transform = { _, _, _ -> AnyPublisher<ActionStrata<Input, Output>, Never> in }
    }

    /// Initialises the thunk with a closure which handles transforming the raw actions and returning refined actions.
    /// - parameter transform: The closure which takes a publisher of `State`, and the `Thunk`'s `Input`, and returns a publisher who's output is the `Thunk`'s `Output`.
    ///
    /// The `transform` closure takes two parameters:
    /// * A publisher wrapping over the state that was passed into the `Thunk`'s angle brackets.
    /// * The middleware's input – most commonly raw actions.
    ///
    /// The closure then returns a publisher who's output is equivalent to the `Thunk`'s `Output` – an `ActionStrata` that most commonly contains raw/refined actions.
    ///
    /// For example:
    ///
    ///     static let thunk = Thunk<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<ActionStrata<Action.Raw, Action.Refined>, Never> in
    ///         switch action {
    ///             case let findCurrentLocation(service):
    ///                 return CLLocationManager.currentLocationPublisher(service: service)
    ///                     .map { LocationModel(location: $0) }
    ///                     .flatMap { location in
    ///                         statePublisher.map { _ in
    ///                             return .setLocation(to: location)
    ///                         }
    ///                     }
    ///                     .catch {
    ///                         Just(.locationError($0))
    ///                     }
    ///                     .map { .refined($0) }
    ///                     .eraseToAnyPublisher()
    ///
    public init<P: Publisher>(
        _ transform: @escaping (StatePublisher, Input, Environment) -> P
    ) where P.Output == Action, P.Failure == Never {
        self.transform = { transform($0, $1, $2).eraseToAnyPublisher() }
    }

    func callAsFunction(state: StatePublisher, input: Input, environment: Environment) -> AnyPublisher<Action, Never> {
        transform(state, input, environment)
    }
}
