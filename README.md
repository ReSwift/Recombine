# Recombine

Recombine is a deeply opinionated [Redux](https://github.com/reactjs/redux)-like implementation of the unidirectional data flow architecture in Swift.

This project could be considered a tightened and Combine-specific sequel to [ReactiveReSwift](https://github.com/ReSwift/ReactiveReSwift).

# Why Recombine?

Ever since I started writing Elm in 2012 at the impressionable age of eighteen, I've always seen its Model-View-Update architecture as the pinnacle of user interface development, and I've wanted for a very long time to make something faithful to Elm's design philosophy. SwiftUI now allows us that same power, if only we use the right tools to take advantage of it.

Recombine makes so many facets of application development easy, for the up front cost of your UI reflecting a central state model.

At the time of writing this document, Swift does not yet have default `Codable` implementations for enums with associated types. There is currently a proposal in the pipeline, but you can already get all the benefits listed below by using [Sourcery's](https://github.com/krzysztofzablocki/Sourcery) [`AutoCodable` template](https://github.com/krzysztofzablocki/Sourcery/blob/master/Templates/Tests/Context/AutoCodable.swift).
A non-comprehensive list of benefits:
- **Type-safe**: Recombine uses concrete types, not protocols, for its actions. If you're using enums for your actions (and you should), switch cases will alert you to all of the locations that need updating whenever you make changes to your implementation.
- **Screenshotting**: Since your entire app state is driven by actions, you can serialise lists of actions into JSON, pipe them into the app via XCUITest environment variables, and deserialise them into lists of actions to be applied after pressing a single clear overlay button on top of your entire view hierarcy (which notifies the application that you've taken a screenshot and it can continue). No fussing about with button labels and writing specific logic that will break with UI redesigns.
- **Replay**: When a user experiences a bug, they can send you a bug report with all of the actions taken up to that point in the application included (please make sure to fuzz out user-sensitive data when collecting these actions). By keeping a `[TimeInterval: [RefinedAction]]` object for use in debugging into which you record your actions (the time interval being the amount of seconds elapsed since the app started), you can replay these actions using a custom handler and see the weird timing bugs that somehow users are amazing at creating, but developers are rarely able to reproduce.
- **Lensing**: Since Recombine dictates that the structure of your code should be like a type-pyramid, it can get rather awkward when you're twelve views down in the stack having to access `state.user.config.information.name.displayName` and update it using `.config(.user(.info(.name(.displayName("Evan Czaplicki")))))`. That's where lensing comes in! Using the power of `@EnvironmentObject`, you can inject lensed stores that can only see a tiny amount of the state, and only send a tiny amount of actions, as per their needs. You can inject as many lensed stores as you like, so long as their types don't conflict. This allows for hassle free lensing into your user state, navigation state, and so on, using multiple `LensedStore` types in any view that requires access to multiple deep nested locations. An added benefit to lensing is that your view won't be refreshed by irrelevant changes to the outer state, since lensed states are required to be `Equatable`.

# About Recombine

Recombine relies on three principles:
- **The Store** stores your entire app state in the form of a single data structure. This state can only be modified by dispatching Actions to the store. Whenever the state in the store changes, the store will notify all observers.
- **Actions** are a declarative way of describing a state change. Actions don't contain any code, they are consumed by the store and forwarded to reducers. Reducers will handle the actions by implementing a different state change for each action.
- **Reducers** provide pure functions that create a new app state from actions and the current app state. These are your business and navigation logic routers.
- **Middleware** is a transformative type that lets you go from unrefined actions to refined ones, allowing for asynchronous calls and shortcut expansion of one action into many. Middleware is perfect for extracting records from databases or servers.

![](Docs/img/recombine_concept.png)

For a very simple app, one that maintains a counter, you can define the app state as following:

```swift
enum Redux {
    struct State: Equatable {
        var text: String?
        var counter: Int
    }
}
```

You would also define your actions. For the simple actions in this example we can use a very basic enum:

```swift
// Use enums for your actions to ensure a well typed implementation.
extension Redux {
    enum Action {
        enum Refined {
            case modify(Modification)
            case setText(String?)
            
            enum Modification {
                case increase
                case decrease
                case set(Int)
            }
        }

        enum Raw {
            case networkCall(URL)
            case reset
        }
    }
}
```

A single `Reducer` should only deal with a single field of the state struct. You can nest multiple reducers within your main reducer to provide separation of concerns.
In order to have a predictable app state, it is important that the reducer is always free of side effects, it receives the current app state and an action and returns the new app state.
Your reducer needs to respond to these different actions, that can be done by switching over the value of action:

```swift
extension Redux {
    enum Reducer {
        static let main = MutatingReducer<State, Action.Refined> { state, action in
            switch action {
            case let .modify(action):
                state.counter = modification(state: state.counter, action: action)
            case let .setText(text):
                state.text = text
            }
        }

        static let modification = PureReducer<Int, Action.Refined.Modification> { state, action in
            switch action {
            case .increase:
                return state + 1
            case .decrease:
                return state - 1
            case let .set(value):
                return value
            }
        }
    }
}
```

We also need `Middleware` to intercept our "raw" actions and convert them into "refined" ones.
Here we can do asynchronous operations like network requests and aggregate operations like resetting the state.

```swift
extension Redux {
    static let middleware: Middleware<State, Action.Raw, Action.Refined> = Middleware { state, action -> AnyPublisher<Action.Refined, Never> in
        switch action {
        case let .networkCall(url):
            return URLSession.shared
                .dataTaskPublisher(for: url)
                .flatMap { data, _ in
                    state.map {
                        .modify(.set($0.counter + data.count))
                    }
                }
                .catch { error in
                    Just(.setText(error.localizedDescription))
                }
                .eraseToAnyPublisher()
        case .reset:
            return [
                .modify(.set(0)),
                .setText(nil)
            ]
            .publisher
            .eraseToAnyPublisher()
        }
    }
}
```

To maintain our state and delegate the actions to the reducers, we need a store. Let's call it `Redux.store`:

```swift
// It's recommended to create typealiases
typealias Store = BaseStore<Redux.State, Redux.Action.Raw, Redux.Action.Refined>
typealias SubStore<SubState: Equatable, SubAction> = LensedStore<Redux.State, SubState, Redux.Action.Raw, Redux.Action.Refined, SubAction>

extension Redux {
    static let store = Store(
        state: .init(counter: 0),
        reducer: Reducer.main,
        middleware: middleware,
        publishOn: RunLoop.main
    )
}
```

Now let's inject the store as an environment variable so that any views in our hierarchy can access it and automatically be updated when state changes:

```swift
ContentView()
    .environmentObject(Redux.store)
```

Now it can be accessed from any of our views!
But just for fun, let's inject some lensed stores too.


```swift
ContentView()
    .environmentObject(Redux.store)
    .environmentObject(
        Redux.store.lensing(
            state: \.counter, // Using a keypath to narrow the state to just the counter
            actions: { .modify($0) } // Using a function to narrow our actions to just modifictions
        )
    )
    .environmentObject(
        Redux.store.lensing(
            state: \.text,
            actions: { .setText($0) } // You can even narrow your actions to a singular action with no sub-actions!
        )
    )
```

Lensed states are required to be `Equatable`, which means that not only will you not get view updates when only the outer store changes, you won't get updates unless the lensed state itself becomes distinct from its previous state. Using SwiftUI's powerful environment injection, we can lens any parts of the state we want, and as long as the resulting lenses have unique types, they won't overwrite one another.

```swift
struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var counterStore: SubStore<Int, Redux.Action.Refined.Modification>
    @EnvironmentObject var textStore: SubStore<String?, String?>
    
    var body: some View {
        VStack {
            if let text = textStore.state {
                Text("Error: \(text)")
            }
            Text("\(counterStore.state)")
            HStack {
                Button(action: {
                    store.dispatch(refined: .modify(.decrease))
                }, label: {
                    Image(systemName: "minus.circle")
                })
                Button(action: {
                    counterStore.dispatch(refined: .increase)
                }, label: {
                    Image(systemName: "plus.circle")
                })
            }
            Button("Network request") {
                store.dispatch(raw: .networkCall(URL(string: "https://www.google.com")!))
            }
            Button("Reset") {
                store.dispatch(raw: .reset)
            }
        }
    }
}
```

# Credits

- Huge thanks to [Evan Czaplicki](https://github.com/evancz) for creating [Elm](https://github.com/elm-lang), the first language to implement unidirectional data flow as a paradigm.
- Thanks a lot to [Dan Abramov](https://github.com/gaearon) for building [Redux](https://github.com/reactjs/redux), many ideas in here were provided by his library.
- Thanks a lot to [Benjamin Encz](https://github.com/Ben-G) for building [ReSwift](https://github.com/ReSwift/ReSwift), the base from which this project was originally derived.

# Example Projects

[Recombine-Example](https://github.com/ReSwift/Recombine-Example): A counter example app that showcases networking, action recording/replay, state rewind and serialising actions via `Codable`.

[Magnetar](https://github.com/Qata/Magnetar)
