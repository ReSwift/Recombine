import Combine

/// A dependency injection structure where you transform raw actions, into refined actions which are sent to the store's `Reducer`.
///
/// The middleware is where you handle side effects, asynchronous calls, and generally code which interacts with the outside world (ie: making a network call, loading app data from disk, getting the user's current location), and also aggregate operations like resetting the state. Much like the rest of Recombine, `Middleware` harnesses Combine and its publishers to represent these interactions.
///
///`Middleware` is generic over 3 types:
/// * `State`: The  data structure which represents the current app state.
/// * `Input`: Most commonly raw actions, this is the value that will be transformed into the `Output`.
/// * `Output`: Most commonly refined actions, this is the result of the `Input`'s transformation, which is then sent to the store's `Reducer`
///
/// When creating the middleware, you pass in the `State`, `Input`, and `Output` in the angle brackets, and then a closure which takes two arguments –  a publisher of `State`, the  `Input`, and which returns an `AnyPublisher` of the `Output`.
///
/// Critically, you don't have access to the current state itself – only a "stream" where you can send refined actions.
///
/// Because you need to return an `AnyPublisher`, you usually make your asynchronous calls using Combine publishers, which you can `flatMap(_:)` into the `statePublisher` to return a refined action. It is recommended to make publisher extensions on common types which don't already have one, like `FileManager` or `CLLocationManager`.
///
/// For example, a middleware which handles making a network call and resetting the app's state:
///
///     static let middleware = Middleware<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<Action.Refined, Never> in
///         switch action {
///             case let networkCall(url):
///                 URLSession.shared.dataTaskPublisher(for: url)
///                     .map(\.data)
///                     .decode(type: MyModel.self, decoder: JSONDecoder())
///                     .replaceError(with: MyModel())
///                     .flatMap { myModel in
///                         statePublisher.map { _ in
///                             return .setModel(myModel)
///                             }
///                      }
///                      .eraseToAnyPublisher()
///                 }
///             case resetAppState:
///                 return [
///                     .setModel(MyModel.empty),
///                     .usernameModification(.delete))
///                     ]
///                     .publisher
///                     .eraseToAnyPublisher()
///         }
///     }
/// In the code above, the network call is made in the form of `URLSession`'s  `dataTaskPublisher(for:)`. We decode the data and change the publisher's error type using `replaceError(with:)` (since the returned `AnyPublisher`'s error type must be `Never` – this can be done with other operators like `catch(:)` and `mapError(_:)`).
///
/// Then, we replace the `URLSession` publisher with the `statePublisher` using `flatMap(_:)`, which itself returns a refined action: `.setModel(MyModel)`.
///
/// This middleware also handles an aggregate operation, resetting the app state. It simply returns an array of refined actions, which is turned into a publisher using the `publisher` property on the `Sequence` protocol.
public struct Middleware<State, Input, Output> {
    public typealias StatePublisher = Publishers.First<Published<State>.Publisher>
    public typealias Transform<Result> = (StatePublisher, Output) -> Result
    /// The closure which takes in the `StatePublisher` and `Input`, and transforms it into an `AnyPublisher<Output, Never>`;  the heart of the middleware.
    internal let transform: (StatePublisher, Input) -> AnyPublisher<Output, Never>

    /// Create an empty passthrough `Middleware.`
    ///
    /// The input type must be equivalent to the output type.
    ///
    ///For example:
    ///
    ///     static let passthroughMiddleware = Middleware<State, Action.Refined, Action.Refined>()
    public init() where Input == Output {
        self.transform = { Just($1).eraseToAnyPublisher() }
    }

    /// Initialises the middleware with a closure which handles transforming the raw actions and returning refined actions.
    /// - parameter transform: The closure which takes a publisher of `State`, and the `Middleware`'s `Input`, and returns a publisher who's output is the `Middleware`'s `Output`.
    ///
    /// The `transform` closure takes two parameters:
    /// * A publisher wrapping over the state that was passed into the `Middleware`'s angle brackets.
    /// * The middleware's input – most commonly raw actions.
    ///
    /// The closure then returns a publisher who's output is equivalent to the `Middleware`'s `Output` – most commonly refined actions.
    ///
    /// For example:
    ///
    ///     static let middleware = Middleware<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<Action.Refined, Never> in
    ///         switch action {
    ///             case let findCurrentLocation(service):
    ///                 CLLocationManager.currentLocationPublisher(service: service)
    ///                     .map { LocationModel(location: $0) }
    ///                     .flatMap { location in
    ///                         statePublisher.map { _ in
    ///                             return .setLocation(to: location)
    ///                         }
    ///                     }
    ///                     .catch { err in
    ///                         return Just(.locationError(err))
    ///                     }
    ///                     .eraseToAnyPublisher()
    /// For a more detailed explanation, go to the `Middleware` documentation.
    public init<P: Publisher>(
        _ transform: @escaping (StatePublisher, Input) -> P
    ) where P.Output == Output, P.Failure == Never {
        self.transform = { transform($0, $1).eraseToAnyPublisher() }
    }

    /// Adds two middlewares together, concatenating  the passed-in middleware's closure to the caller's own closure.
    /// - Parameter other: The other middleware, who's `State`, `Input`, and `Output` must be equivalent to the callers'.
    /// - Returns: A `Middleware` who's closure is the result of concatenating the caller's closure and the passed in middleware's closure.
    ///
    /// Use this function when you want to break up your middleware code to make it more compositional.
    ///
    /// For example:
    ///
    ///     static let middleware = Middleware<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<Action.Refined, Never> in
    ///         switch action {
    ///             case loadAppData:
    ///                 FileManager.default.loadPublisher(from: "appData.json", in: .applicationSupportDirectory)
    ///                     .decode(type: State.self, decoder: JSONDecoder())
    ///                     // etc...
    ///             default:
    ///                 break
    ///         }
    ///     }
    ///     .concat(
    ///         Middleware<State, Action.Raw, Action.Refined> { statePublisher, action -> AnyPublisher<Action.Refined, Never> in
    ///             switch action {
    ///                 case let displayBluetoothPeripherals(services: services):
    ///                     CBCentralManager.peripheralsPublisher(services: services)
    ///                         .map(\.peripheralName)
    ///                         // etc...
    ///                 default:
    ///                     break
    ///     )
    public func concat<Result>(_ other: Middleware<State, Output, Result>) -> Middleware<State, Input, Result> {
        .init { state, action in
            self.transform(state, action).flatMap {
                other.transform(state, $0)
            }
        }
    }
}
