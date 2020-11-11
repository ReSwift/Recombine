# Recombine

Recombine is a [Redux](https://github.com/reactjs/redux)-like implementation of the unidirectional data flow architecture in Swift.

This project could be considered a tightened and Combine-specific sequel to [ReactiveReSwift](https://github.com/ReSwift/ReactiveReSwift).

# About Recombine

Recombine relies on three principles:
- **The Store** stores your entire app state in the form of a single data structure. This state can only be modified by dispatching Actions to the store. Whenever the state in the store changes, the store will notify all observers.
- **Actions** are a declarative way of describing a state change. Actions don't contain any code, they are consumed by the store and forwarded to reducers. Reducers will handle the actions by implementing a different state change for each action.
- **Reducers** provide pure functions that create a new app state from actions and the current app state.
- **Middleware** is a transformative type that lets you go from unrefined actions to refined ones, allowing for asynchronous calls and multiplication of actions.

![](Docs/img/recombine_concept.png)

For a very simple app, one that maintains a counter, you can define the app state as following:

```swift
enum Redux {
    struct State {
        var text: String?
        var counter: Int
    }
}
```

You would also define your actions. For the simple actions in this example we can use a very basic enum:

```swift
// It's recommended that you use enums for your actions to ensure a well typed implementation.
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
extension Redux {
    static let store = Store<State, Action.Raw, Action.Refined>(
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

```swift
struct ContentView: View {
    @EnvironmentObject var store: Store<Redux.State, Redux.Action.Raw, Redux.Action.Refined>
    
    var body: some View {
        VStack {
            if let text = store.state.text {
                Text("Error: \(text)")
            }
            Text("\(store.state.counter)")
            HStack {
                Button(action: {
                    store.dispatch(refined: .modify(.decrease))
                }, label: {
                    Image(systemName: "minus.circle")
                })
                Button(action: {
                    store.dispatch(refined: .modify(.increase))
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
